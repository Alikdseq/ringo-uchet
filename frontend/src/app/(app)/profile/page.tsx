"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Card } from "@/shared/components/ui/Card";
import { useAuthStore } from "@/shared/store/authStore";
import type { UserInfo } from "@/shared/types/auth";

function getInitials(user: UserInfo | null): string {
  if (!user) return "?";
  const full =
    user.fullNameFromApi ??
    `${user.firstName ?? ""} ${user.lastName ?? ""}`.trim();
  const source = full || user.username || user.phone || user.email;
  if (!source) return "?";
  const parts = source.split(" ").filter(Boolean);
  if (parts.length === 1) {
    return parts[0].slice(0, 2).toUpperCase();
  }
  return `${parts[0][0] ?? ""}${parts[1][0] ?? ""}`.toUpperCase();
}

function getDisplayName(user: UserInfo | null): string {
  if (!user) return "Пользователь";
  const full =
    user.fullNameFromApi ??
    `${user.firstName ?? ""} ${user.lastName ?? ""}`.trim();
  return (
    full ||
    user.username ||
    user.phone ||
    user.email ||
    `Пользователь #${user.id}`
  );
}

export default function ProfilePage() {
  const router = useRouter();
  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);

  const [isLoggingOut, setIsLoggingOut] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogout = async () => {
    setIsLoggingOut(true);
    setError(null);
    try {
      await logout();
      router.replace("/login");
    } catch (e) {
      const message =
        e instanceof Error ? e.message : "Не удалось выполнить выход";
      setError(message);
      setIsLoggingOut(false);
    }
  };

  const initials = getInitials(user ?? null);
  const name = getDisplayName(user ?? null);
  const role = user?.roleDisplay ?? user?.role ?? "user";

  return (
    <section className="space-y-4">
      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {error}
        </div>
      ) : null}

      <Card className="p-4">
        <div className="flex items-center gap-4">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-slate-900 text-lg font-semibold uppercase text-white md:h-20 md:w-20 md:text-2xl">
            {initials}
          </div>
          <div className="space-y-1 text-sm">
            <div className="text-base font-semibold text-slate-900 md:text-lg">
              {name}
            </div>
            <div className="text-xs uppercase tracking-wide text-slate-500">
              {role}
            </div>
            <div className="mt-1 flex flex-wrap gap-3 text-xs text-slate-600">
              {user?.email ? <span>{user.email}</span> : null}
              {user?.phone ? <span>{user.phone}</span> : null}
            </div>
          </div>
        </div>
      </Card>

      <Card className="p-4 text-sm">
        <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
          Настройки
        </h2>
        <div className="divide-y divide-slate-200">
          <ProfileLink href="/profile/notifications" title="Уведомления">
            Управление типами уведомлений (создание заявок, статус, оплаты и др.).
          </ProfileLink>
          <ProfileLink href="/profile/password" title="Смена пароля">
            Обновление пароля для входа в систему.
          </ProfileLink>
          <ProfileLink href="/offline-queue" title="Оффлайн очередь">
            Несинхронизированные действия и очередь отправки.
          </ProfileLink>
          <ProfileLink
            title="Выйти"
            onClick={handleLogout}
            danger
            disabled={isLoggingOut}
          >
            Завершить сессию и выйти из учётной записи.
          </ProfileLink>
        </div>
      </Card>
    </section>
  );
}

interface ProfileLinkProps {
  href?: string;
  title: string;
  children: React.ReactNode;
  onClick?: () => void;
  danger?: boolean;
  disabled?: boolean;
}

function ProfileLink({
  href,
  title,
  children,
  onClick,
  danger,
  disabled,
}: ProfileLinkProps) {
  const className =
    "flex w-full items-center justify-between gap-3 py-2.5 text-sm hover:bg-slate-50";

  const content = (
    <div className="flex w-full items-center justify-between gap-3">
      <div>
        <div
          className={`font-medium ${
            danger ? "text-red-600" : "text-slate-900"
          }`}
        >
          {title}
        </div>
        <div
          className={`text-xs ${danger ? "text-red-500" : "text-slate-500"}`}
        >
          {children}
        </div>
      </div>
      <span className={`text-xs ${danger ? "text-red-400" : "text-slate-400"}`}>
        ›
      </span>
    </div>
  );

  if (href) {
    return (
      <Link href={href} className={className}>
        {content}
      </Link>
    );
  }

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={`${className} text-left disabled:cursor-not-allowed disabled:opacity-60`}
    >
      {content}
    </button>
  );
}

