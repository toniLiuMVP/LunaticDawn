/* LD4 修改器 Service Worker v1.0 (2026-05-18)
 *
 * 策略:
 *   - HTML(導航):network-first → 失敗 fallback cache(保留自動更新 + 離線可用)
 *   - 靜態資源(JSON / CSS / 字典):cache-first → 失敗 fallback network(快 + 離線可用)
 *   - 不快取:bridge HTTP API(/status /read /write /scan)+ 跨域資源
 */

const CACHE_VERSION = 'ld4-modifier-v1.0-20260518';
const CORE = [
  './savedata-viewer.html',
  './manifest.json',
  './big5-encoder-table.json'
];

self.addEventListener('install', (evt) => {
  evt.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(CORE).catch(() => {}))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (evt) => {
  evt.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (evt) => {
  const req = evt.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // 不快取:bridge HTTP API + 跨域
  if (url.hostname === '127.0.0.1' || url.hostname === 'localhost') return;
  if (url.origin !== self.location.origin) return;

  // HTML:network-first
  if (req.mode === 'navigate' || req.destination === 'document') {
    evt.respondWith(
      fetch(req)
        .then((res) => {
          if (res && res.ok) {
            const clone = res.clone();
            caches.open(CACHE_VERSION).then((c) => c.put(req, clone));
          }
          return res;
        })
        .catch(() => caches.match(req).then((cached) => cached || caches.match('./savedata-viewer.html')))
    );
    return;
  }

  // 靜態資源:cache-first
  evt.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((res) => {
        if (res && res.ok && res.type === 'basic') {
          const clone = res.clone();
          caches.open(CACHE_VERSION).then((c) => c.put(req, clone));
        }
        return res;
      });
    })
  );
});
