"use client";

import React, { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/shared/store/authStore";

export type UserRole =
  | "admin"
  | "manager"
  | "operator"
  | "accountant"
  | "viewer";

interface RoleGuardProps {
  allowedRoles: UserRole[];
  children: React.ReactNode;
  fallback?: React.ReactNode;
  /** Если роль не подходит — редирект вместо сообщения */
  redirectTo?: string;
}

export function RoleGuard({
  allowedRoles,
  children,
  fallback,
  redirectTo,
}: RoleGuardProps) {
  const router = useRouter();
  const user = useAuthStore((state) => state.user);
  const isLoading = useAuthStore((state) => state.isLoading);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  const role = user?.role as UserRole | undefined;
  const denied =
    isAuthenticated && Boolean(user) && role != null && !allowedRoles.includes(role);

  useEffect(() => {
    if (denied && redirectTo) {
      router.replace(redirectTo);
    }
  }, [denied, redirectTo, router]);

  if (isLoading) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center">
        <div className="rounded-md border border-slate-200 bg-white px-4 py-3 text-xs text-slate-600 shadow-sm">
          Проверяем права доступа...
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return null;
  }

  if (!user) {
    if (fallback) {
      return <>{fallback}</>;
    }
    return null;
  }

  if (!allowedRoles.includes(user.role as UserRole)) {
    if (redirectTo) {
      return (
        <div className="flex min-h-[40vh] items-center justify-center">
          <div className="rounded-md border border-slate-200 bg-white px-4 py-3 text-xs text-slate-600 shadow-sm">
            Перенаправление...
          </div>
        </div>
      );
    }

    if (fallback) {
      return <>{fallback}</>;
    }

    return (
      <div className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
        У вас нет доступа к этому разделу.
      </div>
    );
  }

  return <>{children}</>;
}
