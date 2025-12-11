// Service Worker для PWA кэширования
// Кэширует статические ресурсы и API ответы для офлайн работы
// Улучшено для работы на мобильном интернете с таймаутами и retry

const CACHE_NAME = 'ringo-uchet-v4';
const STATIC_CACHE_NAME = 'ringo-static-v4';
const API_CACHE_NAME = 'ringo-api-v4';

// Таймауты для запросов (в миллисекундах)
const NETWORK_TIMEOUT = 10000; // 10 секунд для обычных запросов
const API_TIMEOUT = 15000; // 15 секунд для API запросов
const NAVIGATION_TIMEOUT = 8000; // 8 секунд для навигации

// Максимальное количество попыток retry
const MAX_RETRIES = 3;
const RETRY_DELAY = 1000; // 1 секунда между попытками

// Ресурсы для кэширования при установке
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

// Установка Service Worker
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing v4...');
  event.waitUntil(
    caches.open(STATIC_CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Caching static assets');
      return cache.addAll(STATIC_ASSETS).catch((err) => {
        console.warn('[Service Worker] Failed to cache some assets:', err);
        // Продолжаем даже если некоторые ресурсы не закэшировались
      });
    })
  );
  self.skipWaiting(); // Активируем сразу
});

// Активация Service Worker
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating v4...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          // Удаляем старые кэши
          if (cacheName !== STATIC_CACHE_NAME && 
              cacheName !== API_CACHE_NAME && 
              cacheName !== CACHE_NAME) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  return self.clients.claim(); // Берем контроль над всеми страницами
});

// Функция для выполнения запроса с таймаутом
function fetchWithTimeout(request, timeout) {
  // Убеждаемся что request - это Request объект
  const req = request instanceof Request ? request : new Request(request);
  return Promise.race([
    fetch(req),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Network timeout')), timeout)
    )
  ]);
}

