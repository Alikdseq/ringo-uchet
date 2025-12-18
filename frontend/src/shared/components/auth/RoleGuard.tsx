"use client";

import React from "react";
import { useAuthStore } from "@/shared/store/authStore";

export type UserRole = "admin" | "manager" | "operator" | "accountant" | "viewer";

interface RoleGuardProps {
  allowedRoles: UserRole[];
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export function RoleGuard({ allowedRoles, children, fallback }: RoleGuardProps) {
  const user = useAuthStore((state) => state.user);
  const isLoading = useAuthStore((state) => state.isLoading);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  // Пока ещё идёт авто-логин / проверка токена — показываем небольшой лоадер,
  // но не рендерим сообщение "нет доступа".
  if (isLoading) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center">
        <div className="rounded-md border border-slate-200 bg-white px-4 py-3 text-xs text-slate-600 shadow-sm">
          Проверяем права доступа...
        </div>
      </div>
    );
  }

  // Если пользователь ещё не аутентифицирован, отдаём управление AuthGuard,
  // здесь ничего не показываем.
  if (!isAuthenticated) {
    return null;
  }

  // Защита от странных состояний: аутентифицирован, но user не подгружен.
  // В этом случае тоже не показываем "нет доступа", чтобы не вводить в заблуждение.
  if (!user) {
    if (fallback) {
      return <>{fallback}</>;
    }
    return null;
  }

  const role = user.role as UserRole;

  if (!allowedRoles.includes(role)) {
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


