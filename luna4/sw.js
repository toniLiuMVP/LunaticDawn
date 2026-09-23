/* LD4 修改器 Service Worker v1.4 (2026-09-23)
 *
 * 策略:
 *   - HTML(導航):network-first,連不上網路時回快取版本
 *   - 靜態資源(JSON / CSS / 字典):stale-while-revalidate,先回快取,同時在背景抓新版寫回
 *   - 不快取:本機 bridge 的 HTTP API(/status /read /write /scan)與跨網域資源
 *
 * 行為:
 *   - precache 任一檔失敗就讓 install 失敗,舊 worker 與舊快取保持不變
 *   - 背景寫入快取都交給 event.waitUntil,worker 不會在寫完前被終止
 *   - 離線時只有修改器頁本身會回快取版本;luna4 底下其他沒快取過的頁面回網路錯誤
 *   - 這個網域上還有其他站台,所以只讀寫、只清理自己命名空間(ld4-modifier-)的快取
 */

const CACHE_PREFIX = 'ld4-modifier-';
const CACHE_VERSION = CACHE_PREFIX + 'v1.4-20260923';
const VIEWER_PATH = './savedata-viewer.html';
const CORE = [
  VIEWER_PATH,
  './manifest.json',
  './ld4_enum_table.json'
];

self.addEventListener('install', (evt) => {
  // addAll 是原子的:任一檔抓不到就整個 reject,install 失敗,繼續用舊 worker。
  // skipWaiting 只在 precache 成功之後才呼叫。
  evt.waitUntil(
    caches.open(CACHE_VERSION)
      .then((cache) => cache.addAll(CORE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (evt) => {
  evt.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k.startsWith(CACHE_PREFIX) && k !== CACHE_VERSION)
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// 只查自己的快取,不讀同網域其他站台的快取
function matchOwn(req) {
  return caches.open(CACHE_VERSION).then((c) => c.match(req));
}

// 這個請求是不是修改器頁本身(不論有沒有帶 query)
function isViewerRequest(url) {
  return url.pathname === new URL(VIEWER_PATH, self.location.href).pathname;
}

self.addEventListener('fetch', (evt) => {
  const req = evt.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // 不快取:bridge HTTP API + 跨網域
  if (url.hostname === '127.0.0.1' || url.hostname === 'localhost') return;
  if (url.origin !== self.location.origin) return;

  // HTML:network-first
  if (req.mode === 'navigate' || req.destination === 'document') {
    evt.respondWith(
      fetch(req)
        .then((res) => {
          if (res && res.ok) {
            const clone = res.clone();
            // respondWith 的 promise 還沒結束,這裡呼叫 waitUntil 仍然有效
            evt.waitUntil(caches.open(CACHE_VERSION).then((c) => c.put(req, clone)));
          }
          return res;
        })
        .catch(() => matchOwn(req).then((cached) => {
          if (cached) return cached;
          if (isViewerRequest(url)) {
            return matchOwn(VIEWER_PATH).then((viewer) => viewer || Response.error());
          }
          return Response.error();
        }))
    );
    return;
  }

  // 靜態資源:stale-while-revalidate
  // 背景更新在事件派送當下就交給 waitUntil,即使已經先回了快取也會寫完。
  const network = fetch(req);
  evt.waitUntil(
    network.then((res) => {
      if (res && res.ok && res.type === 'basic') {
        const clone = res.clone();
        return caches.open(CACHE_VERSION).then((c) => c.put(req, clone));
      }
      return undefined;
    }).catch(() => undefined)
  );
  evt.respondWith(
    matchOwn(req).then((cached) => cached || network.catch(() => Response.error()))
  );
});
