"use client";

import React from "react";
import Link from "next/link";
import { RoleGuard } from "@/shared/components/auth/RoleGuard";
import { Card } from "@/shared/components/ui/Card";

export default function ReportsPage() {
  return (
    <RoleGuard allowedRoles={["admin", "manager", "accountant"]}>
      <section className="space-y-4">
        <h1 className="text-2xl font-semibold text-slate-900">Отчёты</h1>
        <p className="text-sm text-slate-600">
          Финансовые отчёты по бизнесу: общая сводка, техника и сотрудники.
        </p>

        <div className="grid gap-3 md:grid-cols-3">
          <Link href="/reports/summary">
            <Card className="flex h-full flex-col justify-between rounded-xl border border-slate-200 bg-white p-4 text-sm hover:shadow-md">
              <div>
                <div className="mb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Общие
                </div>
                <div className="text-base font-semibold text-slate-900">
                  Общий финансовый отчёт
                </div>
                <div className="mt-1 text-[11px] text-slate-500">
                  Выручка, расходы, маржа и количество завершённых заявок за
                  период.
                </div>
              </div>
              <div className="mt-3 text-right text-xs text-slate-400">
                Перейти →
              </div>
            </Card>
          </Link>

          <Link href="/reports/equipment">
            <Card className="flex h-full flex-col justify-between rounded-xl border border-slate-200 bg-white p-4 text-sm hover:shadow-md">
              <div>
                <div className="mb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Техника
                </div>
                <div className="text-base font-semibold text-slate-900">
                  Отчёт по технике
                </div>
                <div className="mt-1 text-[11px] text-slate-500">
                  Загрузка техники, часы, выручка и расходы по топливу и
                  ремонту.
                </div>
              </div>
              <div className="mt-3 text-right text-xs text-slate-400">
                Перейти →
              </div>
            </Card>
          </Link>

          <Link href="/reports/employees">
            <Card className="flex h-full flex-col justify-between rounded-xl border border-slate-200 bg-white p-4 text-sm hover:shadow-md">
              <div>
                <div className="mb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
                  Сотрудники
                </div>
                <div className="text-base font-semibold text-slate-900">
                  Отчёт по сотрудникам
                </div>
                <div className="mt-1 text-[11px] text-slate-500">
                  Выручка, часы работы и количество назначений по операторам.
                </div>
              </div>
              <div className="mt-3 text-right text-xs text-slate-400">
                Перейти →
              </div>
            </Card>
          </Link>
        </div>
      </section>
    </RoleGuard>
  );
}
