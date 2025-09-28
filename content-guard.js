// Run ASAP in <head> (no async/defer) to prevent first paint if not authed
(function () {
  var KEY_SESSION = "sm_help_authed_session";
  var KEY_PERSIST = "sm_help_authed_persist";
  var VALID_V = /^\d{4}-\d{2}-\d{2}-\d{6}$/;

  function isAuthed() {
    try {
      return sessionStorage.getItem(KEY_SESSION) === "1" ||
             localStorage.getItem(KEY_PERSIST) === "1";
    } catch (e) { return false; }
  }

  if (!isAuthed()) {
    // Hide immediately to avoid flicker
    try {
      // If HTML already started parsing, make it invisible
      document.write('<style>html{visibility:hidden !important}</style>');
    } catch (e) {}

    // Build redirect to index with ?next= and (only) a valid v
    var here = location.pathname + location.search + location.hash;
    var u = new URL("/", location.origin);
    var sp = new URLSearchParams();
    sp.set("next", here.replace(/^\//, ""));
    var v = new URL(location.href).searchParams.get("v");
    if (v && VALID_V.test(v)) sp.set("v", v);
    u.search = sp.toString();

    // Redirect before the page paints
    location.replace(u.pathname + "?" + u.searchParams.toString());
  } else {
    // Already authed: ensure the page is visible (in case any hide CSS slipped in)
    try { document.write('<style>html{visibility:visible !important}</style>'); } catch (e) {}
  }
})();
