"use client";

import { useQuery } from "@tanstack/react-query";
import React, { useMemo, useState } from "react";
import { RoleGuard } from "@/shared/components/auth/RoleGuard";
import { Card } from "@/shared/components/ui/Card";
import { PageHeader } from "@/shared/components/ui/PageHeader";
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

export default function OperatorSalaryPage() {
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const {
    data,
    isLoading,
    isError,
    error,
    refetch,
    isFetching,
  } = useQuery<OperatorSalaryResponse>({
    queryKey: QUERY_KEY,
    queryFn: () => ProfileApi.getOperatorSalary(),
     staleTime: 2 * 60_000,
     refetchOnWindowFocus: false,
  });

  const filteredOrders = useMemo(() => {
    const orders: OperatorSalaryOrder[] = data?.orders ?? [];

    if (!from && !to) {
      return orders;
    }

    const fromDate = from ? new Date(from) : null;
    const toDate = to ? new Date(to) : null;

    return orders.filter((order) => {
      const dt = order.createdAt;
      if (Number.isNaN(dt.getTime())) return false;

      if (fromDate) {
        const startOfFrom = new Date(
          fromDate.getFullYear(),
          fromDate.getMonth(),
          fromDate.getDate(),
          0,
          0,
          0,
          0,
        );
        if (dt < startOfFrom) return false;
      }

      if (toDate) {
        const endOfTo = new Date(
          toDate.getFullYear(),
          toDate.getMonth(),
          toDate.getDate(),
          23,
          59,
          59,
          999,
        );
        if (dt > endOfTo) return false;
      }

      return true;
    });
  }, [data, from, to]);

  const totalSalary = useMemo(
    () =>
      filteredOrders.reduce(
        (sum, order) => sum + (order.salaryAmount || 0),
        0,
      ),
    [filteredOrders],
  );

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      error instanceof Error
        ? error.message
        : "Не удалось загрузить данные о зарплате";
  }

  const handleClearPeriod = () => {
    setFrom("");
    setTo("");
  };

  const handleRefresh = async () => {
    await refetch();
  };

  return (
    <RoleGuard allowedRoles={["operator"]}>
      <section className="space-y-4">
        <PageHeader
          title="Мои зарплаты"
          subtitle="Отчёт по начислениям за выполненные заказы."
        />

        <Card className="p-4 text-sm">
          <div className="flex flex-col gap-3 md:flex-row md:items-end">
            <div className="flex-1 space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                Период с
              </label>
              <input
                type="date"
                value={from}
                onChange={(event) => setFrom(event.target.value)}
                className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              />
            </div>
            <div className="flex-1 space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                Период по
              </label>
              <input
                type="date"
                value={to}
                onChange={(event) => setTo(event.target.value)}
                className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              />
            </div>
            <div className="flex items-center gap-2 md:self-stretch">
              <button
                type="button"
                onClick={handleClearPeriod}
                className="inline-flex items-center justify-center rounded-md border border-slate-300 bg-white px-3 py-2 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50"
              >
                Сбросить
              </button>
              <button
                type="button"
                onClick={handleRefresh}
                disabled={isFetching}
                className="inline-flex items-center justify-center rounded-md border border-slate-300 bg-white px-3 py-2 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {isFetching ? "Обновляем..." : "Обновить"}
              </button>
            </div>
          </div>
        </Card>

        <Card className="border-emerald-200 bg-emerald-50 p-4 text-sm">
          <div className="flex items-center justify-between gap-4">
            <div>
              <div className="text-xs font-medium uppercase tracking-wide text-emerald-700">
                Итого заработано
              </div>
              <div className="text-[11px] text-emerald-800">
                По выбранному периоду
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
          ) : filteredOrders.length === 0 ? (
            <div className="flex items-center justify-center px-4 py-10 text-xs text-slate-500">
              Нет данных за выбранный период.
            </div>
          ) : (
            <div className="divide-y divide-slate-100">
              {filteredOrders.map((order) => (
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
    </RoleGuard>
  );
}


