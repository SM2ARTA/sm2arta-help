/* guard.js — cross-tab session with link-based auto-login
   - Accepts #pw= (plaintext), #ps= (alias), or #pwh= (SHA-256 hex, lowercase/uppercase OK)
   - Strips secrets from URL after use
   - Shares login across tabs while any tab is open (heartbeat)
   - Bounces unauth deep-links to "/" unless already authed
*/
(async function () {
  // === CONFIG ===
  const PW_HASH = "1abe8f5aca6045c7844a07b0e09fb57039cb2c5923de729dfce9d07f28624971"; // 64-char SHA-256 hex
  const HEARTBEAT_INTERVAL_MS = 3000;
  const HEARTBEAT_TTL_MS      = 10000;

  // === Keys / marks ===
  const AUTH_LOCAL = "sm_help_auth";      // localStorage: global mark
  const AUTH_SESS  = "sm_help_session";   // sessionStorage: per-tab mark
  const HB_KEY     = "sm_help_heartbeat"; // last heartbeat timestamp (ms)
  const MARK       = "ok:" + PW_HASH;

  // Helpers
  function now() { return Date.now(); }
  function getHB() { return parseInt(localStorage.getItem(HB_KEY) || "0", 10); }
  function hbAlive() { return (now() - getHB()) < HEARTBEAT_TTL_MS; }
  function hasGlobalAuth() { return localStorage.getItem(AUTH_LOCAL) === MARK; }
  function hasTabAuth() { return sessionStorage.getItem(AUTH_SESS) === MARK; }

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
  function isAuthed() {
    return hasTabAuth() || (hasGlobalAuth() && hbAlive());
  }

  async function sha256(str) {
    const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
    return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
  }

  // If another authed tab is alive, auto-unlock this tab
  if (!hasTabAuth() && hasGlobalAuth() && hbAlive()) {
    sessionStorage.setItem(AUTH_SESS, MARK);
    startHeartbeat();
  }

  // Case-insensitive fragment param helpers
  const hashParams = new URLSearchParams(location.hash.slice(1));
  function getParamCI(name) {
    const target = String(name).toLowerCase();
    for (const [k, v] of hashParams.entries()) {
      if (String(k).toLowerCase() === target) return v;
    }
    return null;
  }
  function cleanedHashExcluding(keysLowerArr) {
    const out = new URLSearchParams();
    for (const [k, v] of hashParams.entries()) {
      if (keysLowerArr.includes(String(k).toLowerCase())) continue;
      out.append(k, v);
    }
    const s = out.toString();
    return s ? ("#" + s) : "";
  }

  // Try to auto-login from URL fragment: #pw=..., #ps=..., or #pwh=...
  async function attemptLinkAuth() {
    const pw  = getParamCI("pw") || getParamCI("ps");    // plaintext or alias
    const pwh = getParamCI("pwh");                       // precomputed hash

    let ok = false;
    if (pwh && pwh.toLowerCase() === PW_HASH) {
      ok = true;
    } else if (pw) {
      try { ok = (await sha256(pw)) === PW_HASH; } catch {}
    }

    if (ok) {
      setAuthed();
      // Strip secrets (#pw/#ps/#pwh) from the URL but keep any other fragment keys
      const newHash = cleanedHashExcluding(["pw", "ps", "pwh"]);
      history.replaceState(null, "", location.pathname + location.search + newHash);
    }
    return ok;
  }

  // Expose minimal API if the gate page wants it
  window.SM_HELP = { PW_HASH, isAuthed, setAuthed, startHeartbeat };

  // Run link-auth before guarding deep links
  await attemptLinkAuth();

  // Protect deep links (non-root pages)
  const path = location.pathname.replace(/\/+$/, "");
  const isGate = (path === "" || path === "/" || path.endsWith("/index.html"));
  if (!isGate && !isAuthed()) {
    const next = location.pathname + location.search + location.hash;
    location.replace("/?next=" + encodeURIComponent(next));
  }
})();
