/* ホーム画面アイコン(ショートカット)の数字(印)と、Webアプリとしての初期化。
   議員団ポータルの public/app-badge.js を元にした南国市議会ポータル版。
   - 印はOSが描く。iPhoneは「数字なし」の印を表示しない(実機確認済み)ため、必ず数字を渡す。
   - iPhoneは「ホーム画面に追加したアイコンから開く」かつ「通知の許可」がある時だけ印が出る。
   - 数字は開始前通知(Push)を受けるたびに sw.js が+1する。トップ画面を開いたら clearBadge() で0に戻す。 */
(function () {
  'use strict';

  const BADGE_DB = 'gikai-portal-badge';
  const BADGE_STORE = 'kv';
  const BADGE_KEY = 'count';

  function isStandalone() {
    try {
      return window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
    } catch (_) { return false; }
  }

  function badgeSupported() {
    return typeof navigator !== 'undefined' && typeof navigator.setAppBadge === 'function';
  }

  async function setBadge(count) {
    if (!badgeSupported()) return;
    try {
      if (count > 0) await navigator.setAppBadge(count);
      else if (typeof navigator.clearAppBadge === 'function') await navigator.clearAppBadge();
    } catch (_) { /* 許可が無い等。画面の動作には影響させない */ }
  }

  function resetStoredCount() {
    return new Promise((resolve) => {
      try {
        const req = indexedDB.open(BADGE_DB, 1);
        req.onupgradeneeded = () => req.result.createObjectStore(BADGE_STORE);
        req.onsuccess = () => {
          const db = req.result;
          try {
            const tx = db.transaction(BADGE_STORE, 'readwrite');
            tx.objectStore(BADGE_STORE).put(0, BADGE_KEY);
            tx.oncomplete = () => { db.close(); resolve(); };
            tx.onerror = () => { db.close(); resolve(); };
          } catch (_) { db.close(); resolve(); }
        };
        req.onerror = () => resolve();
      } catch (_) { resolve(); }
    });
  }

  // トップ画面を見たら、通知で増えた数字を0に戻して印を消す
  async function clearBadge() {
    await resetStoredCount();
    await setBadge(0);
  }

  function notificationState() {
    if (typeof Notification === 'undefined') return 'unsupported';
    return Notification.permission; // default / granted / denied
  }

  // 通知の許可を求める。利用者のタップ操作から呼ぶこと(iPhoneの必須条件)。
  async function requestPermission() {
    if (typeof Notification === 'undefined') return 'unsupported';
    try { return await Notification.requestPermission(); } catch (_) { return Notification.permission; }
  }

  let registrationPromise = null;
  function registerServiceWorker() {
    if (!('serviceWorker' in navigator)) return Promise.resolve(null);
    if (!registrationPromise) {
      registrationPromise = navigator.serviceWorker.register('sw.js', { scope: './' })
        .catch(() => null); // 登録できなくても画面は通常動作
    }
    return registrationPromise;
  }

  registerServiceWorker();

  window.AppBadge = { isStandalone, badgeSupported, setBadge, clearBadge, notificationState, requestPermission, registerServiceWorker };
})();
