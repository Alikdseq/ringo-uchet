"use client";

import React, { useEffect, useRef } from "react";
import { registerWebPush } from "@/shared/services/webPush";
import { useAuthStore } from "@/shared/store/authStore";

interface WebPushBootstrapProps {
  children: React.ReactNode;
}

export function WebPushBootstrap({ children }: WebPushBootstrapProps) {
  const userId = useAuthStore((state) => state.user?.id);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const initializedForUserRef = useRef<number | null>(null);

  useEffect(() => {
    if (!isAuthenticated || !userId) {
      return;
    }

    if (initializedForUserRef.current === userId) {
      return;
    }

    initializedForUserRef.current = userId;
    void registerWebPush();
  }, [isAuthenticated, userId]);

  return <>{children}</>;
}


