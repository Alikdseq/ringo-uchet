"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { OrdersApi } from "@/shared/api/ordersApi";
import type { Order, OrderItem, OrderStatus } from "@/shared/types/orders";
import { StatusBadge } from "@/shared/components/ui/StatusBadge";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import { Card } from "@/shared/components/ui/Card";

function OrderDetailSkeleton() {
  return (
    <div className="space-y-3">
      <div className="h-6 w-40 animate-pulse rounded bg-slate-200" />
      <div className="grid gap-3 md:grid-cols-2">
        <div className="h-32 animate-pulse rounded bg-slate-100" />
        <div className="h-32 animate-pulse rounded bg-slate-100" />
      </div>
      <div className="h-40 animate-pulse rounded bg-slate-100" />
    </div>
  );
}

interface SectionProps {
  title: string;
  children: React.ReactNode;
}

function Section({ title, children }: SectionProps) {
  return (
    <Card className="p-4">
      <h2 className="mb-2 text-sm font-semibold text-slate-900">{title}</h2>
      <div className="text-sm text-slate-700">{children}</div>
    </Card>
  );
}

function formatDateTime(value?: Date | null): string {
  if (!value) return "-";
  return value.toLocaleString("ru-RU", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function formatMoney(value?: number | null): string {
  const amount = typeof value === "number" ? value : 0;
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}

const ORDER_STATUS_OPTIONS: { value: OrderStatus; label: string }[] = [
  { value: "CREATED", label: "Создана" },
  { value: "APPROVED", label: "Одобрена" },
  { value: "IN_PROGRESS", label: "В работе" },
  { value: "COMPLETED", label: "Завершена" },
  { value: "CANCELLED", label: "Отменена" },
];

export default function OrderDetailPage() {
  const params = useParams();
  const router = useRouter();
  const orderId = params?.orderId as string | undefined;
  const queryClient = useQueryClient();

  const [isStatusModalOpen, setIsStatusModalOpen] = useState(false);
  const [nextStatus, setNextStatus] = useState<OrderStatus | "">("");
  const [statusComment, setStatusComment] = useState("");
  const [statusError, setStatusError] = useState<string | null>(null);
  const [isReceiptLoading, setIsReceiptLoading] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const {
    data: order,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery<Order>({
    queryKey: ["order", orderId],
    enabled: Boolean(orderId),
    queryFn: () => OrdersApi.get(orderId as string),
  });

  const changeStatusMutation = useMutation({
    mutationFn: async (payload: { status: OrderStatus; comment?: string }) => {
      if (!orderId) return;
      await OrdersApi.changeStatus(orderId, payload);
    },
    onSuccess: async () => {
      if (orderId) {
        void queryClient.invalidateQueries({ queryKey: ["orders"] });
      }
      setIsStatusModalOpen(false);
      setStatusError(null);
      setStatusComment("");
      setNextStatus("");
      await refetch();
    },
    onError: (err: unknown) => {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось изменить статус, попробуйте позже";
      setStatusError(message);
    },
  });

  const handleDownloadReceipt = async () => {
    if (!order) return;
    try {
      setIsReceiptLoading(true);
      const blob = await OrdersApi.getReceiptPdf(order.id);
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `receipt_${order.number}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (err) {
      // Ошибку можно показать в статусах/тосте, пока просто логируем
      // eslint-disable-next-line no-console
      console.error(err);
    } finally {
      setIsReceiptLoading(false);
    }
  };

  const handleOpenStatusModal = () => {
    if (!order) return;
    setNextStatus(order.status);
    setStatusComment("");
    setStatusError(null);
    setIsStatusModalOpen(true);
  };

  const handleSubmitStatusChange = () => {
    if (!nextStatus || !orderId) return;
    setStatusError(null);
    changeStatusMutation.mutate({
      status: nextStatus,
      comment: statusComment || undefined,
    });
  };

  const handleDelete = async () => {
    if (!order) return;
    setIsDeleting(true);
    try {
      await OrdersApi.delete(order.id);
      void queryClient.invalidateQueries({ queryKey: ["orders"] });
      void queryClient.invalidateQueries({ queryKey: ["reports"] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      setIsDeleteModalOpen(false);
      router.replace("/orders");
    } finally {
      setIsDeleting(false);
    }
  };

  let errorMessage: string | null = null;
  if (isError) {
    if (error instanceof Error) {
      errorMessage = error.message;
    } else {
      errorMessage = "Не удалось загрузить заявку";
    }
  }

  return (
    <section className="space-y-4">
      <PageHeader
        title={order ? `Заявка ${order.number}` : "Заявка"}
        subtitle={
          order
            ? `Создана ${formatDateTime(order.createdAt)} · Обновлена ${formatDateTime(
                order.updatedAt,
              )}`
            : "Детали заявки"
        }
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => router.back()}
              className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50"
            >
              Назад
            </button>
            {order ? (
              <>
                <Link
                  href={`/orders/${order.id}/edit`}
                  className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                >
                  Изменить
                </Link>
                <button
                  type="button"
                  onClick={handleOpenStatusModal}
                  className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                >
                  Изменить статус
                </button>
                {order.status === "IN_PROGRESS" ? (
                  <Link
                    href={`/orders/${order.id}/complete`}
                    className="inline-flex items-center rounded-md border border-emerald-500 bg-emerald-500 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-emerald-600"
                  >
                    Завершить
                  </Link>
                ) : null}
                {order.status !== "COMPLETED" ? (
                  <button
                    type="button"
                    onClick={() => setIsDeleteModalOpen(true)}
                    className="rounded-md border border-red-300 bg-red-50 px-3 py-1.5 text-xs font-medium text-red-700 shadow-sm hover:bg-red-100"
                  >
                    Удалить
                  </button>
                ) : null}
              </>
            ) : null}
            <button
              type="button"
              disabled={isLoading}
              onClick={() => {
                void refetch();
              }}
              className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
            >
              Обновить
            </button>
          </div>
        }
      />

      {isLoading && !order ? <OrderDetailSkeleton /> : null}

      {errorMessage ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {errorMessage}
        </div>
      ) : null}

      {order ? (
        <div className="space-y-4">
          {order.status === "COMPLETED" ? (
            <Card className="flex flex-wrap items-center justify-between gap-3 border-emerald-200 bg-emerald-50 p-3 text-xs">
              <div className="space-y-1">
                <div className="text-[11px] font-semibold uppercase tracking-wide text-emerald-700">
                  Действия с завершённой заявкой
                </div>
                <div className="text-[11px] text-emerald-800">
                  Скачайте чек для клиента или удалите заявку при необходимости.
                </div>
              </div>
              <div className="flex flex-1 justify-end gap-2">
                <button
                  type="button"
                  onClick={() => {
                    void handleDownloadReceipt();
                  }}
                  disabled={isReceiptLoading}
                  className="inline-flex flex-1 items-center justify-center rounded-md bg-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-60 md:flex-none"
                >
                  {isReceiptLoading ? "Формируем чек..." : "Получить чек"}
                </button>
                <button
                  type="button"
                  onClick={() => setIsDeleteModalOpen(true)}
                  className="inline-flex flex-1 items-center justify-center rounded-md border border-red-300 bg-red-50 px-4 py-2 text-sm font-semibold text-red-700 shadow-sm hover:bg-red-100 md:flex-none"
                >
                  Удалить
                </button>
              </div>
            </Card>
          ) : null}
          {/* Header */}
          <Card className="p-4">
            <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
              <div>
                <div className="flex items-center gap-3">
                  <span className="text-sm font-medium text-slate-500">
                    Заявка
                  </span>
                  <span className="text-lg font-semibold text-slate-900">
                    {order.number}
                  </span>
                  <StatusBadge status={order.status} />
                </div>
                <div className="mt-1 text-xs text-slate-500">
                  Создана: {formatDateTime(order.createdAt)} · Начало:{" "}
                  {formatDateTime(order.startDt)} · Окончание:{" "}
                  {formatDateTime(order.endDt)}
                </div>
              </div>
              <div className="text-right text-sm text-slate-700">
                <div className="font-semibold">
                  Сумма: {formatMoney(order.totalAmount)}
                </div>
                <div className="text-xs text-slate-500">
                  Предоплата: {formatMoney(order.prepaymentAmount)} (
                  {order.prepaymentStatus})
                </div>
              </div>
            </div>
          </Card>

          {/* Клиент и адрес/карта */}
          <div className="grid gap-4 md:grid-cols-2">
            <Section title="Клиент">
              {order.client ? (
                <div className="space-y-1">
                  <div className="font-semibold">{order.client.name}</div>
                  <div className="text-xs text-slate-600">
                    {order.client.phone}
                    {order.client.email ? ` · ${order.client.email}` : ""}
                  </div>
                  {order.client.address ? (
                    <div className="text-xs text-slate-500">
                      Адрес: {order.client.address}
                    </div>
                  ) : null}
                </div>
              ) : (
                <div className="text-xs text-slate-500">Клиент не указан</div>
              )}
            </Section>

            <Section title="Адрес и координаты">
              <div className="space-y-1 text-xs">
                <div className="text-slate-700">{order.address}</div>
                <div className="text-slate-500">
                  Координаты:{" "}
                  {order.geoLat != null && order.geoLng != null
                    ? `${order.geoLat.toFixed(6)}, ${order.geoLng.toFixed(6)}`
                    : "не указаны"}
                </div>
                <div className="mt-2 rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-2 text-[11px] text-slate-400">
                  Карта будет интегрирована позже (отдельной задачей).
                </div>
              </div>
            </Section>
          </div>

          {/* Операторы и менеджер */}
          <Section title="Участники">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-1 text-xs">
                <div className="font-semibold text-slate-800">Менеджер</div>
                {order.manager ? (
                  <>
                    <div className="text-slate-700">
                      {order.manager.fullNameFromApi ||
                        `${order.manager.firstName ?? ""} ${
                          order.manager.lastName ?? ""
                        }`.trim() ||
                        order.manager.username ||
                        "—"}
                    </div>
                    {order.manager.phone ? (
                      <div className="text-slate-500">{order.manager.phone}</div>
                    ) : null}
                  </>
                ) : (
                  <div className="text-slate-500">Не назначен</div>
                )}
              </div>
              <div className="space-y-1 text-xs">
                <div className="font-semibold text-slate-800">Операторы</div>
                {order.operators && order.operators.length > 0 ? (
                  <ul className="list-inside list-disc space-y-0.5 text-slate-700">
                    {order.operators.map((op) => {
                      const fullName =
                        op.fullNameFromApi ||
                        `${op.firstName ?? ""} ${op.lastName ?? ""}`.trim() ||
                        op.username ||
                        `ID ${op.id}`;
                      return <li key={op.id}>{fullName}</li>;
                    })}
                  </ul>
                ) : order.operator ? (
                  <div className="text-slate-700">
                    {order.operator.fullNameFromApi ||
                      `${order.operator.firstName ?? ""} ${
                        order.operator.lastName ?? ""
                      }`.trim() ||
                      order.operator.username ||
                      `ID ${order.operator.id}`}
                  </div>
                ) : (
                  <div className="text-slate-500">Операторы не назначены</div>
                )}
              </div>
            </div>
          </Section>

          {/* Позиции заказа */}
          <Section title="Позиции заказа">
            {order.items && order.items.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-slate-200 text-xs">
                  <thead className="bg-slate-50">
                    <tr>
                      <th className="px-2 py-1 text-left font-semibold text-slate-600">
                        Наименование
                      </th>
                      <th className="px-2 py-1 text-right font-semibold text-slate-600">
                        Кол-во
                      </th>
                      <th className="px-2 py-1 text-right font-semibold text-slate-600">
                        Цена
                      </th>
                      <th className="px-2 py-1 text-right font-semibold text-slate-600">
                        Скидка
                      </th>
                      <th className="px-2 py-1 text-right font-semibold text-slate-600">
                        Итого
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 bg-white">
                    {order.items.map((item: OrderItem, index: number) => (
                      <tr key={item.id ?? index}>
                        <td className="px-2 py-1 text-slate-800">
                          <div className="font-medium">
                            {item.nameSnapshot || "Позиция"}
                          </div>
                          <div className="text-[11px] uppercase text-slate-400">
                            {item.itemType}
                          </div>
                        </td>
                        <td className="px-2 py-1 text-right text-slate-700">
                          {item.quantity.toFixed(2)} {item.unit}
                        </td>
                        <td className="px-2 py-1 text-right text-slate-700">
                          {formatMoney(item.unitPrice)}
                        </td>
                        <td className="px-2 py-1 text-right text-slate-700">
                          {item.discount.toFixed(2)}%
                        </td>
                        <td className="px-2 py-1 text-right text-slate-900">
                          {formatMoney(item.lineTotal ?? item.unitPrice * item.quantity)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="text-xs text-slate-500">
                Позиции в заявке отсутствуют.
              </div>
            )}
          </Section>

          {/* Финансы */}
          <Section title="Финансы">
            <div className="grid gap-4 md:grid-cols-3">
              <div className="space-y-1 text-xs">
                <div className="text-slate-500">Предоплата</div>
                <div className="text-sm font-semibold text-slate-900">
                  {formatMoney(order.prepaymentAmount)}
                </div>
                <div className="text-slate-500 text-[11px]">
                  Статус: {order.prepaymentStatus}
                </div>
              </div>
              <div className="space-y-1 text-xs">
                <div className="text-slate-500">Сумма</div>
                <div className="text-sm font-semibold text-slate-900">
                  {formatMoney(order.totalAmount)}
                </div>
              </div>
              <div className="space-y-1 text-xs">
                <div className="text-slate-500">Snapshot</div>
                <div className="text-[11px] text-slate-500">
                  Структура цены хранится в <code>price_snapshot</code> и будет
                  отображена отдельным компонентом на следующем этапе.
                </div>
              </div>
            </div>
          </Section>

          {/* Блоки таймлайна статусов и фото убраны по требованию бизнес-логики */}
        </div>
      ) : null}

      {isStatusModalOpen ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-md rounded-lg bg-white p-4 shadow-lg">
            <h2 className="mb-3 text-sm font-semibold text-slate-900">
              Изменить статус заявки
            </h2>
            <div className="space-y-3 text-xs">
              <div className="space-y-1.5">
                <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                  Новый статус
                </label>
                <select
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                  value={nextStatus}
                  onChange={(event) =>
                    setNextStatus(event.target.value as OrderStatus)
                  }
                  disabled={changeStatusMutation.isPending}
                >
                  <option value="">Выберите статус</option>
                  {ORDER_STATUS_OPTIONS.map((option) => (
                    <option
                      key={option.value}
                      value={option.value}
                      disabled={option.value === order?.status}
                    >
                      {option.label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-1.5">
                <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                  Комментарий (опционально)
                </label>
                <textarea
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                  rows={3}
                  value={statusComment}
                  onChange={(event) => setStatusComment(event.target.value)}
                  disabled={changeStatusMutation.isPending}
                />
              </div>

              {statusError ? (
                <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
                  {statusError}
                </div>
              ) : null}

              <div className="flex justify-end gap-2 pt-1">
                <button
                  type="button"
                  onClick={() => {
                    if (changeStatusMutation.isPending) return;
                    setIsStatusModalOpen(false);
                  }}
                  className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                >
                  Отмена
                </button>
                <button
                  type="button"
                  onClick={handleSubmitStatusChange}
                  disabled={!nextStatus || changeStatusMutation.isPending}
                  className="inline-flex items-center rounded-md border border-slate-900 bg-slate-900 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {changeStatusMutation.isPending
                    ? "Сохраняем..."
                    : "Сохранить"}
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {order && isDeleteModalOpen ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-lg bg-white p-4 text-xs shadow-lg">
            <h2 className="mb-2 text-sm font-semibold text-slate-900">
              Удалить заявку
            </h2>
            <p className="mb-3 text-[11px] text-slate-600">
              Вы действительно хотите удалить заявку {order.number}? Это действие
              нельзя будет отменить.
            </p>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setIsDeleteModalOpen(false)}
                disabled={isDeleting}
                className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
              >
                Отмена
              </button>
              <button
                type="button"
                onClick={() => {
                  void handleDelete();
                }}
                disabled={isDeleting}
                className="rounded-md border border-red-500 bg-red-500 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-red-600 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {isDeleting ? "Удаляем..." : "Удалить"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  );
}


