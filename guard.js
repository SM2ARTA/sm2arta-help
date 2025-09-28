// guard.js — cross-tab "session until all tabs closed"
// How it works:
// - On successful login we set a global auth mark in localStorage and start a heartbeat.
// - Any new tab that sees a fresh heartbeat (from another open tab) will auto-unlock.
// - When the last tab closes, heartbeat stops; after a short TTL, auth is considered expired.

(function () {
  // === CONFIG ===
  const PW_HASH = "1abe8f5aca6045c7844a07b0e09fb57039cb2c5923de729dfce9d07f28624971"; // 64-char SHA-256 hex of your password
  const HEARTBEAT_INTERVAL_MS = 3000;       // how often tabs update the heartbeat
  const HEARTBEAT_TTL_MS      = 10000;      // how long a heartbeat is considered "alive" (10s)

  // === Keys ===
  const AUTH_LOCAL = "sm_help_auth";     // localStorage: "ok:<hash>"
  const AUTH_SESS  = "sm_help_session";  // sessionStorage: "ok:<hash>" (per tab)
  const HB_KEY     = "sm_help_heartbeat";// localStorage: last timestamp (ms)
  const MARK       = "ok:" + PW_HASH;

  // === Helpers exposed to pages ===
  function now()     { return Date.now(); }
  function getHB()   { return parseInt(localStorage.getItem(HB_KEY) || "0", 10); }
  function hbAlive() { return (now() - getHB()) < HEARTBEAT_TTL_MS; }
  function hasGlobalAuth() { return localStorage.getItem(AUTH_LOCAL) === MARK; }
  function hasTabAuth()    { return sessionStorage.getItem(AUTH_SESS) === MARK; }

  let hbTimer = null;
  function startHeartbeat() {
    // write immediately, then on interval
    localStorage.setItem(HB_KEY, String(now()));
    if (hbTimer) clearInterval(hbTimer);
    hbTimer = setInterval(() => {
      localStorage.setItem(HB_KEY, String(now()));
    }, HEARTBEAT_INTERVAL_MS);
  }

  function stopHeartbeat() {
    if (hbTimer) clearInterval(hbTimer);
    hbTimer = null;
  }

  function setAuthed() {
    // set both: global + this tab; then start heartbeat for cross-tab sharing
    localStorage.setItem(AUTH_LOCAL, MARK);
    sessionStorage.setItem(AUTH_SESS, MARK);
    startHeartbeat();
  }

  // Auto-unlock this tab if another authed tab is alive
  if (!hasTabAuth() && hasGlobalAuth() && hbAlive()) {
    sessionStorage.setItem(AUTH_SESS, MARK);
    startHeartbeat();
  }

  // If user navigates away / closes, interval stops automatically.
  // If this was the last tab, heartbeat stops and expires after TTL → next open will prompt.

  // Expose API
  window.SM_HELP = {
    PW_HASH,
    isAuthed: () => hasTabAuth() || (hasGlobalAuth() && hbAlive()),
    setAuthed,
    startHeartbeat, // in case you want to call explicitly after login
  };

  // Protect deep links: if a topic is opened without auth, bounce to the gate
  const path = location.pathname.replace(/\/+$/, "");
  const isGate = (path === "" || path === "/" || path.endsWith("/index.html"));
  if (!isGate && !window.SM_HELP.isAuthed()) {
    const next = location.pathname + location.search + location.hash;
    location.replace("/?next=" + encodeURIComponent(next));
  }
})();
