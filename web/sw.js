// Service Worker DESHABILITADO - Limpia toda la caché
// Este SW se auto-desregistra para forzar actualizaciones

const CACHE_VERSION = 'clear-cache-v' + Date.now();

// Al instalarse, eliminar TODO el caché anterior
self.addEventListener('install', (event) => {
  console.log('[SW] Instalando - limpiando caché...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          console.log('[SW] Eliminando caché:', cacheName);
          return caches.delete(cacheName);
        })
      );
    }).then(() => {
      self.skipWaiting();
    })
  );
});

// Al activarse, tomar control inmediatamente y limpiar
self.addEventListener('activate', (event) => {
  console.log('[SW] Activado - tomando control...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          console.log('[SW] Eliminando caché viejo:', cacheName);
          return caches.delete(cacheName);
        })
      );
    }).then(() => {
      // Desregistrar este service worker
      return self.registration.unregister();
    }).then(() => {
      console.log('[SW] Service Worker desregistrado');
      return self.clients.claim();
    })
  );
});

// NO cachear nada - siempre ir a la red
self.addEventListener('fetch', (event) => {
  // Simplemente pasar la petición a la red, sin cachear
  event.respondWith(fetch(event.request));
});
