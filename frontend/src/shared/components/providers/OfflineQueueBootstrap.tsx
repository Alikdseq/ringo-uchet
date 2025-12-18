"use client";

import React, { useEffect, useRef } from "react";
import { OfflineQueueService } from "@/shared/offline/offlineQueue";
import { useAuthStore } from "@/shared/store/authStore";

interface OfflineQueueBootstrapProps {
  children: React.ReactNode;
}

export function OfflineQueueBootstrap({ children }: OfflineQueueBootstrapProps) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const initializedRef = useRef(false);

  useEffect(() => {
    if (!isAuthenticated) {
      initializedRef.current = false;
      return;
    }

    if (initializedRef.current) {
      return;
    }
    initializedRef.current = true;

    if (typeof window === "undefined") {
      return;
    }

    const sync = () => {
      void OfflineQueueService.retryAll();
    };

    if (window.navigator.onLine) {
      sync();
    }

    window.addEventListener("online", sync);

    return () => {
      window.removeEventListener("online", sync);
    };
  }, [isAuthenticated]);

  return <>{children}</>;
}


