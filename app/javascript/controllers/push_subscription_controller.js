import { Controller } from "@hotwired/stimulus"

// "Turn on for this browser" in Settings → Notifications (docs/design/notifications.md, Phones and browsers). The offer
// shows only where push works and this browser isn't already one of the person's devices: the page lists a SHA-256 of
// each of their endpoints, never the endpoints, which work as secrets. Turning it on asks for permission, registers the
// service worker, subscribes with the VAPID public key and submits the hidden form; Turbo shows the page again with the
// device listed. If permission is refused, it says how to allow it, and if the browser can't subscribe, it says so.
export default class extends Controller {
  static targets = [ "offer", "refused", "failed", "form" ]
  static values = { publicKey: String, subscribed: Array }

  async connect() {
    if (!this.supported) return

    const registration = await navigator.serviceWorker.getRegistration("/")
    const subscription = await registration?.pushManager.getSubscription()
    if (subscription && this.subscribedValue.includes(await this.digest(subscription.endpoint))) return

    this.offerTarget.hidden = false
  }

  async subscribe() {
    this.refusedTarget.hidden = this.failedTarget.hidden = true
    if (await Notification.requestPermission() !== "granted") {
      this.refusedTarget.hidden = false
      return
    }

    // A private window, or a push service that's down, can refuse the worker or the subscription.
    try {
      const registration = await navigator.serviceWorker.register("/service-worker", { scope: "/" })
      await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription() ||
        await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: this.applicationServerKey })
      this.submit(subscription.toJSON())
    } catch {
      this.failedTarget.hidden = false
    }
  }

  submit({ endpoint, keys }) {
    const standalone = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true
    const fields = { endpoint, p256dh_key: keys.p256dh, auth_key: keys.auth, standalone }
    for (const [ name, value ] of Object.entries(fields)) this.formTarget.elements[`push_subscription[${name}]`].value = value
    this.formTarget.requestSubmit()
  }

  get supported() {
    return this.publicKeyValue && window.isSecureContext && "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  // The VAPID public key comes URL-safe Base64; the browser wants its bytes.
  get applicationServerKey() {
    const base64 = this.publicKeyValue.replace(/-/g, "+").replace(/_/g, "/")
    return Uint8Array.from(atob(base64), character => character.charCodeAt(0))
  }

  async digest(text) {
    const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)))
    return Array.from(bytes, byte => byte.toString(16).padStart(2, "0")).join("")
  }
}
