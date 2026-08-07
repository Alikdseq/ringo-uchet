"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import React, { useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { OrdersApi } from "@/shared/api/ordersApi";
import type { Order, OrderStatus } from "@/shared/types/orders";
import { StatusBadge } from "@/shared/components/ui/StatusBadge";
import { Card } from "@/shared/components/ui/Card";
import { useDebouncedValue } from "@/shared/hooks";
import { useAuthStore } from "@/shared/store/authStore";

type TabKey = "ALL" | OrderStatus;

const PAGE_SIZE = 50;
const ORDER_DRAFT_STORAGE_KEY = "order-create-draft-v1";

interface OrderDraftSummary {
  clientName: string;
  address: string;
  startDt: Date | null;
}

const STATUS_TABS: { key: TabKey; label: string }[] = [
  { key: "ALL", label: "Все" },
  { key: "CREATED", label: "Создан" },
  { key: "APPROVED", label: "Одобрен" },
  { key: "IN_PROGRESS", label: "В работе" },
  { key: "COMPLETED", label: "Завершён" },
  { key: "CANCELLED", label: "Отменён" },
];

interface OrdersListFilters {
  status: TabKey;
  search: string;
  page: number;
  dateFrom: string;
  dateTo: string;
}

function useOrdersData(filters: OrdersListFilters) {
  const debouncedSearch = useDebouncedValue(filters.search, 400);

  const queryKey = [
    "orders",
    {
      status: filters.status,
      search: debouncedSearch,
      page: filters.page,
      pageSize: PAGE_SIZE,
      dateFrom: filters.dateFrom,
      dateTo: filters.dateTo,
    },
  ] as const;

  const queryResult = useQuery<Order[]>({
    queryKey,
    queryFn: () =>
      OrdersApi.list({
        status: filters.status === "ALL" ? undefined : filters.status,
        search: debouncedSearch || undefined,
        page: filters.page,
        pageSize: PAGE_SIZE,
        dateFrom: filters.dateFrom || undefined,
        dateTo: filters.dateTo || undefined,
      }),
    refetchInterval: 5000,
    staleTime: 3000,
    placeholderData: (previousData: Order[] | undefined) => previousData,
    notifyOnChangeProps: ["data", "error"],
  });

  return { ...queryResult, debouncedSearch };
}

function formatDateRange(order: Order): string {
  const start = order.startDt;
  const end = order.endDt;
  const options: Intl.DateTimeFormatOptions = {
    day: "2-digit",
    month: "2-digit",
  };
  const startStr = start
    ? start.toLocaleDateString("ru-RU", options)
    : "...";
  const endStr = end
    ? end.toLocaleDateString("ru-RU", options)
    : "...";
  return `${startStr} - ${endStr}`;
}

function formatMoney(value?: number | null): string {
  const amount = typeof value === "number" ? value : 0;
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    maximumFractionDigits: 2,
  }).format(amount);
}

