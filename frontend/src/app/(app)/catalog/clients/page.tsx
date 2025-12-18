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
        {items.map((client) => (
          <Card
            key={client.id}
            className="flex items-center justify-between rounded-xl px-3 py-2 text-xs"
          >
            <div className="space-y-0.5">
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
            </div>
            <div className="flex gap-2 text-lg text-slate-400">
              <button type="button" aria-label="Редактировать">
                ✏️
              </button>
              <button type="button" aria-label="Удалить">
                🗑
              </button>
            </div>
          </Card>
        ))}
      </div>

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

