/* eslint-disable no-restricted-globals */

const CACHE_NAME = "ringo-web-cache-v1";
const STATIC_ASSETS = ["/", "/favicon.ico", "/manifest.json"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(STATIC_ASSETS)),
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key)),
      ),
    ),
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const { request } = event;

  if (request.method !== "GET") {
    return;
  }

  const url = new URL(request.url);

  // Кешируем только запросы к нашему домену
  if (url.origin !== self.location.origin) {
    return;
  }

  // Статика — cache-first
  if (STATIC_ASSETS.includes(url.pathname)) {
    event.respondWith(
      caches.match(request).then(
        (cached) =>
          cached ||
          fetch(request).then((response) => {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
            return response;
          }),
      ),
    );
    return;
  }

  // Для API — network-first с fallback в кеш (если вдруг закеширован)
  if (url.pathname.startsWith("/api/")) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          return response;
        })
        .catch(() =>
          caches.match(request).then((cached) => cached || Promise.reject()),
        ),
    );
  }
});

self.addEventListener("push", (event) => {
  let payload = {};
  try {
    if (event.data) {
      payload = event.data.json();
    }
  } catch {
    // ignored
  }

  const title = payload.title || "Ringo Uchet";
  const options = {
    body: payload.body || "Новое уведомление",
    icon: "/icons/icon-192x192.png",
    badge: "/icons/icon-96x96.png",
    data: payload.data || {},
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || "/";

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientsArr) => {
      const activeClient = clientsArr.find((client) => client.url === targetUrl);
      if (activeClient) {
        return activeClient.focus();
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
      return undefined;
    }),
  );
});

const STATIC_CACHE = "ringo-static-v1";
const API_CACHE = "ringo-api-v1";

// Базовый набор pre-cache ресурсов приложения
const STATIC_ASSETS = ["/", "/offline-queue", "/manifest.json"];

// Установка service worker: кэшируем базовые ресурсы
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    }),
  );
});

// Активация: чистим старые кэши
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== STATIC_CACHE && key !== API_CACHE)
          .map((key) => caches.delete(key)),
      ),
    ),
  );
});

// Обработка push-уведомлений
self.addEventListener("push", (event) => {
  if (!event.data) {
    return;
  }

  let payload = {};
  try {
    payload = event.data.json();
  } catch {
    // Если пришла не-JSON строка, показываем как текст
    payload = { body: event.data.text() };
  }

  const title = payload.title || "Ringo Учет";
  const options = {
    body: payload.body || "",
    icon: payload.icon || "/icons/icon-192.png",
    badge: payload.badge || "/icons/icon-96.png",
    data: {
      url: payload.url || "/",
    },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || "/";

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ("focus" in client) {
          if (client.url.includes(url)) {
            return client.focus();
          }
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(url);
      }
      return undefined;
    }),
  );
});

// Кэширование статики и API
self.addEventListener("fetch", (event) => {
  const { request } = event;

  if (request.method !== "GET") {
    return;
  }

  const url = new URL(request.url);

  // Статические ассеты Next.js и иконки — cache-first
  if (
    url.origin === self.location.origin &&
    (url.pathname === "/" ||
      url.pathname.startsWith("/_next/static/") ||
      url.pathname.startsWith("/icons/") ||
      url.pathname === "/manifest.json")
  ) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // API-запросы (в т.ч. к backend с /api/v1/ в пути)
  if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/api/v1/")) {
    // Лёгкие справочники — stale-while-revalidate
    if (
      url.pathname.includes("/equipment") ||
      url.pathname.includes("/services") ||
      url.pathname.includes("/materials") ||
      url.pathname.includes("/clients")
    ) {
      event.respondWith(staleWhileRevalidate(request));
      return;
    }

    // Критичные операции — network-first
    event.respondWith(networkFirst(request));
  }
});

async function cacheFirst(request) {
  const cache = await caches.open(STATIC_CACHE);
  const cached = await cache.match(request);
  if (cached) {
    return cached;
  }
  const response = await fetch(request);
  cache.put(request, response.clone());
  return response;
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(API_CACHE);
  const cachedPromise = cache.match(request);
  const networkPromise = fetch(request)
    .then((response) => {
      cache.put(request, response.clone());
      return response;
    })
    .catch(() => undefined);

  const cached = await cachedPromise;
  if (cached) {
    // Возвращаем кэш сразу, обновление — в фоне
    networkPromise.catch(() => undefined);
    return cached;
  }

  const network = await networkPromise;
  if (network) {
    return network;
  }

  return new Response("{" + '"detail":"Сеть недоступна"' + "}", {
    status: 503,
    headers: { "Content-Type": "application/json" },
  });
}

async function networkFirst(request) {
  try {
    const response = await fetch(request);
    const cache = await caches.open(API_CACHE);
    cache.put(request, response.clone());
    return response;
  } catch {
    const cache = await caches.open(API_CACHE);
    const cached = await cache.match(request);
    if (cached) {
      return cached;
    }

    return new Response("{" + '"detail":"Сеть недоступна"' + "}", {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }
}

