import React from "react";
import Link from "next/link";

interface BottomNavProps {
  pathname: string;
}

const navItems = [
  { href: "/", label: "Главная" },
  { href: "/orders", label: "Заявки" },
  { href: "/catalog", label: "Каталог" },
  { href: "/reports", label: "Отчёты" },
  { href: "/profile", label: "Профиль" },
];

function NavIcon({
  href,
  active,
}: {
  href: string;
  active: boolean;
}) {
  const strokeWidth = active ? 1.9 : 1.6;

  if (href === "/") {
    // Домашняя страница / дашборд
    return (
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="h-5 w-5"
      >
        <path
          d="M4 11L12 5l8 6"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          d="M6 10v8.5A1.5 1.5 0 0 0 7.5 20h3a1.5 1.5 0 0 0 1.5-1.5V15h2v3.5A1.5 1.5 0 0 0 15.5 20h3a1.5 1.5 0 0 0 1.5-1.5V10"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    );
  }

  if (href === "/orders") {
    // Заявки / задачи
    return (
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="h-5 w-5"
      >
        <rect
          x="6"
          y="4"
          width="12"
          height="16"
          rx="2"
          ry="2"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
        />
        <path
          d="M9 9.5h6"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
        />
        <path
          d="M9 13.5l2 2 4-4"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    );
  }

  if (href === "/catalog") {
    // Каталог / номенклатура (сетка)
    return (
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="h-5 w-5"
      >
        <rect
          x="4"
          y="4"
          width="7"
          height="7"
          rx="1.5"
          ry="1.5"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
        />
        <rect
          x="13"
          y="4"
          width="7"
          height="7"
          rx="1.5"
          ry="1.5"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
        />
        <rect
          x="4"
          y="13"
          width="7"
          height="7"
          rx="1.5"
          ry="1.5"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
        />
        <rect
          x="13"
          y="13"
          width="7"
          height="7"
          rx="1.5"
          ry="1.5"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
        />
      </svg>
    );
  }

  if (href === "/reports") {
    // Отчёты / аналитика
    return (
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="h-5 w-5"
      >
        <path
          d="M4.5 19V11"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
        />
        <path
          d="M9.5 19V5"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
        />
        <path
          d="M14.5 19v-7"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
        />
        <path
          d="M19.5 19v-4"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
        />
      </svg>
    );
  }

  if (href === "/profile") {
    // Профиль пользователя
    return (
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className="h-5 w-5"
      >
        <circle
          cx="12"
          cy="9"
          r="3.5"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
        />
        <path
          d="M6 19c0-3 2.7-5 6-5s6 2 6 5"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeLinecap="round"
        />
      </svg>
    );
  }

  // Fallback
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      className="h-5 w-5"
    >
      <circle
        cx="12"
        cy="12"
        r="5"
        fill="none"
        stroke="currentColor"
        strokeWidth={strokeWidth}
      />
    </svg>
  );
}

export function BottomNav({ pathname }: BottomNavProps) {
  return (
    <nav className="fixed inset-x-0 bottom-0 z-20 border-t border-slate-200 bg-white/95 backdrop-blur">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-2 py-2">
        {navItems.map((item) => {
          const active =
            item.href === "/"
              ? pathname === "/"
              : pathname === item.href || pathname.startsWith(item.href + "/");

          return (
            <Link
              key={item.href}
              href={item.href}
              aria-current={active ? "page" : undefined}
                className={`flex flex-1 flex-col items-center gap-1 rounded-xl px-2 py-1.5 text-[11px] font-medium transition-colors ${
                active
                    ? "text-slate-900"
                    : "text-slate-400 hover:text-slate-700"
              }`}
            >
              <NavIcon href={item.href} active={active} />
              <span>{item.label}</span>
                <span
                  className={`mt-0.5 h-1 w-8 rounded-full transition-all ${
                    active ? "bg-slate-900 opacity-100" : "bg-slate-300 opacity-0"
                  }`}
                />
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

