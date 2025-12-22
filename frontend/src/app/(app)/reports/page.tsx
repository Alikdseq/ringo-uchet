"use client";

import React from "react";
import Link from "next/link";
import { RoleGuard } from "@/shared/components/auth/RoleGuard";
import { Card } from "@/shared/components/ui/Card";
import { useAuthStore } from "@/shared/store/authStore";
import { useQuery } from "@tanstack/react-query";
import { ProfileApi } from "@/shared/api/profileApi";
import type { OperatorSalaryOrder, OperatorSalaryResponse } from "@/shared/types/salary";

const QUERY_KEY = ["profile", "operator-salary"] as const;

function formatCurrency(value: number): string {
  try {
    return new Intl.NumberFormat("ru-RU", {
      style: "currency",
      currency: "RUB",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(value);
  } catch {
    return `${value.toFixed(2)} ₽`;
  }
}

function formatDate(value: Date | null): string {
  if (!value) return "";
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, "0");
  const day = String(value.getDate()).padStart(2, "0");
  return `${day}.${month}.${year}`;
}

function OperatorSalarySection() {
  const {
    data,
    isLoading,
    isError,
    error,
  } = useQuery<OperatorSalaryResponse>({
    queryKey: QUERY_KEY,
    queryFn: () => ProfileApi.getOperatorSalary(),
    staleTime: 2 * 60_000,
    refetchOnWindowFocus: false,
  });

  const orders: OperatorSalaryOrder[] = data?.orders ?? [];
  const totalSalary = orders.reduce(
    (sum, order) => sum + (order.salaryAmount || 0),
    0,
  );

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      error instanceof Error
        ? error.message
        : "Не удалось загрузить данные о зарплате";
  }

  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-semibold text-slate-900">Мои зарплаты</h1>
      <p className="text-sm text-slate-600">
        Отчёт по начислениям за выполненные заказы.
      </p>

      <Card className="border-emerald-200 bg-emerald-50 p-4 text-sm">
        <div className="flex items-center justify-between gap-4">
          <div>
            <div className="text-xs font-medium uppercase tracking-wide text-emerald-700">
              Итого заработано
            </div>
            <div className="text-[11px] text-emerald-800">
              По всем заявкам
            </div>
          </div>
          <div className="text-lg font-semibold text-emerald-800 md:text-xl">
            {formatCurrency(totalSalary)}
          </div>
        </div>
      </Card>

      {errorMessage ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {errorMessage}
        </div>
      ) : null}

      <Card className="p-0 text-sm">
        {isLoading ? (
          <div className="flex items-center justify-center px-4 py-10 text-xs text-slate-500">
            Загружаем данные о зарплате...
          </div>
        ) : orders.length === 0 ? (
          <div className="flex items-center justify-center px-4 py-10 text-xs text-slate-500">
            Нет данных о зарплатах.
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {orders.map((order) => (
              <div
                key={order.id}
                className="flex items-start justify-between gap-3 px-4 py-3"
              >
                <div className="space-y-1">
                  <div className="text-sm font-medium text-slate-900">
                    Заказ {order.number}
                  </div>
                  <div className="text-[11px] text-slate-500">
                    Дата: {formatDate(order.createdAt)}
                  </div>
                  {order.clientName ? (
                    <div className="text-[11px] text-slate-500">
                      Клиент: {order.clientName}
                    </div>
                  ) : null}
                  {order.address ? (
                    <div className="text-[11px] text-slate-500">
                      Адрес: {order.address}
                    </div>
                  ) : null}
                </div>
                <div className="flex flex-col items-end gap-1">
                  <div className="text-sm font-semibold text-orange-700">
                    {formatCurrency(order.salaryAmount)}
                  </div>
                  <div className="text-[11px] text-slate-500">Зарплата</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>
    </section>
  );
}

export default function ReportsPage() {
  const user = useAuthStore((state) => state.user);
  const role = user?.role;

  // Для операторов показываем зарплаты вместо отчетов
  if (role === "operator") {
    return <OperatorSalarySection />;
  }

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
