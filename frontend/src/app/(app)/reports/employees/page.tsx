"use client";

import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { RoleGuard } from "@/shared/components/auth/RoleGuard";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import { Card } from "@/shared/components/ui/Card";
import { ReportsApi } from "@/shared/api/reportsApi";
import type { EmployeeReportItem } from "@/shared/types/reports";
import { DataTable, type DataTableColumn } from "@/shared/components/ui/DataTable";

const QUERY_KEY = ["reports", "employees"] as const;

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    maximumFractionDigits: 0,
  }).format(value);
}

export default function EmployeesReportPage() {
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const { data, isLoading, isError, error, refetch, isFetching } = useQuery<
    EmployeeReportItem[]
  >({
    queryKey: [...QUERY_KEY, { from, to }] as const,
    queryFn: () =>
      ReportsApi.getByEmployees({
        from: from || undefined,
        to: to || undefined,
      }),
    staleTime: 2 * 60_000,
    refetchOnWindowFocus: false,
  });

  const handleClear = () => {
    setFrom("");
    setTo("");
  };

  const handleRefresh = async () => {
    await refetch();
  };

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      error instanceof Error
        ? error.message
        : "Не удалось загрузить отчёт по сотрудникам";
  }

  const items = data ?? [];

  type EmployeeReportItemWithId = EmployeeReportItem & { id: number };

  const columns: DataTableColumn<EmployeeReportItemWithId>[] = [
    {
      key: "fullName",
      header: "Сотрудник",
      render: (row) => (
        <div className="space-y-0.5">
          <div className="font-medium text-slate-900">
            {row.fullName || `ID ${row.userId}`}
          </div>
        </div>
      ),
    },
    {
      key: "assignments",
      header: "Назначений",
      render: (row) => row.assignments.toString(),
    },
    {
      key: "totalHours",
      header: "Часы",
      render: (row) => row.totalHours.toFixed(1),
    },
    {
      key: "totalAmount",
      header: "Сумма",
      render: (row) => formatCurrency(row.totalAmount),
    },
  ];

  const rows: EmployeeReportItemWithId[] = items.map((item, index) => ({
    id: item.userId || index,
    ...item,
  }));

  return (
    <RoleGuard allowedRoles={["admin", "manager", "accountant"]}>
      <section className="space-y-4">
        <PageHeader
          title="Отчёт по сотрудникам"
          subtitle="Выручка, часы работы и количество назначений по операторам."
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

        {errorMessage ? (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
            {errorMessage}
          </div>
        ) : null}

        <DataTable<EmployeeReportItemWithId>
          columns={columns}
          data={rows}
          emptyText={
            isLoading
              ? "Загружаем отчёт по сотрудникам..."
              : "Нет данных за период"
          }
          maxVisibleRows={200}
        />
      </section>
    </RoleGuard>
  );
}


