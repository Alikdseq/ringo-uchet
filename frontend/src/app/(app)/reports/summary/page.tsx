"use client";

import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { RoleGuard } from "@/shared/components/auth/RoleGuard";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import { Card } from "@/shared/components/ui/Card";
import { ReportsApi } from "@/shared/api/reportsApi";
import type { SummaryReport } from "@/shared/types/reports";

const QUERY_KEY = ["reports", "summary"] as const;

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    maximumFractionDigits: 0,
  }).format(value);
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat("ru-RU", {
    maximumFractionDigits: 0,
  }).format(value);
}

interface PeriodState {
  from: string;
  to: string;
}

export default function SummaryReportPage() {
  const [period, setPeriod] = useState<PeriodState>({ from: "", to: "" });

  const { data, isLoading, isError, error, refetch, isFetching } = useQuery<SummaryReport>({
    queryKey: [...QUERY_KEY, period] as const,
    queryFn: () =>
      ReportsApi.getSummary({
        from: period.from || undefined,
        to: period.to || undefined,
      }),
    staleTime: 2 * 60_000,
    refetchOnWindowFocus: false,
  });

  const handleChange =
    (key: keyof PeriodState) =>
    (event: React.ChangeEvent<HTMLInputElement>) => {
      setPeriod((prev) => ({ ...prev, [key]: event.target.value }));
    };

  const handleClear = () => {
    setPeriod({ from: "", to: "" });
  };

  const handleRefresh = async () => {
    await refetch();
  };

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      error instanceof Error
        ? error.message
        : "Не удалось загрузить общий отчёт";
  }

  const emptyReport: SummaryReport = {
    revenue: 0,
    revenueFromServices: 0,
    revenueFromServicesDetails: {
      totalAmount: 0,
      totalQuantity: 0,
      averagePricePerUnit: 0,
    },
    revenueFromEquipment: 0,
    revenueFromEquipmentDetails: {
      totalAmount: 0,
      totalHours: 0,
      totalShifts: 0,
      averagePricePerHour: 0,
    },
    expenses: 0,
    expensesFuel: 0,
    expensesRepair: 0,
    salaries: 0,
    margin: 0,
    ordersCount: 0,
    period: { from: null, to: null },
  };

  const report = data ?? emptyReport;

  return (
    <RoleGuard allowedRoles={["admin", "manager", "accountant"]}>
      <section className="space-y-4">
        <PageHeader
          title="Общий отчёт"
          subtitle="Выручка, расходы, маржа и количество завершённых заявок."
        />

        <Card className="p-4 text-sm">
          <div className="flex flex-col gap-3 md:flex-row md:items-end">
            <div className="flex-1 space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                Период с
              </label>
              <input
                type="date"
                value={period.from}
                onChange={handleChange("from")}
                className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              />
            </div>
            <div className="flex-1 space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                Период по
              </label>
              <input
                type="date"
                value={period.to}
                onChange={handleChange("to")}
                className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              />
            </div>
            <div className="flex items-center gap-2 md:self-stretch">
              <button
                type="button"
                onClick={handleClear}
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

        {report ? (
          <>
            <div className="grid gap-3 md:grid-cols-4">
              <Card className="rounded-xl border-emerald-200 bg-emerald-50 p-3 text-xs">
                <div className="text-[11px] font-semibold uppercase tracking-wide text-emerald-700">
                  Выручка
                </div>
                <div className="mt-1 text-lg font-semibold text-emerald-900">
                  {formatCurrency(report.revenue)}
                </div>
                <div className="mt-1 text-[11px] text-emerald-800">
                  Завершённые заявки
                </div>
              </Card>

              <Card className="rounded-xl border-sky-200 bg-sky-50 p-3 text-xs">
                <div className="text-[11px] font-semibold uppercase tracking-wide text-sky-700">
                  Расходы
                </div>
                <div className="mt-1 text-lg font-semibold text-sky-900">
                  {formatCurrency(report.expenses)}
                </div>
                <div className="mt-1 text-[11px] text-sky-800">
                  Включая топливо: {formatCurrency(report.expensesFuel)}
                </div>
              </Card>

              <Card className="rounded-xl border-orange-200 bg-orange-50 p-3 text-xs">
                <div className="text-[11px] font-semibold uppercase tracking-wide text-orange-700">
                  Зарплаты
                </div>
                <div className="mt-1 text-lg font-semibold text-orange-900">
                  {formatCurrency(report.salaries)}
                </div>
                <div className="mt-1 text-[11px] text-orange-800">
                  Выплаты операторам
                </div>
              </Card>

              <Card className="rounded-xl border-slate-200 bg-slate-50 p-3 text-xs">
                <div className="text-[11px] font-semibold uppercase tracking-wide text-slate-700">
                  Маржа
                </div>
                <div className="mt-1 text-lg font-semibold text-slate-900">
                  {formatCurrency(report.margin)}
                </div>
                <div className="mt-1 text-[11px] text-slate-600">
                  Заявок: {formatNumber(report.ordersCount)}
                </div>
              </Card>
            </div>

            <Card className="p-4 text-xs">
              <h2 className="mb-3 text-sm font-semibold text-slate-900">
                Структура выручки
              </h2>
              <div className="grid gap-3 md:grid-cols-2">
                <div className="space-y-1 rounded-lg border border-slate-100 bg-slate-50 p-3">
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-slate-600">
                    Услуги и материалы
                  </div>
                  <div className="text-base font-semibold text-slate-900">
                    {formatCurrency(report.revenueFromServices)}
                  </div>
                  <div className="text-[11px] text-slate-600">
                    Кол-во:{" "}
                    {formatNumber(
                      report.revenueFromServicesDetails.totalQuantity,
                    )}{" "}
                    · Средняя цена:{" "}
                    {formatCurrency(
                      report.revenueFromServicesDetails.averagePricePerUnit,
                    )}
                  </div>
                </div>
                <div className="space-y-1 rounded-lg border border-slate-100 bg-slate-50 p-3">
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-slate-600">
                    Техника
                  </div>
                  <div className="text-base font-semibold text-slate-900">
                    {formatCurrency(report.revenueFromEquipment)}
                  </div>
                  <div className="text-[11px] text-slate-600">
                    Часы:{" "}
                    {formatNumber(
                      report.revenueFromEquipmentDetails.totalHours,
                    )}{" "}
                    · Смены:{" "}
                    {formatNumber(
                      report.revenueFromEquipmentDetails.totalShifts,
                    )}
                  </div>
                </div>
              </div>
            </Card>
          </>
        ) : null}

        {isLoading && !report ? (
          <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
            Загружаем общий отчёт...
          </div>
        ) : null}

        {errorMessage ? (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
            {errorMessage}
          </div>
        ) : null}
      </section>
    </RoleGuard>
  );
}


