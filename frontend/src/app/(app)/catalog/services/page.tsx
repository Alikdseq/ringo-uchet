"use client";

import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { CatalogApi } from "@/shared/api/catalogApi";
import type { ServiceItem } from "@/shared/types/catalog";
import { Card } from "@/shared/components/ui/Card";

export default function ServicesCatalogPage() {
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<ServiceItem | null>(null);
  const [isCreateMode, setIsCreateMode] = useState(false);
  const [editName, setEditName] = useState("");
  const [editUnit, setEditUnit] = useState("");
  const [editPrice, setEditPrice] = useState("");
  const [modalError, setModalError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  const { data, isLoading, isError, error, refetch } = useQuery<ServiceItem[]>({
    queryKey: ["catalog", "services", { search }],
    queryFn: () =>
      CatalogApi.getServices({
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
        : "Не удалось загрузить список услуг";
  }

  const openEdit = (service: ServiceItem) => {
    setEditing(service);
    setIsCreateMode(false);
    setEditName(service.name);
    setEditUnit(service.unit);
    setEditPrice(service.price != null ? service.price.toString() : "");
    setModalError(null);
  };

  const openCreate = () => {
    setEditing({
      id: 0,
      category: 0,
      categoryName: null,
      name: "",
      unit: "усл.",
      price: 0,
      defaultDuration: null,
      includedItems: [],
      isActive: true,
    });
    setIsCreateMode(true);
    setEditName("");
    setEditUnit("");
    setEditPrice("");
    setModalError(null);
  };

  const handleSave = async () => {
    if (!editing) return;

    if (!editName.trim()) {
      setModalError("Название услуги обязательно для заполнения.");
      return;
    }

    const price = Number(editPrice.replace(",", "."));
    if (!Number.isFinite(price) || price < 0) {
      setModalError("Укажите корректную цену услуги.");
      return;
    }

    setIsSaving(true);
    setModalError(null);
    try {
      if (isCreateMode) {
        await CatalogApi.createService({
          name: editName.trim(),
          unit: editUnit || editing.unit,
          price,
        });
      } else {
        await CatalogApi.updateService(editing.id, {
          name: editName.trim(),
          unit: editUnit || editing.unit,
          price,
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

  const handleDelete = async (service: ServiceItem) => {
    const confirmed = window.confirm(
      `Удалить услугу "${service.name}"? Действие необратимо.`,
    );
    if (!confirmed) return;

    try {
      await CatalogApi.deleteService(service.id);
      await refetch();
    } catch (e) {
      const message =
        e instanceof Error ? e.message : "Не удалось удалить услугу";
      // eslint-disable-next-line no-alert
      alert(message);
    }
  };

  return (
    <div className="space-y-3">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs sm:flex-1">
          <input
            type="text"
            placeholder="Поиск по названию/категории"
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

      {errorMessage ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {errorMessage}
        </div>
      ) : null}

      {isLoading && !items.length ? (
        <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
          Загружаем услуги...
        </div>
      ) : null}

      {!isLoading && items.length === 0 ? (
        <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
          Услуги не найдены.
        </div>
      ) : null}

      <div className="space-y-2">
        {items.map((service) => (
          <Card
            key={service.id}
            className="flex items-center justify-between rounded-xl px-3 py-2 text-xs"
          >
            <div className="space-y-0.5">
              <div className="text-sm font-semibold text-slate-900">
                {service.name}
              </div>
              <div className="text-[11px] text-slate-500">
                {service.categoryName ?? `Категория #${service.category}`}
              </div>
              <div className="text-[11px] text-slate-500">
                {service.unit} ·{" "}
                {new Intl.NumberFormat("ru-RU", {
                  style: "currency",
                  currency: "RUB",
                  maximumFractionDigits: 0,
                }).format(service.price)}
              </div>
            </div>
            <div className="flex gap-2 text-lg text-slate-400">
              <button
                type="button"
                aria-label="Редактировать"
                onClick={() => openEdit(service)}
              >
                ✏️
              </button>
              <button
                type="button"
                aria-label="Удалить"
                onClick={() => handleDelete(service)}
              >
                🗑
              </button>
            </div>
          </Card>
        ))}
      </div>

      {editing ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-3">
          <div className="w-full max-w-md rounded-lg bg-white p-4 text-xs shadow-lg">
            <h2 className="mb-3 text-sm font-semibold text-slate-900">
              {isCreateMode ? "Добавить услугу" : "Редактировать услугу"}
            </h2>
            <div className="space-y-3">
              <div className="space-y-1.5">
                <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                  Название услуги *
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
                  Цена услуги (₽) *
                </label>
                <input
                  type="number"
                  min={0}
                  value={editPrice}
                  onChange={(event) => setEditPrice(event.target.value)}
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                />
              </div>
              <div className="space-y-1.5">
                <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                  Единица измерения
                </label>
                <input
                  type="text"
                  value={editUnit}
                  onChange={(event) => setEditUnit(event.target.value)}
                  placeholder={editing.unit}
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                />
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
                  disabled={isSaving}
                  className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-[11px] font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
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

