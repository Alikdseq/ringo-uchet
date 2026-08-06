"use client";

import React, { useMemo } from "react";
import Link from "next/link";
import { useAuthStore } from "@/shared/store/authStore";

interface SideNavProps {
  pathname: string;
  className?: string;
}

const ALL_NAV_ITEMS = [
  { href: "/", label: "Dashboard" },
  { href: "/orders", label: "Заявки" },
  { href: "/catalog", label: "Номенклатура", hideForRoles: ["operator"] as const },
  { href: "/reports", label: "Отчёты" },
  { href: "/profile", label: "Профиль" },
  { href: "/offline-queue", label: "Оффлайн" },
];

export function SideNav({ pathname, className }: SideNavProps) {
  const role = useAuthStore((state) => state.user?.role);

  const navItems = useMemo(
    () =>
      ALL_NAV_ITEMS.filter((item) => {
        if (!("hideForRoles" in item) || !item.hideForRoles) return true;
        if (!role) return true;
        return !(item.hideForRoles as readonly string[]).includes(role);
      }),
    [role],
  );

  return (
    <aside
      className={`h-screen w-56 border-r border-slate-200 bg-white/90 px-3 py-4 ${className}`}
    >
      <nav className="flex flex-col gap-1">
        {navItems.map((item) => {
          const active =
            item.href === "/"
              ? pathname === "/"
              : pathname === item.href || pathname.startsWith(item.href + "/");

          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                active
                  ? "bg-slate-900 text-white"
                  : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
              }`}
            >
              {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}


