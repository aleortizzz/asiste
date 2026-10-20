// Service worker de Asiste: por ahora solo recibe notificaciones push (el
// aviso de registros del superadmin, ver src/lib/push.js). A propósito NO
// tiene handler de `fetch`: no guarda nada en caché ni intercepta pedidos,
// así un deploy nunca queda trabado con archivos viejos.

self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()))

self.addEventListener('push', (event) => {
  const data = event.data?.json() ?? {}
  event.waitUntil(
    self.registration.showNotification(data.title ?? 'Asiste', {
      body: data.body ?? '',
      icon: '/icon-192.png?v=2',
      badge: '/favicon-32.png?v=5',
      data: { url: data.url ?? '/admin' },
    }),
  )
})

// Tocar el aviso: si Asiste ya está abierto, lo trae al frente en esa página; si no, lo abre.
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = new URL(event.notification.data?.url ?? '/admin', self.location.origin).href
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((wins) => {
      const win = wins.find((w) => w.url.startsWith(self.location.origin))
      if (!win) return self.clients.openWindow(url)
      return win
        .focus()
        .then(() => win.navigate(url))
        .catch(() => self.clients.openWindow(url))
    }),
  )
})
