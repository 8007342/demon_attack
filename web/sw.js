// pwa-install: the game's service worker (openspec/changes/pwa-install).
//
// Deliberately small and cache-free: every request still goes to the
// network, so a new deploy is live on the next load and no stale build is
// ever served. Its fetch handler exists so Chromium treats the site as an
// installable app (and fires `beforeinstallprompt`); it answers page
// navigations network-first, with a short offline notice when the network
// is down. Assets, audio and /api requests are left to the browser.
'use strict';

const OFFLINE_PAGE = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#100e2c"><title>Demon Attack</title>
<style>html,body{margin:0;height:100%;background:#090d12;color:#d7e5ef;font:14px monospace}
body{display:flex;align-items:center;justify-content:center;text-align:center;letter-spacing:2px}
b{color:#70f5d5;display:block;font-size:18px;margin-bottom:12px}</style></head>
<body><div><b>DEMON ATTACK</b>NO SIGNAL · RECONNECT TO PLAY</div></body></html>`;

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || request.mode !== 'navigate') return;
  event.respondWith(
    fetch(request).catch(
      () => new Response(OFFLINE_PAGE, {
        status: 503,
        headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' },
      }),
    ),
  );
});