// Функция для retry запросов
async function fetchWithRetry(request, maxRetries = MAX_RETRIES, timeout = NETWORK_TIMEOUT) {
  let lastError;
  
  // Сохраняем параметры запроса для создания новых Request объектов
  // Клонируем request ДО использования, чтобы получить body
  const requestClone = request.clone();
  const url = request.url;
  
  // Получаем body если есть (для POST/PUT/DELETE)
  let bodyData = null;
  if (request.body !== null && request.method !== 'GET' && request.method !== 'HEAD') {
    try {
      bodyData = await requestClone.arrayBuffer();
    } catch (e) {
      // Если не удалось получить body, пробуем без него
      console.warn('[Service Worker] Could not clone request body:', e);
    }
  }
  
  // Копируем headers
  const headers = new Headers();
  if (request.headers) {
    request.headers.forEach((value, key) => {
      headers.append(key, value);
    });
  }
  
  const init = {
    method: request.method,
    headers: headers,
    body: bodyData,
    mode: request.mode,
    credentials: request.credentials,
    cache: request.cache,
    redirect: request.redirect,
    referrer: request.referrer,
    integrity: request.integrity,
  };
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      // Создаем новый Request объект для каждой попытки
      const newRequest = new Request(url, init);
      console.log(`[Service Worker] Fetch attempt ${attempt}/${maxRetries} for ${url}`);
      const response = await fetchWithTimeout(newRequest, timeout);
      
      // Проверяем успешность ответа
      if (response.ok || response.status < 500) {
        return response;
      }
      
      // Если ошибка сервера (5xx), пробуем еще раз
      if (response.status >= 500 && attempt < maxRetries) {
        console.warn(`[Service Worker] Server error ${response.status}, retrying...`);
        await new Promise(resolve => setTimeout(resolve, RETRY_DELAY * attempt));
        continue;
      }
      
      return response;
    } catch (error) {
      lastError = error;
      console.warn(`[Service Worker] Fetch attempt ${attempt} failed:`, error.message);
      
      if (attempt < maxRetries) {
        // Экспоненциальная задержка между попытками
        const delay = RETRY_DELAY * Math.pow(2, attempt - 1);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  
  throw lastError || new Error('All fetch attempts failed');
}

// Перехват запросов
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // НЕ перехватываем запросы к другим доменам (CORS)
  if (url.origin !== self.location.origin) {
    return; // Пропускаем, пусть браузер обрабатывает
  }

  // Стратегия для статических ресурсов: Cache First с Network Fallback
  if (isStaticAsset(request.url)) {
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        if (cachedResponse) {
          // Обновляем кэш в фоне
          fetchWithTimeout(request, NETWORK_TIMEOUT)
            .then((networkResponse) => {
              if (networkResponse.ok) {
                caches.open(STATIC_CACHE_NAME).then((cache) => {
                  cache.put(request, networkResponse.clone());
                });
              }
            })
            .catch(() => {
              // Игнорируем ошибки обновления кэша
            });
          return cachedResponse;
        }
        
        // Если нет в кэше, пробуем сеть
        return fetchWithRetry(request, 2, NETWORK_TIMEOUT)
          .then((response) => {
            if (response.ok) {
              const responseToCache = response.clone();
              caches.open(STATIC_CACHE_NAME).then((cache) => {
                cache.put(request, responseToCache);
              });
            }
            return response;
          })
          .catch(() => {
            // Если сеть недоступна, возвращаем базовый ответ
            return new Response('Resource not available', {
              status: 503,
              statusText: 'Service Unavailable',
            });
          });
      })
    );
    return;
  }

  // Стратегия для API: Network First с таймаутами и retry, БЕЗ кэша при ошибках
  if (isAPIRequest(request.url)) {
    // Для PATCH/POST/PUT/DELETE запросов НЕ перехватываем через Service Worker
    // Позволяем браузеру обрабатывать их напрямую для избежания проблем с Request объектом
    if (request.method === 'PATCH' || request.method === 'POST' || request.method === 'PUT' || request.method === 'DELETE') {
      // Пропускаем перехват для модифицирующих запросов - пусть браузер обрабатывает напрямую
      return;
    }
    
    event.respondWith(
      fetchWithRetry(request, MAX_RETRIES, API_TIMEOUT)
        .then((response) => {
          // Кэшируем только успешные GET запросы
          if (response.ok && request.method === 'GET') {
            const responseToCache = response.clone();
            caches.open(API_CACHE_NAME).then((cache) => {
              cache.put(request, responseToCache);
            });
          }
          return response;
        })
        .catch((error) => {
          console.error('[Service Worker] API request failed:', error.message);
          
          // Для GET запросов пробуем кэш как последний вариант
          if (request.method === 'GET' || request.method === 'HEAD') {
            return caches.match(request).then((cachedResponse) => {
              if (cachedResponse) {
                console.log('[Service Worker] Using cached API response');
                return cachedResponse;
              }
              
              // Если кэша нет, возвращаем ошибку
              return new Response(
                JSON.stringify({ 
                  error: 'Network error', 
                  message: 'Проверьте подключение к интернету',
                  cached: false 
                }),
                {
                  status: 503,
                  statusText: 'Service Unavailable',
                  headers: { 'Content-Type': 'application/json' },
                }
              );
            });
          }
          
          // Для других методов (не должно доходить сюда, но на всякий случай)
          throw error;
        })
          
          // Для GET запросов пробуем кэш как последний вариант
          return caches.match(request).then((cachedResponse) => {
            if (cachedResponse) {
              console.log('[Service Worker] Using cached API response');
              return cachedResponse;
            }
            
            // Если кэша нет, возвращаем ошибку
            return new Response(
              JSON.stringify({ 
                error: 'Network error', 
                message: 'Проверьте подключение к интернету',
                cached: false 
              }),
              {
                status: 503,
                statusText: 'Service Unavailable',
                headers: { 'Content-Type': 'application/json' },
              }
            );
          });
        })
    );
    return;
  }

  // Навигационные запросы (страницы): Network First с таймаутом, fallback на кэш
  if (request.mode === 'navigate') {
    event.respondWith(
      fetchWithRetry(request, 2, NAVIGATION_TIMEOUT)
        .then((response) => {
          // Кэшируем успешные ответы навигации
          if (response.ok) {
            const responseToCache = response.clone();
            caches.open(STATIC_CACHE_NAME).then((cache) => {
              cache.put('/', responseToCache);
            });
          }
          return response;
        })
        .catch((error) => {
          console.warn('[Service Worker] Navigation request failed:', error.message);
          
          // Пробуем кэш
          return caches.match('/').then((cachedResponse) => {
            if (cachedResponse) {
              console.log('[Service Worker] Using cached index.html');
              return cachedResponse;
            }
            
            // Если кэша нет, возвращаем базовую страницу
            return new Response(
              '<!DOCTYPE html><html><head><title>Loading...</title></head><body><h1>Загрузка приложения...</h1><p>Проверьте подключение к интернету</p></body></html>',
              {
                status: 503,
                statusText: 'Service Unavailable',
                headers: { 'Content-Type': 'text/html; charset=utf-8' },
              }
            );
          });
        })
    );
    return;
  }

  // Для остальных запросов: Network First с fallback
  event.respondWith(
    fetchWithRetry(request, 2, NETWORK_TIMEOUT)
      .catch(() => {
        return caches.match(request);
      })
  );
});

// Проверка, является ли запрос статическим ресурсом
function isStaticAsset(url) {
  return (
    url.includes('/main.dart.js') ||
    url.includes('/flutter_bootstrap.js') ||
    url.includes('/icons/') ||
    url.includes('/assets/') ||
    url.includes('/manifest.json') ||
    url.endsWith('.png') ||
    url.endsWith('.jpg') ||
    url.endsWith('.jpeg') ||
    url.endsWith('.gif') ||
    url.endsWith('.svg') ||
    url.endsWith('.woff') ||
    url.endsWith('.woff2') ||
    url.endsWith('.ttf')
  );
}

// Проверка, является ли запрос API запросом
function isAPIRequest(url) {
  return (
    url.includes('/api/') ||
    url.includes('/token/') ||
    url.includes('/users/') ||
    url.includes('/orders/') ||
    url.includes('/catalog/') ||
    url.includes('/finance/') ||
    url.includes('/notifications/')
  );
}

// Фоновая синхронизация (для будущего использования)
self.addEventListener('sync', (event) => {
  console.log('[Service Worker] Background sync:', event.tag);
  // Здесь можно добавить логику синхронизации офлайн данных
});

// Push уведомления (для будущего использования)
self.addEventListener('push', (event) => {
  console.log('[Service Worker] Push notification received');
  // Здесь можно добавить обработку push уведомлений
});
