"use client";

import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { CatalogApi } from "@/shared/api/catalogApi";
import type {
  Attachment,
  Equipment,
  EquipmentStatus,
} from "@/shared/types/catalog";
import { Card } from "@/shared/components/ui/Card";

export default function AttachmentsCatalogPage() {
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<Attachment | null>(null);
  const [isCreateMode, setIsCreateMode] = useState(false);
  const [editEquipmentId, setEditEquipmentId] = useState<string>("");
  const [editName, setEditName] = useState("");
  const [editPrice, setEditPrice] = useState("");
  const [editStatus, setEditStatus] = useState<EquipmentStatus>("available");
  const [modalError, setModalError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [attachmentToDelete, setAttachmentToDelete] =
    useState<Attachment | null>(null);
  const [deletingId, setDeletingId] = useState<number | null>(null);

  const { data: attachments, isLoading, isError, error, refetch } =
    useQuery<Attachment[]>({
      queryKey: ["catalog", "attachments", { search }],
      queryFn: () =>
        CatalogApi.getAttachments({
          search: search || undefined,
        }),
      staleTime: 5 * 60_000,
      refetchOnWindowFocus: false,
    });

  const { data: equipmentList } = useQuery<Equipment[]>({
    queryKey: ["catalog", "equipment", "all"],
    queryFn: () => CatalogApi.getEquipment({ pageSize: 1000 }),
    staleTime: 10 * 60_000,
  });

  const items = attachments ?? [];
  const equipment = equipmentList ?? [];

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      error instanceof Error
        ? error.message
        : "Не удалось загрузить список навесок";
  }

  const openEdit = (att: Attachment) => {
    setEditing(att);
    setIsCreateMode(false);
    setEditEquipmentId(att.equipment.toString());
    setEditName(att.name);
    setEditPrice(att.price.toString());
    setEditStatus(att.status);
    setModalError(null);
  };

  const openCreate = () => {
    setEditing({
      id: 0,
      equipment: 0,
      name: "",
      price: 0,
      status: "available",
      metadata: {},
    } as Attachment);
    setIsCreateMode(true);
    setEditEquipmentId("");
    setEditName("");
    setEditPrice("0");
    setEditStatus("available");
    setModalError(null);
  };

  const handleSave = async () => {
    if (!editing) return;
    if (!editEquipmentId || !editName.trim()) {
      setModalError("Техника и название обязательны для заполнения.");
      return;
    }

    const equipmentId = Number(editEquipmentId);
    if (!Number.isFinite(equipmentId) || equipmentId <= 0) {
      setModalError("Выберите корректную технику.");
      return;
    }

    const price = Number(editPrice.replace(",", "."));
    if (!Number.isFinite(price) || price < 0) {
      setModalError("Укажите корректную цену (неотрицательное число).");
      return;
    }

    setIsSaving(true);
    setModalError(null);
    try {
      if (isCreateMode) {
        await CatalogApi.createAttachment({
          equipment: equipmentId,
          name: editName.trim(),
          price: price,
          status: editStatus,
        });
      } else {
        await CatalogApi.updateAttachment(editing.id, {
          equipment: equipmentId,
          name: editName.trim(),
          price: price,
          status: editStatus,
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

  const requestDelete = (att: Attachment) => {
    setAttachmentToDelete(att);
  };

  const handleConfirmDelete = async () => {
    if (!attachmentToDelete) return;

    setDeletingId(attachmentToDelete.id);

    try {
      await CatalogApi.deleteAttachment(attachmentToDelete.id);
      setAttachmentToDelete(null);
      await refetch();
    } catch (e) {
      const message =
        e instanceof Error ? e.message : "Не удалось удалить навеску";
      setModalError(message);
    } finally {
      setDeletingId(null);
    }
  };

  const handleCancelDelete = () => {
    setAttachmentToDelete(null);
  };

  const getStatusLabel = (status: EquipmentStatus): string => {
    const labels: Record<EquipmentStatus, string> = {
      available: "Доступна",
      busy: "Занята",
      maintenance: "На обслуживании",
      inactive: "Неактивна",
    };
    return labels[status] ?? status;
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
          Загружаем список навесок...
        </div>
      ) : null}

      {!isLoading && items.length === 0 ? (
        <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
          Навески не найдены.
        </div>
      ) : null}

      <div className="space-y-2">
        {items.map((att) => (
          <Card
            key={att.id}
            className="flex items-center justify-between rounded-xl px-3 py-2 text-xs"
          >
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-100 text-lg text-slate-600">
                🔧
              </div>
              <div className="space-y-0.5">
                <div className="text-sm font-semibold text-slate-900">
                  {att.name}
                </div>
                <div className="text-[11px] text-slate-500">
                  {att.equipmentCode
                    ? `${att.equipmentCode} — ${att.equipmentName ?? ""}`
                    : `Техника #${att.equipment}`}
                </div>
                <div className="text-[11px] text-slate-500">
                  Цена: {att.price.toFixed(0)} ₽ · Статус:{" "}
                  {getStatusLabel(att.status)}
                </div>
              </div>
            </div>
            <div className="flex flex-col items-end gap-1">
              <div className="flex gap-2 text-lg text-slate-400">
                <button
                  type="button"
                  aria-label="Редактировать"
                  onClick={() => openEdit(att)}
                >
                  ✏️
                </button>
                <button
                  type="button"
                  aria-label="Удалить"
                  onClick={() => requestDelete(att)}
                  disabled={deletingId === att.id}
                  className={
                    deletingId === att.id
                      ? "opacity-60"
                      : "hover:text-red-600"
                  }
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
              {isCreateMode ? "Добавить навеску" : "Редактировать навеску"}
            </h2>
            <div className="space-y-3">
              <div className="space-y-1.5">
                <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                  Техника *
                </label>
                <select
                  value={editEquipmentId}
                  onChange={(event) => setEditEquipmentId(event.target.value)}
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                >
                  <option value="">Выберите технику</option>
                  {equipment.map((eq) => (
                    <option key={eq.id} value={eq.id}>
                      {eq.code} — {eq.name}
                    </option>
                  ))}
                </select>
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
              <div className="grid gap-3 md:grid-cols-2">
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Цена (₽)
                  </label>
                  <input
                    type="number"
                    min={0}
                    step="0.01"
                    value={editPrice}
                    onChange={(event) =>
                      setEditPrice(event.target.value)
                    }
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                    placeholder="0"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Статус
                  </label>
                  <select
                    value={editStatus}
                    onChange={(event) =>
                      setEditStatus(event.target.value as EquipmentStatus)
                    }
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                  >
                    <option value="available">Доступна</option>
                    <option value="busy">Занята</option>
                    <option value="maintenance">На обслуживании</option>
                    <option value="inactive">Неактивна</option>
                  </select>
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

      {attachmentToDelete ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-3">
          <div className="w-full max-w-sm rounded-lg bg-white p-4 text-xs shadow-lg">
            <div className="mb-2 text-sm font-semibold text-slate-900">
              Удалить навеску?
            </div>
            <div className="text-[11px] text-slate-600">
              Навеска{" "}
              <span className="font-semibold">{attachmentToDelete.name}</span>{" "}
              будет удалена из справочника. Заявки, которые уже используют эту
              навеску, <span className="font-semibold">останутся в истории</span>{" "}
              с этой информацией.
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button
                type="button"
                onClick={handleCancelDelete}
                className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-[11px] font-medium text-slate-700 shadow-sm hover:bg-slate-50"
              >
                Отмена
              </button>
              <button
                type="button"
                onClick={() => void handleConfirmDelete()}
                disabled={deletingId === attachmentToDelete.id}
                className="inline-flex items-center rounded-md bg-rose-500 px-3 py-1.5 text-[11px] font-medium text-white shadow-sm hover:bg-rose-600 disabled:cursor-not-allowed disabled:opacity-60"
              >
                Удалить
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}

