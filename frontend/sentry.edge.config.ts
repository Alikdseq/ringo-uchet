/**
 * Sentry конфигурация для Edge Runtime Next.js
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
  });
}

