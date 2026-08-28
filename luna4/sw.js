/* LD4 修改器 Service Worker v1.0 (2026-05-18)
 *
 * 策略:
 *   - HTML(導航):network-first → 失敗 fallback cache(保留自動更新 + 離線可用)
 *   - 靜態資源(JSON / CSS / 字典):stale-while-revalidate → 先回快取、背景更新(快 + 離線可用 + 不會卡舊資料)
 *   - 不快取:bridge HTTP API(/status /read /write /scan)+ 跨域資源
 */

const CACHE_VERSION = 'ld4-modifier-v1.2-20260828';
const CORE = [
  './savedata-viewer.html',
  './manifest.json',
  './ld4_enum_table.json'
];

self.addEventListener('install', (evt) => {
  evt.waitUntil(
    caches.open(CACHE_VERSION).then((cache) =>
      // addAll is atomic: one missing file silently voids the whole precache.
      // Surface it instead of swallowing, so a renamed CORE entry is noticeable.
      cache.addAll(CORE).catch((err) => {
        console.warn('[sw] precache failed — offline start may be incomplete:', err);
      })
    )
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

  // 靜態資源:stale-while-revalidate
  // 原本是純 cache-first(命中就回、永不 revalidate),資料 JSON 更新後回訪者會一直
  // 拿到舊檔,直到有人手動 bump CACHE_VERSION 為止 —— 破字修正與資料擴充都因此漏送過。
  // 現在:命中快取先回(速度不變),同時背景抓新版寫回,下次進站就是新的。
  evt.respondWith(
    caches.match(req).then((cached) => {
      const network = fetch(req).then((res) => {
        if (res && res.ok && res.type === 'basic') {
          const clone = res.clone();
          caches.open(CACHE_VERSION).then((c) => c.put(req, clone));
        }
        return res;
      }).catch(() => cached);
      return cached || network;
    })
  );
});
