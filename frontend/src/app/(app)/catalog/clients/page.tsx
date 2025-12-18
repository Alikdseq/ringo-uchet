"use client";

import React, { FormEvent, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { CatalogApi } from "@/shared/api/catalogApi";
import type { ClientInfo } from "@/shared/types/orders";
import { httpClient } from "@/shared/api/httpClient";
import { Card } from "@/shared/components/ui/Card";

export default function ClientsCatalogPage() {
  const [search, setSearch] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | null>(null);

  const [editingId, setEditingId] = useState<number | null>(null);
  const [editName, setEditName] = useState("");
  const [editPhone, setEditPhone] = useState("");
  const [editEmail, setEditEmail] = useState("");
  const [editAddress, setEditAddress] = useState("");
  const [editError, setEditError] = useState<string | null>(null);
  const [isSavingEdit, setIsSavingEdit] = useState(false);
  const [clientToDelete, setClientToDelete] = useState<ClientInfo | null>(null);

  const { data, isLoading, isError, error: queryError, refetch } = useQuery<
    ClientInfo[]
  >({
    queryKey: ["catalog", "clients", { search }],
    queryFn: () =>
      CatalogApi.getClients({
        search: search || undefined,
      }),
    staleTime: 5 * 60_000,
    refetchOnWindowFocus: false,
  });

  const items = data ?? [];

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      queryError instanceof Error
        ? queryError.message
        : "Не удалось загрузить список клиентов";
  }

  const startEditClient = (client: ClientInfo) => {
    setEditingId(client.id);
    setEditName(client.name);
    setEditPhone(client.phone);
    setEditEmail(client.email ?? "");
    setEditAddress(client.address ?? "");
    setEditError(null);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setEditPhone("");
    setEditEmail("");
    setEditAddress("");
    setEditError(null);
  };

  const handleSaveEdit = async () => {
    if (editingId == null) return;
    if (!editName.trim() || !editPhone.trim()) {
      setEditError("Имя и телефон обязательны");
      return;
    }

    setIsSavingEdit(true);
    setEditError(null);

    try {
      await CatalogApi.updateClient(editingId, {
        name: editName.trim(),
        phone: editPhone.trim(),
        // Для email и адреса backend ожидает пустую строку,
        // а не null, поэтому просто передаём строку (включая пустую).
        email: editEmail.trim(),
        address: editAddress.trim(),
      });
      cancelEdit();
      await refetch();
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось обновить клиента, попробуйте позже";
      setEditError(message);
    } finally {
      setIsSavingEdit(false);
    }
  };

  const requestDeleteClient = (client: ClientInfo) => {
    setClientToDelete(client);
    setError(null);
  };

  const handleConfirmDeleteClient = async () => {
    if (!clientToDelete) return;

    setDeletingId(clientToDelete.id);

    try {
      await CatalogApi.deleteClient(clientToDelete.id);
      if (editingId === clientToDelete.id) {
        cancelEdit();
      }
      setClientToDelete(null);
      await refetch();
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось удалить клиента, попробуйте позже";
      setError(message);
    } finally {
      setDeletingId(null);
    }
  };

  const handleCancelDeleteClient = () => {
    setClientToDelete(null);
  };

  const handleCreateClient = async (event: FormEvent) => {
    event.preventDefault();
    if (!name || !phone) {
      setError("Имя и телефон обязательны");
      return;
    }
    setError(null);
    setIsCreating(true);
    try {
      await httpClient.post("/clients/", {
        name,
        phone,
        email: email || undefined,
      });
      setName("");
      setPhone("");
      setEmail("");
      await refetch();
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось создать клиента, попробуйте позже";
      setError(message);
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs">
        <input
          type="text"
          placeholder="Поиск по имени/телефону"
          className="h-7 w-full border-none bg-transparent text-xs text-slate-900 placeholder:text-slate-400 focus:outline-none"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
      </div>

      {errorMessage ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {errorMessage}
        </div>
      ) : null}

      {isLoading && !items.length ? (
        <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
          Загружаем клиентов...
        </div>
      ) : null}

      {!isLoading && items.length === 0 ? (
        <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
          Клиенты не найдены.
        </div>
      ) : null}

      <div className="space-y-2">
        {items.map((client) => {
          const isEditing = editingId === client.id;

          return (
            <Card
              key={client.id}
              className="rounded-xl px-3 py-2 text-xs"
            >
              <div className="flex items-start justify-between gap-2">
                <div className="flex-1 space-y-0.5">
                  {isEditing ? (
                    <>
                      <div className="space-y-1.5">
                        <input
                          type="text"
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                          value={editName}
                          onChange={(event) => setEditName(event.target.value)}
                          placeholder="Имя клиента"
                        />
                        <input
                          type="tel"
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                          value={editPhone}
                          onChange={(event) => setEditPhone(event.target.value)}
                          placeholder="Телефон"
                        />
                        <input
                          type="email"
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                          value={editEmail}
                          onChange={(event) => setEditEmail(event.target.value)}
                          placeholder="Email (опционально)"
                        />
                        <textarea
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                          rows={2}
                          value={editAddress}
                          onChange={(event) =>
                            setEditAddress(event.target.value)
                          }
                          placeholder="Адрес (опционально)"
                        />
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="text-sm font-semibold text-slate-900">
                        {client.name}
                      </div>
                      <div className="text-[11px] text-slate-500">
                        {client.phone}
                        {client.email ? ` · ${client.email}` : ""}
                      </div>
                      {client.address ? (
                        <div className="text-[11px] text-slate-500">
                          {client.address}
                        </div>
                      ) : null}
                    </>
                  )}
                </div>
                <div className="flex gap-2 text-lg text-slate-400">
                  {isEditing ? (
                    <>
                      <button
                        type="button"
                        aria-label="Сохранить"
                        onClick={() => void handleSaveEdit()}
                        disabled={isSavingEdit}
                        className="text-green-600 disabled:opacity-60"
                      >
                        ✔
                      </button>
                      <button
                        type="button"
                        aria-label="Отменить"
                        onClick={cancelEdit}
                        className="text-slate-400"
                      >
                        ✕
                      </button>
                    </>
                  ) : (
                    <>
                      <button
                        type="button"
                        aria-label="Редактировать"
                        onClick={() => startEditClient(client)}
                      >
                        ✏️
                      </button>
                      <button
                        type="button"
                        aria-label="Удалить"
                        onClick={() => requestDeleteClient(client)}
                        disabled={deletingId === client.id}
                        className={
                          deletingId === client.id
                            ? "opacity-60"
                            : "hover:text-red-600"
                        }
                      >
                        🗑
                      </button>
                    </>
                  )}
                </div>
              </div>

              {isEditing && editError ? (
                <div className="mt-2 rounded-md border border-red-200 bg-red-50 px-3 py-1.5 text-[11px] text-red-700">
                  {editError}
                </div>
              ) : null}
            </Card>
          );
        })}
      </div>

      {clientToDelete ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-3">
          <div className="w-full max-w-sm rounded-lg bg-white p-4 text-xs shadow-lg">
            <div className="mb-2 text-sm font-semibold text-slate-900">
              Удалить клиента?
            </div>
            <div className="text-[11px] text-slate-600">
              Клиент{" "}
              <span className="font-semibold">{clientToDelete.name}</span> будет
              удалён из справочника. Заявки, которые уже привязаны к нему,{" "}
              <span className="font-semibold">останутся в истории</span> с этим
              именем.
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button
                type="button"
                onClick={handleCancelDeleteClient}
                className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-[11px] font-medium text-slate-700 shadow-sm hover:bg-slate-50"
              >
                Отмена
              </button>
              <button
                type="button"
                onClick={() => void handleConfirmDeleteClient()}
                disabled={deletingId === clientToDelete.id}
                className="inline-flex items-center rounded-md bg-rose-500 px-3 py-1.5 text-[11px] font-medium text-white shadow-sm hover:bg-rose-600 disabled:cursor-not-allowed disabled:opacity-60"
              >
                Удалить
              </button>
            </div>
          </div>
        </div>
      ) : null}

      <form
        onSubmit={handleCreateClient}
        className="space-y-3 rounded-xl border border-slate-200 bg-white p-3 text-xs"
      >
        <div className="text-sm font-semibold text-slate-900">
          Создать нового клиента
        </div>
        <div className="grid gap-3 md:grid-cols-3">
          <div className="space-y-1.5">
            <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-500">
              Имя
            </label>
            <input
              type="text"
              className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              value={name}
              onChange={(event) => setName(event.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-500">
              Телефон
            </label>
            <input
              type="tel"
              className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              value={phone}
              onChange={(event) => setPhone(event.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-500">
              Email (опционально)
            </label>
            <input
              type="email"
              className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
          </div>
        </div>

        {error ? (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
            {error}
          </div>
        ) : null}

        <button
          type="submit"
          disabled={isCreating}
          className="inline-flex items-center rounded-md bg-sky-500 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-sky-600 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {isCreating ? "Создаём..." : "Создать клиента"}
        </button>
      </form>
    </div>
  );
}

