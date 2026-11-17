// Shows Aglowy's pushes and opens them (docs/design/notifications.md, Push). It caches nothing: Aglowy isn't an offline
// app. The payload is { title, body, url, tag }, one line and never personal text.
self.addEventListener("push", (event) => {
  const { title, body, url, tag } = event.data.json()
  event.waitUntil(self.registration.showNotification(title, { body, tag, icon: "/icon-192.png", data: { url } }))
})

// Tapping one focuses an Aglowy window already on its page, or opens one there.
self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const url = new URL(event.notification.data.url, self.location.origin).href

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windows) => {
      const open = windows.find((client) => client.url === url && "focus" in client)
      return open ? open.focus() : clients.openWindow(url)
    })
  )
})
