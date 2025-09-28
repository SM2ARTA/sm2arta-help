/* guard.js — cross-tab session, link auto-login, no-flash reveal
   - Accepts #pw=, #ps= (alias), #pwh= (SHA-256 hex)
   - Shares auth across tabs (heartbeat + handshake)
   - Hides deep pages until auth confirmed; reveals only when allowed
*/
(async function () {
  // === CONFIG ===
  const PW_HASH = "1abe8f5aca6045c7844a07b0e09fb57039cb2c5923de729dfce9d07f28624971"; // 64-char SHA-256 hex
  const HEARTBEAT_INTERVAL_MS = 3000;
  const HEARTBEAT_TTL_MS      = 10000;   // grace after last tab closes
  const HANDSHAKE_WAIT_MS     = 900;     // wait for other tabs to answer

  // === Keys / marks ===
  const AUTH_LOCAL = "sm_help_auth";
  const AUTH_SESS  = "sm_help_session";
  const HB_KEY     = "sm_help_heartbeat";
  const MARK       = "ok:" + PW_HASH;

  // Reveal helper: remove preauth hide and show page
  function reveal() {
    const s = document.getElementById('preauth-hide');
    if (s) s.remove();
    const el = document.documentElement;
    el.style.visibility = 'visible';
    el.style.opacity = '1';
  }

  // Helpers
  function now(){ return Date.now(); }
  function getHB(){ return parseInt(localStorage.getItem(HB_KEY) || "0", 10); }
  function hbAlive(){ return (now() - getHB()) < HEARTBEAT_TTL_MS; }
  function hasGlobalAuth(){ return localStorage.getItem(AUTH_LOCAL) === MARK; }
  function hasTabAuth(){ return sessionStorage.getItem(AUTH_SESS) === MARK; }
  function isAuthed(){ return hasTabAuth() || (hasGlobalAuth() && hbAlive()); }

  let hbTimer = null;
  function startHeartbeat(){
    localStorage.setItem(HB_KEY, String(now()));
    if (hbTimer) clearInterval(hbTimer);
    hbTimer = setInterval(() => {
      localStorage.setItem(HB_KEY, String(now()));
    }, HEARTBEAT_INTERVAL_MS);
  }
  function setAuthed(){
    localStorage.setItem(AUTH_LOCAL, MARK);
    sessionStorage.setItem(AUTH_SESS, MARK);
    startHeartbeat();
    announceAuth();
  }

  async function sha256(str){
    const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
    return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2,"0")).join("");
  }

  // If another authed tab is alive, adopt immediately
  if (!hasTabAuth() && hasGlobalAuth() && hbAlive()) {
    sessionStorage.setItem(AUTH_SESS, MARK);
    startHeartbeat();
  }

  // --- Link-based auto-login: #pw=, #ps=, #pwh= ---
  const hashParams = new URLSearchParams(location.hash.slice(1));
  function getParamCI(name){
    const target = String(name).toLowerCase();
    for (const [k,v] of hashParams.entries()) if (String(k).toLowerCase() === target) return v;
    return null;
  }
  function cleanedHashExcluding(keysLowerArr){
    const out = new URLSearchParams();
    for (const [k,v] of hashParams.entries()) {
      if (keysLowerArr.includes(String(k).toLowerCase())) continue;
      out.append(k,v);
    }
    const s = out.toString();
    return s ? ("#" + s) : "";
  }
  async function attemptLinkAuth(){
    const pw  = getParamCI("pw") || getParamCI("ps");
    const pwh = getParamCI("pwh");
    let ok = false;
    if (pwh && pwh.toLowerCase() === PW_HASH) ok = true;
    else if (pw) { try { ok = (await sha256(pw)) === PW_HASH; } catch {} }
    if (ok) {
      setAuthed();
      const newHash = cleanedHashExcluding(["pw","ps","pwh"]);
      history.replaceState(null, "", location.pathname + location.search + newHash);
    }
    return ok;
  }

  // --- Cross-tab handshake (BroadcastChannel + localStorage fallback) ---
  const CH_NAME = "sm_help_channel";
  let bc = null; try { bc = new BroadcastChannel(CH_NAME); } catch {}
  const LS_CH_KEY = "sm_help_signal";
  function announceAuth(){
    const msg = { t:"auth", ts: now() };
    if (bc) bc.postMessage(msg);
    try { localStorage.setItem(LS_CH_KEY, JSON.stringify(msg)); } catch {}
  }
  function askForAuth(){
    const msg = { t:"ping", ts: now() };
    if (bc) bc.postMessage(msg);
    try { localStorage.setItem(LS_CH_KEY, JSON.stringify(msg)); } catch {}
  }
  function onMessage(msg){
    if (!msg || typeof msg !== "object") return;
    if (msg.t === "ping" && isAuthed()) {
      announceAuth();
    } else if (msg.t === "auth" && !hasTabAuth()) {
      sessionStorage.setItem(AUTH_SESS, MARK);
      startHeartbeat();
    }
  }
  if (bc) bc.onmessage = (e) => onMessage(e.data);
  window.addEventListener("storage", (e) => {
    if (e.key === LS_CH_KEY && e.newValue) { try { onMessage(JSON.parse(e.newValue)); } catch {} }
    if (e.key === HB_KEY && hasGlobalAuth() && !hasTabAuth()) {
      sessionStorage.setItem(AUTH_SESS, MARK);
      startHeartbeat();
    }
  });

  // Run link-auth first; if still not authed, handshake & wait briefly
  await attemptLinkAuth();
  if (!isAuthed()) {
    askForAuth();
    await new Promise(r => setTimeout(r, HANDSHAKE_WAIT_MS));
  }

  // Guard deep links: hide by default, reveal only if allowed
  const path = location.pathname.replace(/\/+$/, "");
  const isGate = (path === "" || path === "/" || path.endsWith("/index.html"));

if (isGate) { reveal(); return; }

if (isAuthed()) {
  reveal();
} else {
  // brief retry so adoption/handshake can land before we bounce
  await new Promise(r => setTimeout(r, 150));
  if (isAuthed()) {
    reveal();
  } else {
    const next = location.pathname + location.search + location.hash;
    location.replace("/?next=" + encodeURIComponent(next));
  }

  if (isAuthed()) {
    // Auth confirmed -> show page
    reveal();
  } else {
    // Not authed -> bounce to gate without showing content
    const next = location.pathname + location.search + location.hash;
    location.replace("/?next=" + encodeURIComponent(next));
  }
})();
