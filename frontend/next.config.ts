import type { NextConfig } from "next";

// В Docker: http://django-api:8000; локально без Docker: http://127.0.0.1:8001
const apiProxyTarget =
  process.env.API_INTERNAL_URL || "http://127.0.0.1:8001";

const nextConfig: NextConfig = {
  // Оптимизация для production
  compress: true,
  
  // Переменные окружения для API
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || "/api/v1",
  },

  // Чтобы /api/* работал и при открытии frontend на :3000 (без nginx)
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${apiProxyTarget}/api/:path*`,
      },
    ];
  },
  
  // Headers для безопасности
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-XSS-Protection",
            value: "1; mode=block",
          },
        ],
      },
    ];
  },
};

export default nextConfig;
