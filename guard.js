;(() => {
  const PW_HASH = "1abe8f5aca6045c7844a07b0e09fb57039cb2c5923de729dfce9d07f28624971"; // <-- set me (64 hex chars)
  const KEY_SESSION = "sm_help_authed_session";
  const KEY_PERSIST = "sm_help_authed_persist";
  const CH_NAME = "sm_help_bc_v1";

  function isAuthed() {
    try {
      return sessionStorage.getItem(KEY_SESSION) === "1" || localStorage.getItem(KEY_PERSIST) === "1";
    } catch { return false; }
  }

  function setAuthed(persist = true) {
    try {
      sessionStorage.setItem(KEY_SESSION, "1");
      if (persist) localStorage.setItem(KEY_PERSIST, "1");
    } catch {}
    // inform other tabs
    try {
      bc.postMessage({ t: "authed" });
    } catch {}
  }

  function clearAuthed() {
    try {
      sessionStorage.removeItem(KEY_SESSION);
      localStorage.removeItem(KEY_PERSIST);
    } catch {}
    try { bc.postMessage({ t: "logged_out" }); } catch {}
  }

  // BroadcastChannel handshake so one authed tab can unlock another without retyping
  let bc = null;
  try {
    bc = new BroadcastChannel(CH_NAME);
    bc.onmessage = (ev) => {
      const msg = ev.data || {};
      if (msg.t === "whois" && isAuthed()) {
        bc.postMessage({ t: "iam", ok: true });
      } else if (msg.t === "iam" && msg.ok && !isAuthed()) {
        // Another tab confirmed auth; mirror it
        setAuthed(true);
      }
    };
    // Ask if anyone is authed
    bc.postMessage({ t: "whois" });
  } catch {}

  // Optional link-auth: accept ?pw=<sha256-of-password> and immediately auth then clean URL
  (function linkAuth() {
    const u = new URL(location.href);
    const pw = u.searchParams.get("pw");
    if (pw && typeof pw === "string" && pw.length === 64) {
      if (pw.toLowerCase() === PW_HASH.toLowerCase()) {
        setAuthed(true);
      }
      // Clean the URL (preserve everything else, including ?v=)
      u.searchParams.delete("pw");
      const clean = u.pathname + (u.search ? u.search : "") + u.hash;
      if (clean !== (location.pathname + location.search + location.hash)) {
        history.replaceState(null, "", clean);
      }
    }
  })();

  // If we’re on a non-index HTML page and not authed, bounce to index with next=<this>
  (function gateContentPages() {
    const path = location.pathname.toLowerCase();
    const isIndex = path === "/" || path.endsWith("/index.html");
    const isHtml = path.endsWith(".html") || path.endsWith(".htm");
    if (!isIndex && isHtml && !isAuthed()) {
      const here = location.pathname + location.search + location.hash;
      const u = new URL("/", location.origin);
      const search = new URLSearchParams();
      search.set("next", here.replace(/^\//, "")); // relative
      // preserve v if present
      const v = new URL(location.href).searchParams.get("v");
      if (v) search.set("v", v);
      u.search = search.toString();
      location.replace(u.pathname + "?" + u.searchParams.toString());
    }
  })();

  // Deduplicate multiple ?v= on any page (safety)
  (function normalizeV() {
    const u = new URL(location.href);
    const vs = u.searchParams.getAll("v");
    if (vs.length > 1) {
      const last = vs[vs.length - 1];
      u.searchParams.delete("v");
      if (last) u.searchParams.set("v", last);
      const normalized = u.pathname + (u.search ? u.search : "") + u.hash;
      if (normalized !== (location.pathname + location.search + location.hash)) {
        location.replace(normalized);
      }
    }
  })();

  // Expose API
  window.SM_HELP = {
    PW_HASH,
    isAuthed,
    setAuthed,
    clearAuthed
  };
})();
