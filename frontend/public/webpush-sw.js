/* eslint-disable no-restricted-globals */
/**
 * Service Worker для Next.js PWA
 * Обрабатывает кэширование, push-уведомления и офлайн-режим
 * Версия: v2.0.0
 */

const STATIC_CACHE = "ringo-static-v2";
const API_CACHE = "ringo-api-v2";
const CACHE_VERSION = "v2";

// Базовые ресурсы для pre-cache
const STATIC_ASSETS = [
  "/",
  "/manifest.json",
  "/favicon.ico",
];

// Таймауты (в миллисекундах)
const NETWORK_TIMEOUT = 8000;
const API_TIMEOUT = 10000;
const MAX_RETRIES = 2;

// Установка Service Worker
self.addEventListener("install", (event) => {
  console.log(`[SW] Installing ${CACHE_VERSION}...`);
  event.waitUntil(
    caches
      .open(STATIC_CACHE)
      .then((cache) => {
        console.log("[SW] Caching static assets");
        return cache.addAll(STATIC_ASSETS).catch((err) => {
          console.warn("[SW] Failed to cache some assets:", err);
          // Продолжаем даже если некоторые ресурсы не закэшировались
        });
      })
      .then(() => self.skipWaiting())
  );
});

// Активация: очистка старых кэшей
self.addEventListener("activate", (event) => {
  console.log(`[SW] Activating ${CACHE_VERSION}...`);
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key !== STATIC_CACHE && key !== API_CACHE)
            .map((key) => {
              console.log("[SW] Deleting old cache:", key);
              return caches.delete(key);
            })
        )
      )
      .then(() => self.clients.claim())
  );
});

// Функция для выполнения запроса с таймаутом
function fetchWithTimeout(request, timeout) {
  return Promise.race([
    fetch(request),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error("Network timeout")), timeout)
    ),
  ]);
}

// Функция для retry запросов с правильной обработкой ошибок
async function fetchWithRetry(request, maxRetries = MAX_RETRIES, timeout = NETWORK_TIMEOUT) {
  let lastError;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetchWithTimeout(request, timeout);
      
      // Если получили ответ (даже с ошибкой), возвращаем его
      // Не делаем retry для клиентских ошибок (4xx)
      if (response.status < 500 || attempt === maxRetries) {
        return response;
      }
      
      // Для серверных ошибок (5xx) делаем retry
      if (response.status >= 500 && attempt < maxRetries) {
        console.warn(`[SW] Server error ${response.status}, retrying (${attempt}/${maxRetries})...`);
        await new Promise((resolve) => setTimeout(resolve, 1000 * attempt));
        continue;
      }
      
      return response;
    } catch (error) {
      lastError = error;
      console.warn(`[SW] Fetch attempt ${attempt} failed:`, error.message);
      
      if (attempt < maxRetries) {
        await new Promise((resolve) => setTimeout(resolve, 1000 * attempt));
      }
    }
  }
  
  // Если все попытки провалились, пробуем кэш (только для GET)
  if (request.method === "GET") {
    const cached = await caches.match(request);
    if (cached) {
      console.log("[SW] Using cached response after network failure");
      return cached;
    }
  }
  
  // Если кэша нет, возвращаем ошибку
  throw lastError || new Error("All fetch attempts failed");
}

// Перехват запросов
self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Пропускаем не-GET запросы (кроме специальных случаев)
  if (request.method !== "GET" && request.method !== "HEAD") {
    return;
  }

  // Пропускаем запросы к другим доменам
  if (url.origin !== self.location.origin) {
    return;
  }

  // Статические ресурсы Next.js — cache-first
  if (
    url.pathname === "/" ||
    url.pathname.startsWith("/_next/static/") ||
    url.pathname.startsWith("/icons/") ||
    url.pathname === "/manifest.json" ||
    url.pathname === "/favicon.ico" ||
    /\.(png|jpg|jpeg|svg|woff|woff2|ttf|ico)$/.test(url.pathname)
  ) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // API запросы — network-first с fallback на кэш
  if (url.pathname.startsWith("/api/")) {
    event.respondWith(networkFirstWithCache(request));
    return;
  }

  // Навигационные запросы (страницы) — network-first с fallback
  if (request.mode === "navigate") {
    event.respondWith(networkFirstWithCache(request, NETWORK_TIMEOUT));
    return;
  }

  // Остальные запросы — пропускаем без перехвата
});

