"use client";

import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { PageHeader } from "@/shared/components/ui/PageHeader";

const TABS = [
  { href: "/catalog/equipment", label: "Техника" },
  { href: "/catalog/services", label: "Услуги" },
  { href: "/catalog/materials", label: "Материалы" },
  { href: "/catalog/clients", label: "Клиенты" },
];

export default function CatalogLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();

  return (
    <section className="catalog-scope space-y-4">
      <PageHeader
        title="Каталог"
        subtitle="Техника, услуги, материалы и клиенты."
      />
      <div className="flex flex-wrap gap-2 border-b border-slate-200 pb-2">
        {TABS.map((tab) => {
          const active =
            pathname === tab.href || pathname.startsWith(`${tab.href}/`);
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`rounded-full px-3 py-1 text-xs font-medium transition ${
                active
                  ? "bg-slate-900 text-white"
                  : "bg-slate-100 text-slate-700 hover:bg-slate-200"
              }`}
            >
              {tab.label}
            </Link>
          );
        })}
      </div>
      {children}
    </section>
  );
}


