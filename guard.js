// guard.js — very basic client-side gate (session per tab)
(function () {
  // 1) Replace with your SHA-256 hex of the password
  const PW_HASH = "1abe8f5aca6045c7844a07b0e09fb57039cb2c5923de729dfce9d07f28624971";

  // 2) Session flag (clears when tab/window closes)
  const KEY  = "sm_help_auth";
  const MARK = "ok:" + PW_HASH;

  // Expose helpers so index.html can reuse them
  window.SM_HELP = {
    PW_HASH,
    setAuthed() { sessionStorage.setItem(KEY, MARK); },
    isAuthed()  { return sessionStorage.getItem(KEY) === MARK; }
  };

  // 3) Block deep links: if a topic page is opened without auth, bounce to '/'
  const path = location.pathname.replace(/\/+$/, "");
  const isGate = path === "" || path === "/" || path.endsWith("/index.html");
  if (!isGate && !window.SM_HELP.isAuthed()) {
    const next = location.pathname + location.search + location.hash;
    location.replace("/?next=" + encodeURIComponent(next));
  }
})();
