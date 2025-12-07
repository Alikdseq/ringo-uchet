/**
 * Sentry конфигурация для клиентской части Next.js
 */

import * as Sentry from "@sentry/nextjs";

const SENTRY_DSN = process.env.NEXT_PUBLIC_SENTRY_DSN;
const SENTRY_ENVIRONMENT = process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT || "production";

if (SENTRY_DSN) {
  Sentry.init({
    dsn: SENTRY_DSN,
    environment: SENTRY_ENVIRONMENT,
    release: process.env.NEXT_PUBLIC_SENTRY_RELEASE,
    
    // Процент трейсов для performance monitoring
    tracesSampleRate: SENTRY_ENVIRONMENT === "production" ? 0.1 : 1.0,
    
    // Процент профилей для profiling
    profilesSampleRate: SENTRY_ENVIRONMENT === "production" ? 0.1 : 1.0,
    
    // Включение автоматического трейсинга
    enableTracing: true,
    
    // Интеграции
    integrations: [
      new Sentry.BrowserTracing({
        // Трейсинг навигации
        tracePropagationTargets: [
          "localhost",
          /^https:\/\/ringo\.example\.com/,
        ],
      }),
      new Sentry.Replay({
        // Session Replay для отладки
        maskAllText: true,
        blockAllMedia: true,
      }),
    ],
    
    // Фильтрация чувствительных данных
    beforeSend(event, hint) {
      // Удаляем пароли и токены из событий
      if (event.request?.data) {
        const data = event.request.data;
        if (typeof data === "object" && data !== null) {
          Object.keys(data).forEach((key) => {
            const lowerKey = key.toLowerCase();
            if (
              lowerKey.includes("password") ||
              lowerKey.includes("token") ||
              lowerKey.includes("secret")
            ) {
              delete data[key];
            }
          });
        }
      }
      return event;
    },
    
    // Игнорирование определенных ошибок
    ignoreErrors: [
      // Игнорируем ошибки от расширений браузера
      /ResizeObserver loop limit exceeded/,
      /Non-Error promise rejection captured/,
      // Игнорируем ошибки от сторонних библиотек
      /Network request failed/,
    ],
  });
}

