self.addEventListener("install", (e) => {
  self.skipWaiting();
});
self.addEventListener("activate", (e) => {
  e.waitUntil(clients.claim());
});
self.addEventListener("fetch", (event) => {
  // Network-first, no custom caching; rely on server + URL versioning
  event.respondWith(fetch(event.request).catch(() => fetch(event.request)));
});
