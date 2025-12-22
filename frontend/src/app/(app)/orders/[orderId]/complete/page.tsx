"use client";

import React, { FormEvent, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { OrdersApi } from "@/shared/api/ordersApi";
import type { Order } from "@/shared/types/orders";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import { Card } from "@/shared/components/ui/Card";

function formatUtcWithoutMillis(date: Date): string {
  const iso = date.toISOString();
  return iso.replace(/\.\d+Z$/, "Z");
}

export default function OrderCompletePage() {
  const params = useParams();
  const router = useRouter();
  const orderId = params?.orderId as string | undefined;
  const queryClient = useQueryClient();

  const { data: order, isLoading, isError, error } = useQuery<Order>({
    queryKey: ["order-complete", orderId],
    enabled: Boolean(orderId),
    queryFn: () => OrdersApi.get(orderId as string),
  });

  const [endDt, setEndDt] = useState("");
  const [comment, setComment] = useState("");
  const [operatorSalaries, setOperatorSalaries] = useState<
    { operatorId: number; name: string; salary: string }[]
  >([]);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (!order) return;
    if (order.endDt) {
      setEndDt(new Date(order.endDt).toISOString().slice(0, 16));
    }

    const entries: { operatorId: number; name: string; salary: string }[] = [];
    if (order.operators && order.operators.length > 0) {
      order.operators.forEach((op) => {
        if (typeof op.id !== "number") return;
        const name =
          `${op.firstName ?? ""} ${op.lastName ?? ""}`.trim() ||
          op.fullNameFromApi ||
          op.username ||
          `Оператор #${op.id}`;
        entries.push({ operatorId: op.id, name, salary: "" });
      });
    } else if (order.operator && typeof order.operator.id === "number") {
      const op = order.operator;
      const name =
        `${op.firstName ?? ""} ${op.lastName ?? ""}`.trim() ||
        op.fullNameFromApi ||
        op.username ||
        `Оператор #${op.id}`;
      entries.push({ operatorId: op.id, name, salary: "" });
    }
    setOperatorSalaries(entries);
  }, [order]);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!orderId) return;

    if (!endDt) {
      setSubmitError("Укажите дату и время окончания");
      return;
    }

    setSubmitError(null);
    setIsSubmitting(true);

    try {
      const end = new Date(endDt);
      const payload: Record<string, unknown> = {
        end_dt: formatUtcWithoutMillis(end),
      };

      if (comment.trim()) {
        payload.comment = comment.trim();
      }

      const salariesPayload = operatorSalaries
        .map((entry) => ({
          operator_id: entry.operatorId,
          salary: entry.salary ? Number(entry.salary) : 0,
        }))
        .filter((item) => item.salary > 0);

      if (salariesPayload.length > 0) {
        payload.operator_salaries = salariesPayload;
      }

      const updated = await OrdersApi.complete(orderId, payload);

      // Немедленно обновляем кэш заявки для всех возможных ключей
      queryClient.setQueryData<Order>(["order", updated.id], updated);
      queryClient.setQueryData<Order>(["order-edit", updated.id], updated);
      queryClient.setQueryData<Order>(["order-complete", orderId], updated);
      // Инвалидируем списки и отчёты в фоне (для всех пользователей, включая операторов)
      void queryClient.invalidateQueries({ queryKey: ["orders"] });
      void queryClient.invalidateQueries({ queryKey: ["reports"] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      void queryClient.invalidateQueries({ queryKey: ["profile", "operator-salary"] });

      // Перенаправляем на список заявок после успешного завершения
      router.replace("/orders");
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось завершить заявку, попробуйте позже";
      setSubmitError(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  let loadError: string | null = null;
  if (isError) {
    loadError =
      error instanceof Error ? error.message : "Не удалось загрузить заявку";
  }

  return (
    <section className="space-y-4">
      <PageHeader
        title={order ? `Завершение заявки ${order.number}` : "Завершение заявки"}
        subtitle="Укажите фактическую дату окончания и, при необходимости, комментарий и итоговую зарплату операторов."
      />

      {loadError ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {loadError}
        </div>
      ) : null}

      {order ? (
        <Card className="p-4 text-sm">
          <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
            <div className="space-y-1">
              <div className="text-xs text-slate-500">Заявка</div>
              <div className="text-base font-semibold text-slate-900">
                {order.number}
              </div>
              <div className="text-xs text-slate-600">
                {order.client?.name ?? "Клиент не указан"}
              </div>
              {order.address ? (
                <div className="text-[11px] text-slate-500">{order.address}</div>
              ) : null}
            </div>
            <div className="text-right text-xs text-slate-500">
              <div>
                Начало:{" "}
                <span className="font-medium">
                  {order.startDt ? order.startDt.toLocaleString("ru-RU") : "-"}
                </span>
              </div>
              <div>
                Текущее окончание:{" "}
                <span className="font-medium">
                  {order.endDt ? order.endDt.toLocaleString("ru-RU") : "не указано"}
                </span>
              </div>
            </div>
          </div>
        </Card>
      ) : null}

      <Card className="p-4 text-sm">
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid gap-3 md:grid-cols-2">
            <div className="space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                Дата и время окончания *
              </label>
              <input
                type="datetime-local"
                value={endDt}
                onChange={(event) => setEndDt(event.target.value)}
                className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-sm text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                disabled={isSubmitting || isLoading}
              />
            </div>
            {operatorSalaries.length > 0 ? (
              <div className="space-y-1.5">
                <div className="text-xs font-semibold text-slate-700">
                  Зарплата операторам
                </div>
                <div className="space-y-2 rounded-md border border-slate-200 bg-slate-50 p-2">
                  <p className="text-[11px] text-slate-500">
                    Укажите зарплату для каждого оператора
                  </p>
                  {operatorSalaries.map((entry, index) => (
                    <div key={entry.operatorId} className="space-y-1.5">
                      <label className="block text-[11px] font-medium text-slate-700">
                        ЗП для {entry.name} (₽)
                      </label>
                      <input
                        type="number"
                        min={0}
                        step="0.01"
                        value={entry.salary}
                        onChange={(event) => {
                          const value = event.target.value;
                          setOperatorSalaries((prev) =>
                            prev.map((item, i) =>
                              i === index ? { ...item, salary: value } : item,
                            ),
                          );
                        }}
                        className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-sm text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                        disabled={isSubmitting || isLoading}
                      />
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
          </div>

          <div className="space-y-1.5">
            <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
              Комментарий
            </label>
            <textarea
              rows={3}
              value={comment}
              onChange={(event) => setComment(event.target.value)}
              className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Дополнительная информация по завершению заявки"
              disabled={isSubmitting || isLoading}
            />
          </div>

          {submitError ? (
            <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
              {submitError}
            </div>
          ) : null}

          <div className="flex items-center justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={() => router.back()}
              disabled={isSubmitting}
              className="inline-flex items-center justify-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
            >
              Отмена
            </button>
            <button
              type="submit"
              disabled={isSubmitting || isLoading}
              className="inline-flex items-center justify-center rounded-md bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-400"
            >
              {isSubmitting ? "Завершаем..." : "Завершить заявку"}
            </button>
          </div>
        </form>
      </Card>
    </section>
  );
}


