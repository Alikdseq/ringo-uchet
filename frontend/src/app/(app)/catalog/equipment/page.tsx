"use client";

import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { CatalogApi } from "@/shared/api/catalogApi";
import type { Equipment, EquipmentStatus } from "@/shared/types/catalog";
import { Card } from "@/shared/components/ui/Card";

export default function EquipmentCatalogPage() {
  const [status] = useState<EquipmentStatus | "all">("all");
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<Equipment | null>(null);
  const [isCreateMode, setIsCreateMode] = useState(false);
  const [editCode, setEditCode] = useState("");
  const [editName, setEditName] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editHourlyRate, setEditHourlyRate] = useState("");
  const [editDailyRate, setEditDailyRate] = useState("");
  const [modalError, setModalError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  const { data, isLoading, isError, error, refetch } = useQuery<Equipment[]>({
    queryKey: ["catalog", "equipment", { status, search }],
    queryFn: () =>
      CatalogApi.getEquipment({
        status: status === "all" ? undefined : status,
        search: search || undefined,
        pageSize: 100,
      }),
    staleTime: 5 * 60_000,
    refetchOnWindowFocus: false,
  });

  const items = data ?? [];

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      error instanceof Error
        ? error.message
        : "Не удалось загрузить список техники";
  }

  const openEdit = (eq: Equipment) => {
    setEditing(eq);
    setIsCreateMode(false);
    setEditCode(eq.code);
    setEditName(eq.name);
    setEditDescription(eq.description);
    setEditHourlyRate(eq.hourlyRate.toString());
    setEditDailyRate(eq.dailyRate != null ? eq.dailyRate.toString() : "");
    setModalError(null);
  };

  const openCreate = () => {
    setEditing({
      id: 0,
      code: "",
      name: "",
      description: "",
      hourlyRate: 0,
      dailyRate: null,
      fuelConsumption: null,
      status: "available",
      photos: [],
      attributes: {},
    } as Equipment);
    setIsCreateMode(true);
    setEditCode("");
    setEditName("");
    setEditDescription("");
    setEditHourlyRate("");
    setEditDailyRate("");
    setModalError(null);
  };

  const handleSave = async () => {
    if (!editing) return;
    if (!editCode.trim() || !editName.trim()) {
      setModalError("Код и название обязательны для заполнения.");
      return;
    }

    const hourly = Number(editHourlyRate.replace(",", "."));
    const daily = editDailyRate
      ? Number(editDailyRate.replace(",", "."))
      : null;

    if (!Number.isFinite(hourly) || hourly <= 0) {
      setModalError("Укажите корректную почасовую ставку.");
      return;
    }

    setIsSaving(true);
    setModalError(null);
    try {
      if (isCreateMode) {
        await CatalogApi.createEquipment({
          code: editCode.trim(),
          name: editName.trim(),
          description: editDescription,
          hourly_rate: hourly,
          daily_rate: daily ?? undefined,
        });
      } else {
        await CatalogApi.updateEquipment(editing.id, {
          code: editCode.trim(),
          name: editName.trim(),
          description: editDescription,
          hourly_rate: hourly,
          daily_rate: daily,
        });
      }
      await refetch();
      setEditing(null);
      setIsCreateMode(false);
    } catch (e) {
      const message =
        e instanceof Error ? e.message : "Не удалось сохранить изменения";
      setModalError(message);
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (eq: Equipment) => {
    const confirmed = window.confirm(
      `Удалить технику "${eq.name}" (${eq.code})? Действие необратимо.`,
    );
    if (!confirmed) return;

    try {
      await CatalogApi.deleteEquipment(eq.id);
      await refetch();
    } catch (e) {
      // Бросать наверх не будем, просто покажем alert, чтобы не ломать список
      const message =
        e instanceof Error ? e.message : "Не удалось удалить технику";
      // eslint-disable-next-line no-alert
      alert(message);
    }
  };

  return (
    <div className="space-y-3">
      <div className="flex flex-col gap-2">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs sm:flex-1">
            <input
              type="text"
              placeholder="Поиск..."
              className="h-7 w-full border-none bg-transparent text-xs text-slate-900 placeholder:text-slate-400 focus:outline-none"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </div>
          <button
            type="button"
            onClick={openCreate}
            className="inline-flex items-center justify-center rounded-md bg-sky-500 px-3 py-1.5 text-[11px] font-medium text-white shadow-sm hover:bg-sky-600 sm:ml-2"
          >
            <span className="mr-1 text-sm">＋</span>
            <span>Добавить</span>
          </button>
        </div>
      </div>

      {errorMessage ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {errorMessage}
        </div>
      ) : null}

      {isLoading && !items.length ? (
        <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
          Загружаем список техники...
        </div>
      ) : null}

      {!isLoading && items.length === 0 ? (
        <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
          Техника не найдена.
        </div>
      ) : null}

      <div className="space-y-2">
        {items.map((eq) => (
          <Card
            key={eq.id}
            className="flex items-center justify-between rounded-xl px-3 py-2 text-xs"
          >
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-100 text-lg text-slate-600">
                🛠
              </div>
              <div className="space-y-0.5">
                <div className="text-[11px] uppercase text-slate-400">
                  {eq.code}
                </div>
                <div className="text-sm font-semibold text-slate-900">
                  {eq.name}
                </div>
                <div className="text-[11px] text-slate-500">
                  {eq.hourlyRate.toFixed(0)} ₽ ·{" "}
                  {eq.dailyRate != null
                    ? `${eq.dailyRate.toFixed(0)} ₽/смена`
                    : "почасовая ставка"}
                </div>
              </div>
            </div>
            <div className="flex flex-col items-end gap-1">
              <div className="flex gap-2 text-lg text-slate-400">
                <button
                  type="button"
                  aria-label="Редактировать"
                  onClick={() => openEdit(eq)}
                >
                  ✏️
                </button>
                <button
                  type="button"
                  aria-label="Удалить"
                  onClick={() => handleDelete(eq)}
                >
                  🗑
                </button>
              </div>
            </div>
          </Card>
        ))}
      </div>

      {editing ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-3">
          <div className="w-full max-w-lg rounded-lg bg-white p-4 text-xs shadow-lg">
            <h2 className="mb-3 text-sm font-semibold text-slate-900">
              {isCreateMode ? "Добавить технику" : "Редактировать технику"}
            </h2>
            <div className="space-y-3">
              <div className="space-y-1.5">
                <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                  Код *
                </label>
                <input
                  type="text"
                  value={editCode}
                  onChange={(event) => setEditCode(event.target.value)}
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                />
              </div>
              <div className="space-y-1.5">
                <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                  Название *
                </label>
                <input
                  type="text"
                  value={editName}
                  onChange={(event) => setEditName(event.target.value)}
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                />
              </div>
              <div className="space-y-1.5">
                <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                  Описание
                </label>
                <textarea
                  rows={3}
                  value={editDescription}
                  onChange={(event) => setEditDescription(event.target.value)}
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                />
              </div>
              <div className="grid gap-3 md:grid-cols-2">
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Почасовая ставка (₽) *
                  </label>
                  <input
                    type="number"
                    min={0}
                    value={editHourlyRate}
                    onChange={(event) =>
                      setEditHourlyRate(event.target.value)
                    }
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Дневная ставка (₽)
                  </label>
                  <input
                    type="number"
                    min={0}
                    value={editDailyRate}
                    onChange={(event) =>
                      setEditDailyRate(event.target.value)
                    }
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                  />
                </div>
              </div>

              {modalError ? (
                <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-[11px] text-red-700">
                  {modalError}
                </div>
              ) : null}

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEditing(null)}
                  className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-[11px] font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                  disabled={isSaving}
                >
                  Отмена
                </button>
                <button
                  type="button"
                  onClick={handleSave}
                  disabled={isSaving}
                  className="rounded-md bg-sky-500 px-3 py-1.5 text-[11px] font-medium text-white shadow-sm hover:bg-sky-600 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isSaving ? "Сохраняем..." : "Сохранить"}
                </button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}

