"use client";

import Link from "next/link";
import React, { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card } from "@/shared/components/ui/Card";
import { OrdersApi } from "@/shared/api/ordersApi";
import { ProfileApi } from "@/shared/api/profileApi";
import { useAuthStore } from "@/shared/store/authStore";
import type { Order } from "@/shared/types/orders";
import type { OperatorSalaryResponse } from "@/shared/types/salary";

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    maximumFractionDigits: 0,
  }).format(value);
}

function KpiCard({
  label,
  value,
  icon,
}: {
  label: string;
  value: string;
  icon: React.ReactNode;
}) {
  return (
    <Card className="flex flex-1 items-center justify-between px-4 py-3 text-sm">
      <div className="flex items-center gap-3">
        <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-sky-50 text-sky-500">
          {icon}
        </div>
        <div className="text-xs text-slate-600">{label}</div>
      </div>
      <div className="text-xl font-semibold text-slate-900">{value}</div>
    </Card>
  );
}

export default function DashboardPage() {
  const user = useAuthStore((state) => state.user);
  const role = user?.role;
  const isOperator = role === "operator";
  const canManageOrders = role === "admin" || role === "manager";

  const { data: orders, isLoading, isError } = useQuery<Order[]>({
    queryKey: ["dashboard", "orders"],
    queryFn: () =>
      OrdersApi.list({
        page: 1,
        pageSize: 200,
      }),
    staleTime: 60_000,
    refetchOnWindowFocus: false,
  });

  const {
    data: salaryData,
    isLoading: isSalaryLoading,
  } = useQuery<OperatorSalaryResponse>({
    queryKey: ["dashboard", "operator-salary"],
    queryFn: () => ProfileApi.getOperatorSalary(),
    enabled: isOperator,
    staleTime: 60_000,
    refetchOnWindowFocus: false,
  });

  const {
    newCount,
    completedCount,
    revenue,
    dailyCounts,
  }: {
    newCount: number;
    completedCount: number;
    revenue: number;
    dailyCounts: { date: string; label: string; total: number }[];
  } = useMemo(() => {
    const list = orders ?? [];
    let created = 0;
    let completed = 0;
    let totalRevenue = 0;

    const byDate = new Map<string, number>();

    for (const order of list) {
      if (order.status === "CREATED" || order.status === "APPROVED") {
        created += 1;
      }
      if (order.status === "COMPLETED") {
        completed += 1;
        totalRevenue += order.totalAmount ?? 0;
      }

      const createdAt = order.createdAt;
      if (createdAt) {
        const iso = createdAt.toISOString().slice(0, 10);
        byDate.set(iso, (byDate.get(iso) ?? 0) + 1);
      }
    }

    const sortedDates = Array.from(byDate.keys()).sort();
    const lastDates = sortedDates.slice(-7);
    const dailyCounts = lastDates.map((iso) => {
      const [, month, day] = iso.split("-");
      return {
        date: iso,
        label: `${day}.${month}`,
        total: byDate.get(iso) ?? 0,
      };
    });

    return {
      newCount: created,
      completedCount: completed,
      revenue: totalRevenue,
      dailyCounts,
    };
  }, [orders]);

  const operatorSalaryTotal =
    salaryData?.totalSalary ??
    salaryData?.orders?.reduce((sum, o) => sum + (o.salaryAmount || 0), 0) ??
    0;

  const kpiNew = isLoading ? "…" : String(newCount);
  const kpiCompleted = isLoading ? "…" : String(completedCount);
  const kpiMoney = isOperator
    ? isSalaryLoading
      ? "…"
      : formatCurrency(operatorSalaryTotal)
    : isLoading
      ? "…"
      : formatCurrency(revenue);

  const maxDaily = dailyCounts.reduce(
    (max, item) => (item.total > max ? item.total : max),
    0,
  );
  const safeMax = maxDaily || 1;

  return (
    <section className="space-y-4">
      <div className="grid gap-3 md:grid-cols-3">
        <KpiCard
          label={isOperator ? "Мои активные" : "Новые заявки"}
          value={kpiNew}
          icon={<span className="text-lg">＋</span>}
        />
        <KpiCard
          label="Завершённые"
          value={kpiCompleted}
          icon={<span className="text-lg">✅</span>}
        />
        <KpiCard
          label={isOperator ? "Моя зарплата" : "Доход (по завершённым)"}
          value={kpiMoney}
          icon={<span className="text-lg">💰</span>}
        />
      </div>

      <Card className="p-4 text-xs">
        <h2 className="mb-3 text-sm font-semibold text-slate-900">
          Заявки по дням (последние 7 дней)
        </h2>
        {dailyCounts.length === 0 ? (
          <div className="text-[11px] text-slate-500">
            Пока нет заявок для отображения.
          </div>
        ) : (
          <div className="flex items-end gap-3 pt-1">
            {dailyCounts.map((item) => (
              <div
                key={item.date}
                className="flex flex-1 flex-col items-center justify-end gap-1"
              >
                <div className="flex h-24 w-full items-end justify-center rounded-md bg-slate-50">
                  <div
                    className="w-4 rounded-t-md bg-sky-500"
                    style={{
                      height: `${(item.total / safeMax) * 100}%`,
                    }}
                  />
                </div>
                <div className="text-[11px] font-semibold text-slate-900">
                  {item.total}
                </div>
                <div className="text-[11px] text-slate-500">{item.label}</div>
              </div>
            ))}
          </div>
        )}
      </Card>

      {isError ? (
        <Card className="border border-red-200 bg-red-50 p-3 text-xs text-red-700">
          Не удалось загрузить данные по заявкам для дашборда. Попробуйте обновить
          страницу позже.
        </Card>
      ) : null}

      {canManageOrders ? (
        <Card className="p-4 text-sm">
          <h2 className="mb-3 text-base font-semibold text-slate-900">
            Быстрые действия
          </h2>
          <div className="space-y-2 text-sm">
            <Link
              href="/orders/create"
              className="flex items-center gap-2 text-sky-600 hover:text-sky-700"
            >
              <span className="text-lg">＋</span>
              <span>Создать заявку</span>
            </Link>
            <Link
              href="/reports/summary"
              className="flex items-center gap-2 text-slate-700 hover:text-slate-900"
            >
              <span className="text-lg">ⓘ</span>
              <span>Отчёты</span>
            </Link>
          </div>
        </Card>
      ) : null}

      {isOperator ? (
        <Card className="p-4 text-sm">
          <h2 className="mb-3 text-base font-semibold text-slate-900">
            Быстрые действия
          </h2>
          <div className="space-y-2 text-sm">
            <Link
              href="/orders"
              className="flex items-center gap-2 text-sky-600 hover:text-sky-700"
            >
              <span className="text-lg">📋</span>
              <span>Мои заявки</span>
            </Link>
            <Link
              href="/reports"
              className="flex items-center gap-2 text-slate-700 hover:text-slate-900"
            >
              <span className="text-lg">💰</span>
              <span>Мои зарплаты</span>
            </Link>
          </div>
        </Card>
      ) : null}
    </section>
  );
}
