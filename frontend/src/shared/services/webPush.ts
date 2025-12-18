import { httpClient } from "@/shared/api/httpClient";

function getVapidPublicKey(): string | null {
  const key = process.env.NEXT_PUBLIC_WEBPUSH_VAPID_PUBLIC_KEY;
  return key && key.trim().length > 0 ? key : null;
}

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; i += 1) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

export async function registerWebPush(): Promise<void> {
  if (typeof window === "undefined") {
    return;
  }

  if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
    return;
  }

  if (!("Notification" in window)) {
    return;
  }

  const permission = await Notification.requestPermission();
  if (permission !== "granted") {
    return;
  }

  const vapidKey = getVapidPublicKey();
  if (!vapidKey) {
    // Без VAPID ключа подписка на push невозможна
    return;
  }

  const registration = await navigator.serviceWorker.register("/webpush-sw.js");

  let subscription = await registration.pushManager.getSubscription();
  if (!subscription) {
    const applicationServerKey = urlBase64ToUint8Array(vapidKey) as unknown as BufferSource;
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey,
    });
  }

  const subscriptionJson = subscription.toJSON();
  const token = subscription.endpoint;

  const deviceInfo = {
    userAgent: window.navigator.userAgent,
    language: window.navigator.language,
    platform: window.navigator.platform,
    screen: {
      width: window.screen.width,
      height: window.screen.height,
    },
    subscription: subscriptionJson,
  };

  try {
    await httpClient.post("/notifications/device-tokens/", {
      token,
      platform: "web",
      app_version: process.env.NEXT_PUBLIC_ENV ?? "web",
      device_info: deviceInfo,
    });
  } catch {
    // Регистрация web push не должна ломать UI, поэтому ошибки глушим
  }
}


