/**
 * Sentry конфигурация для серверной части Next.js
 */

import * as Sentry from "@sentry/nextjs";

const SENTRY_DSN = process.env.SENTRY_DSN;
const SENTRY_ENVIRONMENT = process.env.SENTRY_ENVIRONMENT || "production";

if (SENTRY_DSN) {
  Sentry.init({
    dsn: SENTRY_DSN,
    environment: SENTRY_ENVIRONMENT,
    release: process.env.SENTRY_RELEASE,
    
    // Процент трейсов для performance monitoring
    tracesSampleRate: SENTRY_ENVIRONMENT === "production" ? 0.1 : 1.0,
    
    // Процент профилей для profiling
    profilesSampleRate: SENTRY_ENVIRONMENT === "production" ? 0.1 : 1.0,
    
    // Включение автоматического трейсинга
    enableTracing: true,
    
    // Интеграции
    integrations: [
      new Sentry.Integrations.Http({ tracing: true }),
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
      /ENOTFOUND/,
      /ECONNREFUSED/,
      /ETIMEDOUT/,
    ],
  });
}

