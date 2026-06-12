const CACHE_NAME = 'just-sign-v1';
const ASSETS = [
  './',
  './index.html',
  './editor.css',
  './editor.js',
  './manifest.json',
  './icons/icon128.png',
  './icons/icon512.png',
  './libs/pdf.min.js',
  './libs/pdf.worker.min.js',
  './libs/pdf-lib.min.js',
  './libs/standard_fonts/LiberationSans-Regular.ttf',
  './libs/standard_fonts/LiberationSans-Bold.ttf',
  './libs/standard_fonts/LiberationSans-Italic.ttf',
  './libs/standard_fonts/LiberationSans-BoldItalic.ttf',
  './libs/standard_fonts/FoxitDingbats.pfb',
  './libs/standard_fonts/FoxitFixed.pfb',
  './libs/standard_fonts/FoxitFixedBold.pfb',
  './libs/standard_fonts/FoxitFixedBoldItalic.pfb',
  './libs/standard_fonts/FoxitFixedItalic.pfb',
  './libs/standard_fonts/FoxitSerif.pfb',
  './libs/standard_fonts/FoxitSerifBold.pfb',
  './libs/standard_fonts/FoxitSerifBoldItalic.pfb',
  './libs/standard_fonts/FoxitSerifItalic.pfb',
  './libs/standard_fonts/FoxitSymbol.pfb'
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS);
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  e.respondWith(
    caches.match(e.request).then((cachedResponse) => {
      if (cachedResponse) {
        return cachedResponse;
      }
      return fetch(e.request).then((networkResponse) => {
        return networkResponse;
      });
    })
  );
});


