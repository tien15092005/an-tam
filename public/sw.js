// Service worker tối giản: cho phép cài app (PWA) và hiện thông báo.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

// Bấm vào thông báo -> mở lại ứng dụng
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const target = e.notification.data?.url || '/';
  e.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of all) {
      if (new URL(c.url).pathname === target && 'focus' in c) return c.focus();
    }
    return self.clients.openWindow(target);
  })());
});

// Chỗ để gắn Web Push sau này (nhắc cả khi app đã đóng)
self.addEventListener('push', e => {
  const data = e.data ? e.data.json() : {};
  e.waitUntil(self.registration.showNotification(data.title || 'An Tâm', {
    body: data.body || '', icon: '/icon.svg', data: { url: data.url || '/' },
  }));
});