export default function OrdersPage() {
  const router = useRouter();
  const [status, setStatus] = useState<TabKey>("ALL");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [draftSummary, setDraftSummary] = useState<OrderDraftSummary | null>(
    null,
  );

  const user = useAuthStore((state) => state.user);
  const role = user?.role;
  const isOperator = role === "operator";
  const canManageOrders = role === "admin" || role === "manager";

  const { data, isLoading, isError, error, refetch } = useOrdersData({
    status,
    search,
    page,
    dateFrom,
    dateTo,
  });

  // Загружаем локальный черновик заявки (если есть)
  useEffect(() => {
    if (typeof window === "undefined") return;
    try {
      const raw = window.localStorage.getItem(ORDER_DRAFT_STORAGE_KEY);
      if (!raw) {
        setDraftSummary(null);
        return;
      }
      const draft = JSON.parse(raw) as {
        newClientName?: string;
        address?: string;
        startDt?: string;
      };
      const address =
        typeof draft.address === "string" ? draft.address : "";
      const clientName =
        typeof draft.newClientName === "string" && draft.newClientName
          ? draft.newClientName
          : "Черновик клиента";
      const startDtValue = draft.startDt;
      const startDt =
        typeof startDtValue === "string" && startDtValue
          ? new Date(startDtValue)
          : null;

      setDraftSummary({
        clientName,
        address,
        startDt: Number.isNaN(startDt?.getTime() ?? NaN) ? null : startDt,
      });
    } catch {
      setDraftSummary(null);
    }
  }, []);

  const filteredOrdersForRole: Order[] = useMemo(() => {
    const baseOrders: Order[] = data ?? [];
    if (!user || role !== "operator") return baseOrders;
    return baseOrders.filter((order: Order) => {
      const operatorId = user.id;
      if (order.operatorId && order.operatorId === operatorId) return true;
      if (
        order.operators &&
        order.operators.some((op: { id: number }) => op.id === operatorId)
      ) {
        return true;
      }
      return false;
    });
  }, [data, role, user]);

  const handleStatusChange = (next: TabKey) => {
    if (next === status) return;
    setStatus(next);
    setPage(1);
  };

  const handleSearchChange = (value: string) => {
    setSearch(value);
    setPage(1);
  };

  const handleDateFromChange = (value: string) => {
    setDateFrom(value);
    setPage(1);
  };

  const handleDateToChange = (value: string) => {
    setDateTo(value);
    setPage(1);
  };

  const handleClearDates = () => {
    setDateFrom("");
    setDateTo("");
    setPage(1);
  };

  let errorMessage: string | null = null;
  if (isError) {
    if (error instanceof Error) {
      errorMessage = error.message;
    } else {
      errorMessage = "Не удалось загрузить список заявок";
    }
  }

  const handleOpenDraft = () => {
    router.push("/orders/create");
  };

  const handleDeleteDraft = () => {
    if (typeof window === "undefined") return;

    window.localStorage.removeItem(ORDER_DRAFT_STORAGE_KEY);
    setDraftSummary(null);
  };

  return (
    <section className="space-y-4 pb-6">
      <div className="space-y-2">
        <div className="rounded-xl border border-slate-200 bg-white px-3 py-2">
          <div className="flex items-center gap-2">
            <span className="text-lg text-slate-500">🔍</span>
            <input
              type="text"
              placeholder="Поиск по номеру, клиенту, адресу..."
              className="h-8 w-full border-none bg-transparent text-sm text-slate-900 placeholder:text-slate-400 focus:outline-none"
              value={search}
              onChange={(event) => handleSearchChange(event.target.value)}
            />
            <button
              type="button"
              onClick={() => {
                void refetch();
              }}
              className="text-xs text-slate-500"
            >
              ⟳
            </button>
          </div>
        </div>

        <div className="rounded-xl border border-slate-200 bg-white px-3 py-2">
          <div className="flex flex-wrap items-center gap-2 text-xs">
            <span className="text-slate-500">Период</span>
            <input
              type="date"
              value={dateFrom}
              onChange={(event) => handleDateFromChange(event.target.value)}
              className="rounded-md border border-slate-200 px-2 py-1 text-xs text-slate-800 outline-none focus:border-sky-400"
            />
            <span className="text-slate-400">—</span>
            <input
              type="date"
              value={dateTo}
              onChange={(event) => handleDateToChange(event.target.value)}
              className="rounded-md border border-slate-200 px-2 py-1 text-xs text-slate-800 outline-none focus:border-sky-400"
            />
            {dateFrom || dateTo ? (
              <button
                type="button"
                onClick={handleClearDates}
                className="rounded-md px-2 py-1 text-[11px] font-medium text-slate-500 hover:bg-slate-100 hover:text-slate-700"
              >
                Сбросить
              </button>
            ) : null}
          </div>
        </div>

        <div className="flex flex-wrap gap-2 border-b border-slate-200 pb-1 text-xs">
          {STATUS_TABS.map((tab) => {
            const active = tab.key === status;
            return (
              <button
                key={tab.key}
                type="button"
                onClick={() => handleStatusChange(tab.key)}
                className={`flex items-center gap-1 border-b-2 px-2 pb-1 ${
                  active
                    ? "border-sky-500 text-sky-600"
                    : "border-transparent text-slate-500"
                }`}
              >
                <span
                  className={`h-2 w-2 rounded-full ${
                    tab.key === "CREATED"
                      ? "bg-sky-400"
                      : tab.key === "APPROVED"
                        ? "bg-orange-400"
                        : tab.key === "IN_PROGRESS"
                          ? "bg-amber-400"
                          : tab.key === "COMPLETED"
                            ? "bg-emerald-500"
                            : tab.key === "CANCELLED"
                              ? "bg-rose-500"
                              : "bg-slate-300"
                  }`}
                />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      {errorMessage ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {errorMessage}
        </div>
      ) : null}

      {canManageOrders && draftSummary && (status === "ALL" || status === "DRAFT") ? (
        <div className="space-y-1">
          <div className="text-[11px] font-medium uppercase tracking-wide text-slate-500">
            Черновики
          </div>
          <Card className="mb-1 rounded-xl border-dashed border-sky-300 bg-sky-50 px-3 py-3 text-sm shadow-sm">
            <button
              type="button"
              onClick={handleOpenDraft}
              className="flex w-full items-center justify-between gap-3 text-left"
            >
              <div className="space-y-1">
                <div className="text-sm font-semibold text-slate-900">
                  Заявка (черновик)
                </div>
                <div className="text-xs text-slate-500">
                  {draftSummary.clientName}
                </div>
                {draftSummary.address ? (
                  <div className="text-xs text-slate-500 line-clamp-1">
                    {draftSummary.address}
                  </div>
                ) : null}
                <div className="text-[11px] text-slate-400">
                  {draftSummary.startDt
                    ? draftSummary.startDt.toLocaleString("ru-RU", {
                        day: "2-digit",
                        month: "2-digit",
                        hour: "2-digit",
                        minute: "2-digit",
                      })
                    : "Дата начала не указана"}
                </div>
              </div>
              <div className="flex flex-col items-end gap-1">
                <StatusBadge status="DRAFT" />
                <div className="text-[11px] font-medium text-slate-500">
                  Нажмите, чтобы продолжить заполнение
                </div>
              </div>
            </button>
            <div className="mt-2 flex justify-end">
              <button
                type="button"
                onClick={handleDeleteDraft}
                className="inline-flex items-center rounded-md border border-slate-300 bg-white px-2 py-1 text-[11px] font-medium text-slate-600 shadow-sm hover:bg-slate-100"
              >
                🗑 <span className="ml-1">Удалить черновик</span>
              </button>
            </div>
          </Card>
        </div>
      ) : null}

      <div className="space-y-2">
        {/* Показываем loading только при первой загрузке, не при background refetch */}
        {isLoading && !data && filteredOrdersForRole.length === 0 ? (
          <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
            Загружаем список заявок...
          </div>
        ) : null}

        {filteredOrdersForRole.map((order) => {
          // Админ/менеджер — сразу в редактирование; оператор — просмотр
          const detailUrl = isOperator
            ? `/orders/${order.id}`
            : `/orders/${order.id}/edit`;

          return (
          <Link key={order.id} href={detailUrl}>
            <Card className="mb-1 flex items-center justify-between rounded-xl px-3 py-3 text-sm shadow-sm">
              <div className="space-y-1">
                <div className="text-sm font-semibold text-slate-900">
                  Заказ {order.number}
                </div>
                <div className="text-xs text-slate-500">
                  {order.client?.name ?? ""}
                </div>
                <div className="text-xs text-slate-500 line-clamp-1">
                  {order.address}
                </div>
                <div className="text-[11px] text-slate-400">
                  {formatDateRange(order)}
                </div>
              </div>
              <div className="flex flex-col items-end gap-1">
                <StatusBadge status={order.status} />
                {!isOperator ? (
                  <div className="text-xs font-semibold text-sky-600">
                    {formatMoney(order.totalAmount)}
                  </div>
                ) : null}
              </div>
            </Card>
          </Link>
          );
        })}

        {!isLoading && filteredOrdersForRole.length === 0 ? (
          <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
            {isOperator
              ? "Нет назначенных вам заявок."
              : "Заявки не найдены."}
          </div>
        ) : null}
      </div>

      {canManageOrders ? (
        <Link
          href="/orders/create"
          className="fixed bottom-20 right-4 inline-flex h-12 w-12 items-center justify-center rounded-full bg-sky-500 text-2xl text-white shadow-lg md:bottom-6"
        >
          +
        </Link>
      ) : null}
    </section>
  );
}
