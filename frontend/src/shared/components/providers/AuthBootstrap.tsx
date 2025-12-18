"use client";

import React, { useEffect, useRef } from "react";
import { useAuthStore } from "@/shared/store/authStore";
import { httpClient } from "@/shared/api/httpClient";

interface AuthBootstrapProps {
  children: React.ReactNode;
}

export function AuthBootstrap({ children }: AuthBootstrapProps) {
  const tryAutoLogin = useAuthStore((state) => state.tryAutoLogin);
  const initializedRef = useRef(false);

  // Инициализация сессии (авто-логин по сохранённым токенам)
  useEffect(() => {
    if (initializedRef.current) return;
    initializedRef.current = true;
    void tryAutoLogin();
  }, [tryAutoLogin]);

  // Проброс access-токена в httpClient (Authorization: Bearer ...)
  useEffect(() => {
    const applyToken = (token: string | null) => {
      if (token) {
        httpClient.defaults.headers.Authorization = `Bearer ${token}`;
      } else {
        delete httpClient.defaults.headers.Authorization;
      }
    };

    // Инициализируем заголовок при монтировании
    applyToken(useAuthStore.getState().accessToken);

    // И подписываемся на дальнейшие изменения токена
    const unsubscribe = useAuthStore.subscribe((state) => {
      applyToken(state.accessToken);
    });

    return unsubscribe;
  }, []);

  return <>{children}</>;
}


