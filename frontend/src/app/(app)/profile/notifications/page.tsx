"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import React, { useState } from "react";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import { Card } from "@/shared/components/ui/Card";
import { NotificationsApi } from "@/shared/api/notificationsApi";
import type { NotificationPreferences } from "@/shared/types/notifications";

const QUERY_KEY = ["notifications", "preferences"] as const;

export default function NotificationSettingsPage() {
  const queryClient = useQueryClient();
  const [overrides, setOverrides] = useState<Partial<NotificationPreferences>>(
    {},
  );

  const {
    data: prefs,
    isLoading,
    isError,
    refetch,
    error,
  } = useQuery<NotificationPreferences>({
    queryKey: QUERY_KEY,
    queryFn: () => NotificationsApi.getPreferences(),
    staleTime: 5 * 60_000,
    refetchOnWindowFocus: false,
  });

  const mutation = useMutation({
    mutationFn: (next: NotificationPreferences) =>
      NotificationsApi.updatePreferences(next),
    onSuccess: (updated) => {
      queryClient.setQueryData(QUERY_KEY, updated);
      setOverrides({});
    },
  });

  const DEFAULT_PREFS: NotificationPreferences = {
    orderCreated: true,
    statusChanged: true,
    paymentReceived: true,
    invoiceReady: true,
    kassaFull: true,
  };

  const basePrefs: NotificationPreferences = (prefs ?? DEFAULT_PREFS) as NotificationPreferences;
  const current: NotificationPreferences = {
    ...basePrefs,
    ...overrides,
  } as NotificationPreferences;

  const handleToggle = (key: keyof NotificationPreferences) => {
    setOverrides((prev) => ({
      ...prev,
      [key]: !current[key],
    }));
  };

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      error instanceof Error
        ? error.message
        : "Не удалось загрузить настройки уведомлений";
  }

  const isSaving = mutation.isPending;

  const handleSave = async () => {
    await mutation.mutateAsync(current);
  };

  const handleRefresh = async () => {
    setOverrides({});
    await refetch();
  };

  return (
    <section className="space-y-4">
      <PageHeader
        title="Настройки уведомлений"
        subtitle="Выберите, какие события будут присылать уведомления."
        actions={
          <div className="flex gap-2">
            <button
              type="button"
              onClick={handleRefresh}
              disabled={isLoading}
              className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
            >
              Обновить
            </button>
            <button
              type="button"
              onClick={handleSave}
              disabled={isSaving}
              className="rounded-md border border-slate-900 bg-slate-900 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {isSaving ? "Сохраняем..." : "Сохранить"}
            </button>
          </div>
        }
      />

      {errorMessage ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {errorMessage}
        </div>
      ) : null}

      <Card className="p-4 text-xs">
        <div className="space-y-3">
          <ToggleRow
            label="Создание заявки"
            description="Получать уведомление при создании новой заявки."
            checked={current.orderCreated}
            disabled={isLoading || isSaving}
            onChange={() => handleToggle("orderCreated")}
          />
          <ToggleRow
            label="Изменение статуса"
            description="Уведомления о смене статуса заявок."
            checked={current.statusChanged}
            disabled={isLoading || isSaving}
            onChange={() => handleToggle("statusChanged")}
          />
          <ToggleRow
            label="Поступление оплаты"
            description="Уведомления о получении платежей."
            checked={current.paymentReceived}
            disabled={isLoading || isSaving}
            onChange={() => handleToggle("paymentReceived")}
          />
          <ToggleRow
            label="Готовность счёта/акта"
            description="Уведомления о сформированных счетах и актах."
            checked={current.invoiceReady}
            disabled={isLoading || isSaving}
            onChange={() => handleToggle("invoiceReady")}
          />
          <ToggleRow
            label="Заполненность кассы"
            description="Предупреждение, когда касса близка к лимиту."
            checked={current.kassaFull}
            disabled={isLoading || isSaving}
            onChange={() => handleToggle("kassaFull")}
          />
        </div>
      </Card>
    </section>
  );
}

interface ToggleRowProps {
  label: string;
  description: string;
  checked: boolean;
  disabled?: boolean;
  onChange: () => void;
}

function ToggleRow({
  label,
  description,
  checked,
  disabled,
  onChange,
}: ToggleRowProps) {
  return (
    <div className="flex items-start justify-between gap-3">
      <div>
        <div className="text-sm font-semibold text-slate-900">{label}</div>
        <div className="text-[11px] text-slate-500">{description}</div>
      </div>
      <button
        type="button"
        onClick={onChange}
        disabled={disabled}
        className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer items-center rounded-full border px-0.5 text-[10px] font-medium transition ${
          checked
            ? "border-emerald-500 bg-emerald-500 text-white"
            : "border-slate-300 bg-slate-100 text-slate-500"
        } disabled:cursor-not-allowed disabled:opacity-60`}
        aria-pressed={checked}
      >
        <span
          className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition ${
            checked ? "translate-x-3.5" : "translate-x-0"
          }`}
        />
      </button>
    </div>
  );
}


