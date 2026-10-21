/* 南国市議会DXポータル Service Worker
   ・ホーム画面アイコン(ショートカット)をWebアプリとして扱わせるための最小構成
   ・ログイン状態・個人データが古い画面で残る事故を避けるため、キャッシュは一切しない
     (fetchを横取りしない＝通常のネットワーク通信のまま)
   ・お知らせの開始前通知(Push)を受けたら、通知を出してアイコンの数字を+1する
     (iPhoneは通知を出さないPushが禁止のため、必ず通知を出す) */
'use strict';

const BADGE_DB = 'gikai-portal-badge';
const BADGE_STORE = 'kv';
const BADGE_KEY = 'count';
const DEFAULT_TITLE = '南国市議会ポータル';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

function openBadgeDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(BADGE_DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(BADGE_STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

// 受信ごとに+1した数を返す(トップ画面を開くと app-badge.js が0に戻す)
async function incrementBadgeCount() {
  const db = await openBadgeDb();
  try {
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(BADGE_STORE, 'readwrite');
      const store = tx.objectStore(BADGE_STORE);
      const getReq = store.get(BADGE_KEY);
      let next = 1;
      getReq.onsuccess = () => {
        next = (Number(getReq.result) || 0) + 1;
        store.put(next, BADGE_KEY);
      };
      tx.oncomplete = () => resolve(next);
      tx.onerror = () => reject(tx.error);
    });
  } finally {
    db.close();
  }
}

// 通知タップ時の遷移先は、このサイトの範囲内のパスだけを許可する
function safeTargetUrl(raw) {
  const scope = self.registration.scope;
  try {
    const url = new URL(String(raw || ''), scope);
    if (url.origin === self.location.origin && url.href.startsWith(scope)) return url.href;
  } catch (_) { /* 不正な値は既定へ */ }
  return new URL('index.html', scope).href;
}

self.addEventListener('push', (event) => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (_) { payload = {}; }
  const title = typeof payload.title === 'string' && payload.title ? payload.title.slice(0, 60) : DEFAULT_TITLE;
  const body = typeof payload.body === 'string' ? payload.body.slice(0, 200) : 'まもなく開始のお知らせがあります';
  const url = safeTargetUrl(payload.url);

  event.waitUntil((async () => {
    try {
      const count = await incrementBadgeCount();
      if (self.navigator && typeof self.navigator.setAppBadge === 'function') {
        await self.navigator.setAppBadge(count);
      }
    } catch (_) { /* 印が出せなくても通知は出す */ }
    await self.registration.showNotification(title, {
      body,
      icon: 'icons/icon-192.png',
      badge: 'icons/icon-192.png',
      tag: typeof payload.tag === 'string' ? payload.tag.slice(0, 64) : undefined,
      data: { url }
    });
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = safeTargetUrl(event.notification.data && event.notification.data.url);
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (client.url.startsWith(self.registration.scope) && 'focus' in client) {
        if ('navigate' in client) { try { await client.navigate(url); } catch (_) { /* 同一画面のまま */ } }
        return client.focus();
      }
    }
    return self.clients.openWindow(url);
  })());
});