// Cache-first стратегия для статики
async function cacheFirst(request) {
  const cache = await caches.open(STATIC_CACHE);
  const cached = await cache.match(request);
  
  if (cached) {
    // Обновляем кэш в фоне
    fetchWithTimeout(request, NETWORK_TIMEOUT)
      .then((response) => {
        if (response.ok) {
          cache.put(request, response.clone());
        }
      })
      .catch(() => {
        // Игнорируем ошибки обновления кэша
      });
    return cached;
  }
  
  // Если нет в кэше, пробуем сеть
  try {
    const response = await fetchWithRetry(request, 1, NETWORK_TIMEOUT);
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.error("[SW] Cache-first failed:", error);
    return new Response("Resource not available", {
      status: 503,
      statusText: "Service Unavailable",
      headers: { "Content-Type": "text/plain" },
    });
  }
}

// Network-first стратегия с fallback на кэш
async function networkFirstWithCache(request, timeout = API_TIMEOUT) {
  try {
    const response = await fetchWithRetry(request, MAX_RETRIES, timeout);
    
    // Кэшируем только успешные ответы
    if (response.ok && request.method === "GET") {
      const cache = await caches.open(
        request.url.includes("/api/") ? API_CACHE : STATIC_CACHE
      );
      cache.put(request, response.clone());
    }
    
    return response;
  } catch (error) {
    console.warn("[SW] Network request failed, trying cache:", error.message);
    
    // Пробуем кэш только для GET запросов
    if (request.method === "GET" || request.method === "HEAD") {
      const cache = await caches.open(
        request.url.includes("/api/") ? API_CACHE : STATIC_CACHE
      );
      const cached = await cache.match(request);
      
      if (cached) {
        console.log("[SW] Serving from cache");
        return cached;
      }
    }
    
    // Если это навигационный запрос и нет кэша, возвращаем базовую страницу
    if (request.mode === "navigate") {
      return new Response(
        '<!DOCTYPE html><html><head><title>Офлайн</title><meta charset="utf-8"></head><body><h1>Нет подключения к интернету</h1><p>Проверьте подключение и обновите страницу.</p></body></html>',
        {
          status: 503,
          statusText: "Service Unavailable",
          headers: { "Content-Type": "text/html; charset=utf-8" },
        }
      );
    }
    
    // Для API запросов возвращаем JSON ошибку
    return new Response(
      JSON.stringify({
        detail: "Сеть недоступна",
        error: "NETWORK_ERROR",
      }),
      {
        status: 503,
        statusText: "Service Unavailable",
        headers: { "Content-Type": "application/json; charset=utf-8" },
      }
    );
  }
}

// Обработка push-уведомлений
self.addEventListener("push", (event) => {
  if (!event.data) {
    return;
  }

  let payload = {};
  try {
    payload = event.data.json();
  } catch {
    payload = { body: event.data.text() };
  }

  const title = payload.title || "Ringo Учет";
  const options = {
    body: payload.body || "",
    icon: payload.icon || "/icons/icon-192.svg",
    badge: payload.badge || "/icons/icon-192.svg",
    data: {
      url: payload.url || "/",
    },
    requireInteraction: false,
    tag: payload.tag || "ringo-notification",
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Обработка клика по уведомлению
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  
  const url = (event.notification.data && event.notification.data.url) || "/";

  event.waitUntil(
    self.clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((windowClients) => {
        // Ищем открытое окно с нужным URL
        for (const client of windowClients) {
          if (client.url.includes(url) && "focus" in client) {
            return client.focus();
          }
        }
        // Если окна нет, открываем новое
        if (self.clients.openWindow) {
          return self.clients.openWindow(url);
        }
        return undefined;
      })
  );
});

// Обработка сообщений от основного потока
self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "CLEAR_API_CACHE") {
    console.log("[SW] Clearing API cache");
    caches.open(API_CACHE).then((cache) => {
      cache.keys().then((keys) => {
        keys.forEach((key) => {
          if (key.url.includes("/api/")) {
            cache.delete(key);
          }
        });
      });
    });
  }
  
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});
