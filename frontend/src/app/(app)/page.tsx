"use client";

import Link from "next/link";
import React, { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card } from "@/shared/components/ui/Card";
import { StatusBadge } from "@/shared/components/ui/StatusBadge";
import { OrdersApi } from "@/shared/api/ordersApi";
import { useAuthStore } from "@/shared/store/authStore";
import type { Order } from "@/shared/types/orders";

function formatDateTime(value?: Date | null): string {
  if (!value) return "—";
  return value.toLocaleString("ru-RU", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/*
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
*/

const ACTIVE_STATUSES = new Set(["CREATED", "APPROVED", "IN_PROGRESS", "DRAFT"]);

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

  /*
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
  } = useMemo(() => { ... }, [orders]);
  */

  const recentActiveOrders = useMemo(() => {
    const list = orders ?? [];
    return list
      .filter((order) => ACTIVE_STATUSES.has(order.status))
      .sort((a, b) => {
        const aTime = a.createdAt?.getTime() ?? 0;
        const bTime = b.createdAt?.getTime() ?? 0;
        return bTime - aTime;
      })
      .slice(0, 3);
  }, [orders]);

  return (
    <section className="space-y-4">
      {/*
      <div className="grid gap-3 md:grid-cols-3">
        <KpiCard label={...} value={kpiNew} icon={...} />
        <KpiCard label="Завершённые" value={kpiCompleted} icon={...} />
        <KpiCard label={...} value={kpiMoney} icon={...} />
      </div>

      <Card className="p-4 text-xs">
        <h2>Заявки по дням (последние 7 дней)</h2>
        ... chart ...
      </Card>
      */}

      {isError ? (
        <Card className="border border-red-200 bg-red-50 p-3 text-xs text-red-700">
          Не удалось загрузить данные по заявкам. Попробуйте обновить страницу
          позже.
        </Card>
      ) : null}

      <Card className="p-4">
        <div className="mb-3 flex items-center justify-between gap-2">
          <h2 className="text-base font-semibold text-slate-900">
            Последние заявки
          </h2>
          <Link
            href="/orders"
            className="text-xs font-medium text-sky-600 hover:text-sky-700"
          >
            Все заявки
          </Link>
        </div>

        {isLoading && recentActiveOrders.length === 0 ? (
          <div className="text-xs text-slate-500">Загружаем заявки...</div>
        ) : null}

        {!isLoading && recentActiveOrders.length === 0 ? (
          <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
            Нет активных заявок (до завершения).
          </div>
        ) : null}

        <div className="space-y-2">
          {recentActiveOrders.map((order) => {
            const href = isOperator
              ? `/orders/${order.id}`
              : `/orders/${order.id}/edit`;
            return (
              <Link
                key={order.id}
                href={href}
                className="flex items-center justify-between gap-3 rounded-xl border border-slate-200 bg-slate-50 px-3 py-3 transition-colors hover:border-sky-200 hover:bg-sky-50"
              >
                <div className="min-w-0 space-y-0.5">
                  <div className="truncate text-sm font-semibold text-slate-900">
                    Заявка {order.number}
                  </div>
                  <div className="truncate text-xs text-slate-500">
                    {order.client?.name || "Без клиента"}
                    {order.address ? ` · ${order.address}` : ""}
                  </div>
                  <div className="text-[11px] text-slate-400">
                    Создана {formatDateTime(order.createdAt)}
                  </div>
                </div>
                <StatusBadge status={order.status} />
              </Link>
            );
          })}
        </div>
      </Card>

      {canManageOrders ? (
        <Link
          href="/orders/create"
          className="flex min-h-[7.5rem] w-full items-center justify-center rounded-2xl bg-gradient-to-br from-sky-500 to-sky-600 px-6 py-8 text-center shadow-md shadow-sky-500/25 transition hover:from-sky-600 hover:to-sky-700 hover:shadow-lg hover:shadow-sky-600/30 active:scale-[0.99]"
        >
          <span className="flex flex-col items-center gap-2">
            <span className="flex h-12 w-12 items-center justify-center rounded-full bg-white/20 text-3xl font-light text-white">
              +
            </span>
            <span className="text-lg font-semibold tracking-wide text-white">
              Создать заявку
            </span>
            <span className="text-xs font-medium text-sky-100">
              Новая заявка на спецтехнику
            </span>
          </span>
        </Link>
      ) : null}

      {/*
      {canManageOrders ? (
        <Card className="p-4 text-sm">
          <h2>Быстрые действия</h2>
          <Link href="/orders/create">Создать заявку</Link>
          <Link href="/reports/summary">Отчёты</Link>
        </Card>
      ) : null}

      {isOperator ? (
        <Card className="p-4 text-sm">
          <h2>Быстрые действия</h2>
          <Link href="/orders">Мои заявки</Link>
          <Link href="/reports">Мои зарплаты</Link>
        </Card>
      ) : null}
      */}
    </section>
  );
}
