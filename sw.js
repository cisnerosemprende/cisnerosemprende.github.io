// =========================================================================
// Service Worker: Cisneros Emprende PWA (Network-First para HTML)
// =========================================================================

const CACHE_NAME = 'cisneros-emprende-v24';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // No interceptar llamadas a Supabase, WhatsApp o extensiones
  if (url.hostname.includes('supabase.co') || url.hostname.includes('wa.me') || (url.protocol !== 'http:' && url.protocol !== 'https:')) {
    return;
  }

  // Para navegacion o index.html: Network First siempre
  if (event.request.mode === 'navigate' || url.pathname.endsWith('.html') || url.pathname === '/') {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(event.request))
    );
    return;
  }

  // Para otros assets estaticos
  event.respondWith(
    caches.match(event.request).then((cached) => {
      return cached || fetch(event.request);
    })
  );
});
