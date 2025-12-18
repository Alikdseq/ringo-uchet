"use client";

import React from "react";
import { usePathname } from "next/navigation";
import { TopBar } from "./TopBar";
import { BottomNav } from "./BottomNav";

const APP_SHELL_MAX_WIDTH = "max-w-7xl";

function getPageTitle(pathname: string): string {
  if (pathname.startsWith("/orders")) return "Заявки";
  if (pathname.startsWith("/catalog")) return "Номенклатура";
  if (pathname.startsWith("/reports")) return "Отчёты";
  if (pathname.startsWith("/profile")) return "Профиль";
  if (pathname.startsWith("/offline-queue")) return "Оффлайн очередь";
  return "Главная";
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const title = getPageTitle(pathname);

  return (
    <div className="min-h-screen bg-[var(--color-background)] text-[color:var(--color-foreground)]">
      {/* Основной контент во всю ширину, навигация снизу */}
      <div
        className={`${APP_SHELL_MAX_WIDTH} mx-auto flex min-h-screen flex-col`}
      >
        <TopBar className="w-full" title={title} />
        <main className="flex-1 px-4 pb-24 pt-4 md:px-6 md:pt-6">
          {children}
        </main>
      </div>

      {/* Нижняя навигация для всех экранов */}
      <BottomNav pathname={pathname} />
    </div>
  );
}

