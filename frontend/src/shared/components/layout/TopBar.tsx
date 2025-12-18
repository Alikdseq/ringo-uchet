"use client";

import React from "react";
import { usePathname, useRouter } from "next/navigation";
import { OfflineQueueIndicator } from "./OfflineQueueIndicator";

interface TopBarProps {
  className?: string;
  title: string;
}

export function TopBar({ className, title }: TopBarProps) {
  const router = useRouter();
  const pathname = usePathname();

  const handleRefresh = () => {
    router.refresh();
  };

  const handleBack = () => {
    if (typeof window !== "undefined" && window.history.length > 1) {
      router.back();
    } else {
      router.push("/");
    }
  };

  const canGoBack = pathname !== "/" && pathname !== "/login";

  return (
    <header
      className={`backdrop-blur-md bg-white/80 border-b border-slate-200 text-slate-900 ${className ?? ""}`}
    >
      <div className="flex h-14 items-center justify-between px-4 md:px-6">
        <div className="flex h-9 w-9 items-center justify-center">
          {canGoBack ? (
            <button
              type="button"
              aria-label="Назад"
              onClick={handleBack}
              className="flex h-9 w-9 items-center justify-center rounded-full border border-slate-200 bg-white/70 text-slate-700 shadow-xs transition-colors hover:bg-slate-100 active:bg-slate-200"
            >
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
                className="h-4 w-4"
              >
                <path
                  d="M15 5l-7 7 7 7"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth={1.8}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </button>
          ) : null}
        </div>
        <div className="flex items-center gap-2 md:gap-3">
          <div className="text-sm font-semibold tracking-tight text-slate-900 md:text-base">
            {title}
          </div>
          <OfflineQueueIndicator />
        </div>
        <button
          type="button"
          aria-label="Обновить"
          onClick={handleRefresh}
          className="flex h-9 w-9 items-center justify-center rounded-full border border-slate-200 bg-white/70 text-slate-700 shadow-xs transition-colors hover:bg-slate-100 active:bg-slate-200"
        >
          <span className="text-base leading-none">↻</span>
        </button>
      </div>
    </header>
  );
}

