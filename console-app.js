(function(){
  "use strict";

  /* ============================================================
     In-browser SQL console, powered by sql.js (SQLite compiled to
     WebAssembly). Everything here runs client-side -- no server,
     no external calls once the page has loaded, since the WASM
     binary is embedded inline as base64 (see the script block
     right before this one).
     ============================================================ */

  function b64ToUint8Array(b64){
    var binStr = atob(b64);
    var len = binStr.length;
    var bytes = new Uint8Array(len);
    for (var i = 0; i < len; i++) bytes[i] = binStr.charCodeAt(i);
    return bytes;
  }
  function uint8ToB64(bytes){
    var binary = "";
    var chunk = 0x8000;
    for (var i = 0; i < bytes.length; i += chunk){
      binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
    }
    return btoa(binary);
  }
  function escapeHtml(s){
    return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
  }

  // ---------------- Engine bootstrap ----------------
  var enginePromise = null;
  function getEngine(){
    if (!enginePromise){
      enginePromise = new Promise(function(resolve, reject){
        try{
          var wasmBytes = b64ToUint8Array(window.SQL_WASM_B64);
          window.initSqlJs({ wasmBinary: wasmBytes }).then(resolve, reject);
        }catch(e){ reject(e); }
      });
    }
    return enginePromise;
  }
  // Kick off loading immediately (non-blocking) so it's likely ready
  // by the time the learner opens the Console tab.
  if (typeof window.initSqlJs === "function") { getEngine().catch(function(){}); }

  // ---------------- Persistence (per-browser, best-effort) ----------------
  var STORAGE_PREFIX = "sts_db_v1_";
  var STORAGE_LIST_KEY = "sts_db_list_v1";
  var BUILTIN = "retail_academy";

  function saveDbSnapshot(name, db){
    try{
      var b64 = uint8ToB64(db.export());
      localStorage.setItem(STORAGE_PREFIX + name, b64);
      var list = getSavedList();
      if (list.indexOf(name) === -1){
        list.push(name);
        localStorage.setItem(STORAGE_LIST_KEY, JSON.stringify(list));
      }
    }catch(e){ /* storage unavailable/full -- silently skip persistence */ }
  }
  function loadDbSnapshot(name){
    try{
      var b64 = localStorage.getItem(STORAGE_PREFIX + name);
      return b64 ? b64ToUint8Array(b64) : null;
    }catch(e){ return null; }
  }
  function forgetDbSnapshot(name){
    try{
      localStorage.removeItem(STORAGE_PREFIX + name);
      var list = getSavedList().filter(function(n){ return n !== name; });
      localStorage.setItem(STORAGE_LIST_KEY, JSON.stringify(list));
    }catch(e){}
  }
  function getSavedList(){
    try{
      var raw = localStorage.getItem(STORAGE_LIST_KEY);
      return raw ? JSON.parse(raw) : [];
    }catch(e){ return []; }
  }

  // ---------------- Database registry ----------------
  var registry = {};   // name -> SQL.Database

  function ensureDatabase(name){
    return getEngine().then(function(SQL){
      if (registry[name]) return registry[name];
      var snapshot = loadDbSnapshot(name);
      var db;
      if (snapshot){
        db = new SQL.Database(snapshot);
      } else if (name === BUILTIN){
        db = new SQL.Database();
        db.run(window.STS_DEFAULT_SEED_SQL);
      } else {
        db = new SQL.Database();
      }
      registry[name] = db;
      return db;
    });
  }

  function resetDatabase(name){
    forgetDbSnapshot(name);
    delete registry[name];
    return ensureDatabase(name);
  }

  function registerNewDb(name, db){
    registry[name] = db;
    saveDbSnapshot(name, db);
  }

  // ---------------- DOM wiring ----------------
  var els = {};
  function cacheEls(){
    els.tabLearn      = document.getElementById("tab-learn");
    els.tabConsole    = document.getElementById("tab-console");
    els.viewLearn     = document.getElementById("view-learn");
    els.viewConsole   = document.getElementById("view-console");
    els.dbSelect      = document.getElementById("db-select");
    els.dbAddBtn      = document.getElementById("db-add-btn");
    els.dbResetBtn    = document.getElementById("db-reset-btn");
    els.uploadPanel   = document.getElementById("upload-panel");
    els.uploadFile    = document.getElementById("upload-file");
    els.uploadPaste   = document.getElementById("upload-paste");
    els.uploadName    = document.getElementById("upload-name");
    els.uploadSubmit  = document.getElementById("upload-submit");
    els.uploadCancel  = document.getElementById("upload-cancel");
    els.uploadError   = document.getElementById("upload-error");
    els.editor        = document.getElementById("sql-editor");
    els.runBtn        = document.getElementById("run-btn");
    els.results       = document.getElementById("results-area");
    els.engineStatus  = document.getElementById("engine-status");
  }

  function switchTab(tab){
    var toConsole = tab === "console";
    els.viewLearn.hidden = toConsole;
    els.viewConsole.hidden = !toConsole;
    els.tabLearn.classList.toggle("active", !toConsole);
    els.tabConsole.classList.toggle("active", toConsole);
    try{ localStorage.setItem("sts_last_tab", tab); }catch(e){}
    if (toConsole) initConsoleOnce();
  }

  var consoleInited = false;
  function initConsoleOnce(){
    if (consoleInited) return;
    consoleInited = true;
    refreshDbSelect();
    setEngineStatus("loading");
    ensureDatabase(currentDbName()).then(function(){
      setEngineStatus("ready");
    }).catch(function(err){
      setEngineStatus("error", err && err.message);
    });
  }

  function setEngineStatus(state, msg){
    if (state === "loading"){
      els.engineStatus.textContent = "Loading SQL engine…";
      els.engineStatus.className = "engine-status loading";
    } else if (state === "ready"){
      els.engineStatus.textContent = "Engine ready";
      els.engineStatus.className = "engine-status ready";
    } else {
      els.engineStatus.textContent = "Engine failed to load" + (msg ? ": " + msg : "");
      els.engineStatus.className = "engine-status error";
    }
  }

  function refreshDbSelect(){
    var saved = getSavedList().filter(function(n){ return n !== BUILTIN; });
    var all = [BUILTIN].concat(saved);
    var cur = els.dbSelect.value;
    els.dbSelect.innerHTML = "";
    all.forEach(function(n){
      var opt = document.createElement("option");
      opt.value = n;
      opt.textContent = n === BUILTIN ? "retail_academy (built-in)" : n;
      els.dbSelect.appendChild(opt);
    });
    if (all.indexOf(cur) !== -1) els.dbSelect.value = cur;
  }

  function currentDbName(){ return els.dbSelect.value || BUILTIN; }

  function runSql(sqlText){
    if (!sqlText || !sqlText.trim()) return;
    var name = currentDbName();
    els.results.innerHTML = "";
    setRunning(true);
    ensureDatabase(name).then(function(db){
      var startedAt = (window.performance && performance.now) ? performance.now() : Date.now();
      try{
        var results = db.exec(sqlText);
        var elapsed = (((window.performance && performance.now) ? performance.now() : Date.now()) - startedAt).toFixed(1);
        renderResults(results, elapsed, db);
        saveDbSnapshot(name, db);
      }catch(e){
        renderError(e.message);
      } finally {
        setRunning(false);
      }
    }).catch(function(e){
      renderError("Engine error: " + e.message);
      setRunning(false);
    });
  }

  function setRunning(isRunning){
    els.runBtn.disabled = isRunning;
    els.runBtn.textContent = isRunning ? "Running…" : "▶ Run   (Ctrl/⌘ + Enter)";
  }

  function renderError(msg){
    var box = document.createElement("div");
    box.className = "sql-error";
    box.innerHTML = "<b>Error</b><pre>" + escapeHtml(msg) + "</pre>";
    els.results.appendChild(box);
  }

  function renderResults(results, elapsed, db){
    if (!results || results.length === 0){
      var modified = db.getRowsModified();
      var info = document.createElement("div");
      info.className = "sql-info";
      info.textContent = "Statement executed in " + elapsed + "ms. " + modified + " row(s) affected. No result set returned.";
      els.results.appendChild(info);
      return;
    }
    results.forEach(function(res, idx){
      var wrap = document.createElement("div");
      wrap.className = "result-block";

      var meta = document.createElement("div");
      meta.className = "result-meta";
      meta.textContent = "Result " + (idx + 1) + " of " + results.length + " — " + res.values.length + " row(s) in " + elapsed + "ms";
      wrap.appendChild(meta);

      var tableWrap = document.createElement("div");
      tableWrap.className = "table-scroll";
      var table = document.createElement("table");
      table.className = "result-table";

      var thead = document.createElement("thead");
      var trh = document.createElement("tr");
      res.columns.forEach(function(c){
        var th = document.createElement("th");
        th.textContent = c;
        trh.appendChild(th);
      });
      thead.appendChild(trh);
      table.appendChild(thead);

      var tbody = document.createElement("tbody");
      res.values.forEach(function(row){
        var tr = document.createElement("tr");
        row.forEach(function(val){
          var td = document.createElement("td");
          if (val === null){ td.textContent = "NULL"; td.className = "null-val"; }
          else { td.textContent = String(val); }
          tr.appendChild(td);
        });
        tbody.appendChild(tr);
      });
      table.appendChild(tbody);
      tableWrap.appendChild(table);
      wrap.appendChild(tableWrap);
      els.results.appendChild(wrap);
    });
  }

  // ---------------- Upload / paste a mini database ----------------
  function openUploadPanel(){
    els.uploadPanel.hidden = false;
    els.uploadError.hidden = true;
    els.uploadName.focus();
  }
  function closeUploadPanel(){
    els.uploadPanel.hidden = true;
    els.uploadFile.value = "";
    els.uploadPaste.value = "";
    els.uploadName.value = "";
  }
  function showUploadError(msg){
    els.uploadError.textContent = msg;
    els.uploadError.hidden = false;
  }

  function handleUploadSubmit(){
    var name = (els.uploadName.value || "").trim();
    if (!name){ showUploadError("Give this database a short name."); return; }
    if (!/^[a-zA-Z0-9_\-]+$/.test(name)){ showUploadError("Use letters, numbers, - or _ only."); return; }
    if (name === BUILTIN){ showUploadError("That name is reserved for the built-in dataset."); return; }

    var file = els.uploadFile.files && els.uploadFile.files[0];
    var pasted = els.uploadPaste.value.trim();
    if (!file && !pasted){ showUploadError("Choose a file or paste some SQL first."); return; }

    getEngine().then(function(SQL){
      if (file){
        var isBinary = /\.(sqlite3?|db3?)$/i.test(file.name);
        var reader = new FileReader();
        reader.onload = function(){
          try{
            var db;
            if (isBinary){
              db = new SQL.Database(new Uint8Array(reader.result));
            } else {
              db = new SQL.Database();
              db.run(reader.result);
            }
            finishRegister(name, db);
          }catch(e){ showUploadError("Couldn't load that file: " + e.message); }
        };
        reader.onerror = function(){ showUploadError("Couldn't read that file."); };
        if (isBinary) reader.readAsArrayBuffer(file); else reader.readAsText(file);
      } else {
        try{
          var db2 = new SQL.Database();
          db2.run(pasted);
          finishRegister(name, db2);
        }catch(e){ showUploadError("SQL error: " + e.message); }
      }
    }).catch(function(e){ showUploadError("Engine error: " + e.message); });
  }

  function finishRegister(name, db){
    registerNewDb(name, db);
    refreshDbSelect();
    els.dbSelect.value = name;
    closeUploadPanel();
    els.results.innerHTML = "";
    var info = document.createElement("div");
    info.className = "sql-info";
    info.textContent = "Loaded “" + name + "” and selected it as your active database — write a query and hit Run.";
    els.results.appendChild(info);
  }

  // ---------------- "Try it in Console" from Learn tab ----------------
  window.STS_tryInConsole = function(code){
    switchTab("console");
    initConsoleOnce();
    els.editor.value = code;
    getEngine().then(function(){ runSql(code); }).catch(function(){});
  };

  // ---------------- init ----------------
  function init(){
    cacheEls();
    els.tabLearn.addEventListener("click", function(){ switchTab("learn"); });
    els.tabConsole.addEventListener("click", function(){ switchTab("console"); });
    els.dbAddBtn.addEventListener("click", openUploadPanel);
    els.uploadCancel.addEventListener("click", closeUploadPanel);
    els.uploadSubmit.addEventListener("click", handleUploadSubmit);

    els.dbSelect.addEventListener("change", function(){
      els.results.innerHTML = "";
      setEngineStatus("loading");
      ensureDatabase(currentDbName()).then(function(){ setEngineStatus("ready"); });
    });

    els.dbResetBtn.addEventListener("click", function(){
      var name = currentDbName();
      var ok = window.confirm("Reset “" + name + "” back to its original data? Any changes you made in this browser will be lost.");
      if (!ok) return;
      resetDatabase(name).then(function(){
        els.results.innerHTML = "";
        var info = document.createElement("div");
        info.className = "sql-info";
        info.textContent = "“" + name + "” reset to its original data.";
        els.results.appendChild(info);
      });
    });

    els.runBtn.addEventListener("click", function(){ runSql(els.editor.value); });
    els.editor.addEventListener("keydown", function(e){
      if ((e.ctrlKey || e.metaKey) && e.key === "Enter"){
        e.preventDefault();
        runSql(els.editor.value);
      }
      if (e.key === "Tab"){
        e.preventDefault();
        var s = els.editor.selectionStart, en = els.editor.selectionEnd;
        els.editor.value = els.editor.value.slice(0, s) + "  " + els.editor.value.slice(en);
        els.editor.selectionStart = els.editor.selectionEnd = s + 2;
      }
    });

    var lastTab = "learn";
    try{ lastTab = localStorage.getItem("sts_last_tab") || "learn"; }catch(e){}
    switchTab(lastTab);
  }

  if (document.readyState === "loading"){
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
