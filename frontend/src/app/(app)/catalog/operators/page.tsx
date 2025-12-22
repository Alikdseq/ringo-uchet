"use client";

import React, { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { UsersApi } from "@/shared/api/usersApi";
import type { UserInfo } from "@/shared/types/auth";
import { Card } from "@/shared/components/ui/Card";
import { RoleGuard } from "@/shared/components/auth/RoleGuard";

export default function OperatorsCatalogPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  const [editingId, setEditingId] = useState<number | null>(null);
  const [editFirstName, setEditFirstName] = useState("");
  const [editLastName, setEditLastName] = useState("");
  const [editPhone, setEditPhone] = useState("");
  const [editEmail, setEditEmail] = useState("");
  const [editPassword, setEditPassword] = useState("");
  const [editError, setEditError] = useState<string | null>(null);
  const [isSavingEdit, setIsSavingEdit] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [operatorToDelete, setOperatorToDelete] = useState<UserInfo | null>(
    null,
  );

  const { data, isLoading, isError, error: queryError, refetch } = useQuery<
    UserInfo[]
  >({
    queryKey: ["catalog", "operators", { search }],
    queryFn: () =>
      UsersApi.getUsers({
        role: "operator",
        search: search || undefined,
      }),
    // Автоматическое обновление каждые 5 секунд для real-time синхронизации
    refetchInterval: 5000,
    // Данные считаются свежими 3 секунды
    staleTime: 3000,
    refetchOnWindowFocus: true,
    // Используем предыдущие данные во время обновления (без мерцаний)
    placeholderData: (previousData: UserInfo[] | undefined) => previousData,
    // Не показываем loading при background refetch
    notifyOnChangeProps: ["data", "error"],
  });

  const items = data ?? [];

  let errorMessage: string | null = null;
  if (isError) {
    errorMessage =
      queryError instanceof Error
        ? queryError.message
        : "Не удалось загрузить список операторов";
  }

  const startEditOperator = (operator: UserInfo) => {
    setEditingId(operator.id);
    setEditFirstName(operator.firstName ?? "");
    setEditLastName(operator.lastName ?? "");
    setEditPhone(operator.phone ?? "");
    setEditEmail(operator.email ?? "");
    setEditPassword("");
    setEditError(null);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditFirstName("");
    setEditLastName("");
    setEditPhone("");
    setEditEmail("");
    setEditPassword("");
    setEditError(null);
  };

  const handleSaveEdit = async () => {
    if (editingId == null) return;
    if (!editFirstName.trim() || !editLastName.trim() || !editPhone.trim()) {
      setEditError("Имя, фамилия и телефон обязательны");
      return;
    }

    setIsSavingEdit(true);
    setEditError(null);

    try {
      const payload: {
        first_name: string;
        last_name: string;
        phone: string;
        email: string;
        password?: string;
      } = {
        first_name: editFirstName.trim(),
        last_name: editLastName.trim(),
        phone: editPhone.trim(),
        email: editEmail.trim() || "",
      };

      if (editPassword.trim()) {
        payload.password = editPassword.trim();
      }

      await UsersApi.updateUser(editingId, payload);
      cancelEdit();
      // Инвалидируем все запросы операторов для мгновенного обновления
      void queryClient.invalidateQueries({ queryKey: ["catalog", "operators"] });
      void queryClient.invalidateQueries({ queryKey: ["users"] });
      await refetch();
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось обновить оператора, попробуйте позже";
      setEditError(message);
    } finally {
      setIsSavingEdit(false);
    }
  };

  const requestDeleteOperator = (operator: UserInfo) => {
    setOperatorToDelete(operator);
    setError(null);
  };

  const handleConfirmDeleteOperator = async () => {
    if (!operatorToDelete) return;

    setDeletingId(operatorToDelete.id);
    try {
      await UsersApi.deleteUser(operatorToDelete.id);
      if (editingId === operatorToDelete.id) {
        cancelEdit();
      }
      setOperatorToDelete(null);
      // Инвалидируем все запросы операторов для мгновенного обновления
      void queryClient.invalidateQueries({ queryKey: ["catalog", "operators"] });
      void queryClient.invalidateQueries({ queryKey: ["users"] });
      await refetch();
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось удалить оператора, попробуйте позже";
      setError(message);
    } finally {
      setDeletingId(null);
    }
  };

  const handleCancelDeleteOperator = () => {
    setOperatorToDelete(null);
  };

  const handleCreate = async () => {
    if (!firstName.trim() || !lastName.trim() || !phone.trim() || !password.trim()) {
      setError("Заполните все обязательные поля");
      return;
    }

    if (password.length < 6) {
      setError("Пароль должен содержать не менее 6 символов");
      return;
    }

    setError(null);

    try {
      await UsersApi.createUser({
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        phone: phone.trim(),
        password: password.trim(),
        email: email.trim() || undefined,
        role: "operator",
        username: phone.trim(),
      });
      setIsCreating(false);
      setFirstName("");
      setLastName("");
      setPhone("");
      setEmail("");
      setPassword("");
      // Инвалидируем все запросы операторов для мгновенного обновления
      void queryClient.invalidateQueries({ queryKey: ["catalog", "operators"] });
      void queryClient.invalidateQueries({ queryKey: ["users"] });
      await refetch();
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось создать оператора, попробуйте позже";
      setError(message);
    }
  };

  const getRoleLabel = (role: string): string => {
    const labels: Record<string, string> = {
      admin: "Администратор",
      manager: "Менеджер",
      operator: "Оператор",
      accountant: "Бухгалтер",
    };
    return labels[role] ?? role;
  };

  return (
    <RoleGuard allowedRoles={["admin"]}>
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
              onClick={() => setIsCreating(true)}
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

        {error ? (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
            {error}
          </div>
        ) : null}

        {isLoading && !items.length ? (
          <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
            Загружаем список операторов...
          </div>
        ) : null}

        {!isLoading && items.length === 0 ? (
          <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-4 text-xs text-slate-500">
            Операторы не найдены.
          </div>
        ) : null}

        <div className="space-y-2">
          {items.map((operator) => {
            const isEditing = editingId === operator.id;
            const isDeleting = deletingId === operator.id;

            if (isEditing) {
              return (
                <Card
                  key={operator.id}
                  className="rounded-xl border-sky-200 bg-sky-50 p-3 text-xs"
                >
                  <div className="space-y-3">
                    <div className="grid gap-3 md:grid-cols-2">
                      <div className="space-y-1.5">
                        <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                          Имя *
                        </label>
                        <input
                          type="text"
                          value={editFirstName}
                          onChange={(event) =>
                            setEditFirstName(event.target.value)
                          }
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                        />
                      </div>
                      <div className="space-y-1.5">
                        <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                          Фамилия *
                        </label>
                        <input
                          type="text"
                          value={editLastName}
                          onChange={(event) =>
                            setEditLastName(event.target.value)
                          }
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                        />
                      </div>
                      <div className="space-y-1.5">
                        <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                          Телефон *
                        </label>
                        <input
                          type="tel"
                          value={editPhone}
                          onChange={(event) => setEditPhone(event.target.value)}
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                        />
                      </div>
                      <div className="space-y-1.5">
                        <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                          Email
                        </label>
                        <input
                          type="email"
                          value={editEmail}
                          onChange={(event) => setEditEmail(event.target.value)}
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                        />
                      </div>
                      <div className="space-y-1.5">
                        <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                          Новый пароль (оставьте пустым, чтобы не менять)
                        </label>
                        <input
                          type="password"
                          value={editPassword}
                          onChange={(event) =>
                            setEditPassword(event.target.value)
                          }
                          className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                        />
                      </div>
                    </div>

                    {editError ? (
                      <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
                        {editError}
                      </div>
                    ) : null}

                    <div className="flex justify-end gap-2">
                      <button
                        type="button"
                        onClick={cancelEdit}
                        disabled={isSavingEdit}
                        className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-[11px] font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        ✕ Отмена
                      </button>
                      <button
                        type="button"
                        onClick={() => void handleSaveEdit()}
                        disabled={isSavingEdit}
                        className="inline-flex items-center rounded-md bg-sky-500 px-3 py-1.5 text-[11px] font-medium text-white shadow-sm hover:bg-sky-600 disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        ✔ Сохранить
                      </button>
                    </div>
                  </div>
                </Card>
              );
            }

            return (
              <Card
                key={operator.id}
                className="flex items-center justify-between rounded-xl px-3 py-2 text-xs"
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-full bg-slate-100 text-lg text-slate-600">
                    👤
                  </div>
                  <div className="space-y-0.5">
                    <div className="text-sm font-semibold text-slate-900">
                      {operator.firstName && operator.lastName
                        ? `${operator.firstName} ${operator.lastName}`
                        : operator.fullNameFromApi ||
                          operator.username ||
                          `Оператор #${operator.id}`}
                    </div>
                    <div className="text-[11px] text-slate-500">
                      {operator.phone ? `📞 ${operator.phone}` : ""}
                      {operator.email ? ` · ✉ ${operator.email}` : ""}
                    </div>
                    <div className="text-[11px] text-slate-500">
                      Роль: {getRoleLabel(operator.role)}
                    </div>
                  </div>
                </div>
                <div className="flex flex-col items-end gap-1">
                  <div className="flex gap-2 text-lg text-slate-400">
                    <button
                      type="button"
                      aria-label="Редактировать"
                      onClick={() => startEditOperator(operator)}
                    >
                      ✏️
                    </button>
                    <button
                      type="button"
                      aria-label="Удалить"
                      onClick={() => requestDeleteOperator(operator)}
                      disabled={isDeleting}
                      className={
                        isDeleting
                          ? "opacity-60"
                          : "hover:text-red-600"
                      }
                    >
                      🗑
                    </button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>

        {isCreating ? (
          <Card className="rounded-xl border-sky-200 bg-sky-50 p-3 text-xs">
            <div className="space-y-3">
              <div className="text-sm font-semibold text-slate-900">
                Добавить оператора
              </div>
              <div className="grid gap-3 md:grid-cols-2">
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Имя *
                  </label>
                  <input
                    type="text"
                    value={firstName}
                    onChange={(event) => setFirstName(event.target.value)}
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Фамилия *
                  </label>
                  <input
                    type="text"
                    value={lastName}
                    onChange={(event) => setLastName(event.target.value)}
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Телефон *
                  </label>
                  <input
                    type="tel"
                    value={phone}
                    onChange={(event) => setPhone(event.target.value)}
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                    placeholder="+79991234567"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Email
                  </label>
                  <input
                    type="email"
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                  />
                </div>
                <div className="space-y-1.5 md:col-span-2">
                  <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                    Пароль *
                  </label>
                  <input
                    type="password"
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                    placeholder="Минимум 6 символов"
                  />
                </div>
              </div>

              {error ? (
                <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
                  {error}
                </div>
              ) : null}

              <div className="flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setIsCreating(false);
                    setError(null);
                    setFirstName("");
                    setLastName("");
                    setPhone("");
                    setEmail("");
                    setPassword("");
                  }}
                  className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-[11px] font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                >
                  ✕ Отмена
                </button>
                <button
                  type="button"
                  onClick={() => void handleCreate()}
                  className="inline-flex items-center rounded-md bg-sky-500 px-3 py-1.5 text-[11px] font-medium text-white shadow-sm hover:bg-sky-600"
                >
                  ✔ Создать
                </button>
              </div>
            </div>
          </Card>
        ) : null}

        {operatorToDelete ? (
          <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-3">
            <div className="w-full max-w-sm rounded-lg bg-white p-4 text-xs shadow-lg">
              <div className="mb-2 text-sm font-semibold text-slate-900">
                Удалить оператора?
              </div>
              <div className="text-[11px] text-slate-600">
                Оператор{" "}
                <span className="font-semibold">
                  {operatorToDelete.firstName && operatorToDelete.lastName
                    ? `${operatorToDelete.firstName} ${operatorToDelete.lastName}`
                    : operatorToDelete.fullNameFromApi ||
                      operatorToDelete.username ||
                      `#${operatorToDelete.id}`}
                </span>{" "}
                будет удалён из системы. Заявки, которые уже привязаны к нему,{" "}
                <span className="font-semibold">останутся в истории</span> с этим
                именем.
              </div>
              <div className="mt-4 flex justify-end gap-2">
                <button
                  type="button"
                  onClick={handleCancelDeleteOperator}
                  className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-[11px] font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                >
                  Отмена
                </button>
                <button
                  type="button"
                  onClick={() => void handleConfirmDeleteOperator()}
                  disabled={deletingId === operatorToDelete.id}
                  className="inline-flex items-center rounded-md bg-rose-500 px-3 py-1.5 text-[11px] font-medium text-white shadow-sm hover:bg-rose-600 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  Удалить
                </button>
              </div>
            </div>
          </div>
        ) : null}
      </div>
    </RoleGuard>
  );
}

