/* guard.js — cross-tab session with link-based auto-login (#pw or #pwh)
   - Accepts password or SHA-256 hash in the URL fragment, then strips it.
   - Shares login across tabs while any tab is open (heartbeat).
   - Bounces unauth deep-links to "/" unless already authed.
*/
(async function () {
  // === CONFIG ===
  const PW_HASH = "1abe8f5aca6045c7844a07b0e09fb57039cb2c5923de729dfce9d07f28624971"; // 64-char SHA-256 hex of your password
  const HEARTBEAT_INTERVAL_MS = 3000;
  const HEARTBEAT_TTL_MS      = 10000;

  // === Keys/marks ===
  const AUTH_LOCAL = "sm_help_auth";      // localStorage: global mark
  const AUTH_SESS  = "sm_help_session";   // sessionStorage: per-tab mark
  const HB_KEY     = "sm_help_heartbeat"; // timestamp (ms) for cross-tab heartbeat
  const MARK       = "ok:" + PW_HASH;

  // Helpers
  function now() { return Date.now(); }
  function getHB(){ return parseInt(localStorage.getItem(HB_KEY) || "0", 10); }
  function hbAlive(){ return (now() - getHB()) < HEARTBEAT_TTL_MS; }
  function hasGlobalAuth(){ return localStorage.getItem(AUTH_LOCAL) === MARK; }
  function hasTabAuth(){ return sessionStorage.getItem(AUTH_SESS) === MARK; }

  let hbTimer = null;
  function startHeartbeat() {
    localStorage.setItem(HB_KEY, String(now()));
    if (hbTimer) clearInterval(hbTimer);
    hbTimer = setInterval(() => {
      localStorage.setItem(HB_KEY, String(now()));
    }, HEARTBEAT_INTERVAL_MS);
  }

  function setAuthed() {
    localStorage.setItem(AUTH_LOCAL, MARK);
    sessionStorage.setItem(AUTH_SESS, MARK);
    startHeartbeat();
  }
  function isAuthed(){ return hasTabAuth() || (hasGlobalAuth() && hbAlive()); }

  async function sha256(str) {
    const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
    return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
  }

  // Auto-unlock this tab if another authed tab is alive
  if (!hasTabAuth() && hasGlobalAuth() && hbAlive()) {
    sessionStorage.setItem(AUTH_SESS, MARK);
    startHeartbeat();
  }

  // Try to auto-login from URL fragment: #pw=... or #pwh=...
  async function attemptLinkAuth() {
    const hashParams = new URLSearchParams(location.hash.slice(1));
    const pw  = hashParams.get("pw");
    const pwh = hashParams.get("pwh");

    let ok = false;
    if (pwh && pwh.toLowerCase() === PW_HASH) {
      ok = true;
    } else if (pw) {
      try { ok = (await sha256(pw)) === PW_HASH; } catch {}
    }
    if (ok) {
      setAuthed();
      // Strip secrets from the URL (keep other fragment keys if any)
      const cleaned = new URLSearchParams(location.hash.slice(1));
      cleaned.delete("pw"); cleaned.delete("pwh");
      const newHash = cleaned.toString();
      history.replaceState(null, "", location.pathname + location.search + (newHash ? "#" + newHash : ""));
    }
    return ok;
  }

  // Expose minimal API if index.html needs it
  window.SM_HELP = { PW_HASH, isAuthed, setAuthed, startHeartbeat };

  // Run link-auth before deciding to bounce deep links
  await attemptLinkAuth();

  // Protect deep links (pages that aren't the root gate)
  const path = location.pathname.replace(/\/+$/, "");
  const isGate = (path === "" || path === "/" || path.endsWith("/index.html"));
  if (!isGate && !isAuthed()) {
    const next = location.pathname + location.search + location.hash;
    location.replace("/?next=" + encodeURIComponent(next));
  }
})();
