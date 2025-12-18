"use client";

import React, { useState } from "react";
import { Card } from "@/shared/components/ui/Card";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import {
  type OfflineQueueItem,
  OfflineQueueService,
} from "@/shared/offline/offlineQueue";

function formatDateTime(iso: string): string {
  if (!iso) return "";
  const dt = new Date(iso);
  if (Number.isNaN(dt.getTime())) return "";
  const year = dt.getFullYear();
  const month = String(dt.getMonth() + 1).padStart(2, "0");
  const day = String(dt.getDate()).padStart(2, "0");
  const hours = String(dt.getHours()).padStart(2, "0");
  const minutes = String(dt.getMinutes()).padStart(2, "0");
  return `${day}.${month}.${year} ${hours}:${minutes}`;
}

export default function OfflineQueuePage() {
  const [items, setItems] = useState<OfflineQueueItem[]>(() =>
    OfflineQueueService.list(),
  );
  const [isSyncingAll, setIsSyncingAll] = useState(false);
  const [syncError, setSyncError] = useState<string | null>(null);

  const refresh = () => {
    setItems(OfflineQueueService.list());
  };

  const handleRetryAll = async () => {
    setIsSyncingAll(true);
    setSyncError(null);
    try {
      await OfflineQueueService.retryAll();
      refresh();
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Не удалось синхронизировать очередь";
      setSyncError(message);
    } finally {
      setIsSyncingAll(false);
    }
  };

  const handleRetryOne = async (id: string) => {
    await OfflineQueueService.retryItem(id);
    refresh();
  };

  const handleRemove = (id: string) => {
    OfflineQueueService.remove(id);
    refresh();
  };

  return (
    <section className="space-y-4">
      <PageHeader
        title="Оффлайн очередь"
        subtitle="Несинхронизированные действия (создание заявок, смена статуса, завершение)."
        actions={
          <button
            type="button"
            onClick={handleRetryAll}
            disabled={isSyncingAll || items.length === 0}
            className="rounded-md border border-slate-900 bg-slate-900 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-400"
          >
            {isSyncingAll ? "Синхронизируем..." : "Синхронизировать всё"}
          </button>
        }
      />

      {syncError ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {syncError}
        </div>
      ) : null}

      <Card className="p-0 text-xs">
        {items.length === 0 ? (
          <div className="flex items-center justify-center px-4 py-10 text-xs text-slate-500">
            Очередь пуста. Все действия синхронизированы.
          </div>
        ) : (
          <div className="min-w-full divide-y divide-slate-100">
            <div className="grid grid-cols-5 gap-2 px-4 py-2 text-[11px] font-semibold uppercase tracking-wide text-slate-500">
              <div>Действие</div>
              <div>Endpoint</div>
              <div>Создано</div>
              <div>Повторы / Ошибка</div>
              <div className="text-right">Действия</div>
            </div>
            {items.map((item) => (
              <div
                key={item.id}
                className="grid grid-cols-5 gap-2 px-4 py-2 align-middle text-[11px] text-slate-700"
              >
                <div>
                  <div className="font-medium">
                    {item.meta?.label ?? item.action}
                  </div>
                  {item.meta?.orderId || item.meta?.orderNumber ? (
                    <div className="text-[10px] text-slate-500">
                      {item.meta?.orderNumber
                        ? `Заказ ${item.meta.orderNumber}`
                        : `Заказ ID ${item.meta?.orderId}`}
                    </div>
                  ) : null}
                </div>
                <div className="break-all text-[10px] text-slate-500">
                  {item.endpoint}
                </div>
                <div>{formatDateTime(item.createdAt)}</div>
                <div>
                  <div>Повторов: {item.retries}</div>
                  {item.lastError ? (
                    <div className="mt-0.5 text-[10px] text-red-600">
                      {item.lastError}
                    </div>
                  ) : null}
                </div>
                <div className="flex items-center justify-end gap-2">
                  <button
                    type="button"
                    onClick={() => handleRetryOne(item.id)}
                    className="rounded-md border border-slate-300 bg-white px-2 py-1 text-[10px] font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                  >
                    Повторить
                  </button>
                  <button
                    type="button"
                    onClick={() => handleRemove(item.id)}
                    className="rounded-md border border-red-200 bg-white px-2 py-1 text-[10px] font-medium text-red-600 shadow-sm hover:bg-red-50"
                  >
                    Удалить
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>
    </section>
  );
}

