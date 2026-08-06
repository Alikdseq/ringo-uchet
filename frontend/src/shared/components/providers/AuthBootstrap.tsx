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

  // Ждём rehydrate localStorage, затем восстанавливаем сессию
  useEffect(() => {
    if (initializedRef.current) return;
    initializedRef.current = true;

    const run = () => {
      void tryAutoLogin();
    };

    const persistApi = useAuthStore.persist;
    if (persistApi.hasHydrated()) {
      run();
      return;
    }

    const unsub = persistApi.onFinishHydration(() => {
      run();
    });
    return unsub;
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

    applyToken(useAuthStore.getState().accessToken);

    const unsubscribe = useAuthStore.subscribe((state) => {
      applyToken(state.accessToken);
    });

    return unsubscribe;
  }, []);

  return <>{children}</>;
}
