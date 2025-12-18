"use client";

import React, { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { AuthApi } from "@/shared/api/authApi";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import { Card } from "@/shared/components/ui/Card";

export default function ChangePasswordPage() {
  const router = useRouter();

  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!oldPassword || !newPassword || !confirmPassword) {
      setError("Заполните все поля");
      setSuccess(null);
      return;
    }

    if (newPassword.length < 8) {
      setError("Новый пароль должен содержать минимум 8 символов");
      setSuccess(null);
      return;
    }

    if (newPassword !== confirmPassword) {
      setError("Пароли не совпадают");
      setSuccess(null);
      return;
    }

    setError(null);
    setIsSubmitting(true);

    try {
      await AuthApi.changePassword({
        oldPassword,
        newPassword,
        confirmPassword,
      });

      setSuccess("Пароль успешно изменён");
      setOldPassword("");
      setNewPassword("");
      setConfirmPassword("");
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Не удалось изменить пароль";
      setError(message);
      setSuccess(null);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section className="space-y-4">
      <PageHeader title="Смена пароля" subtitle="Обновите пароль для входа в систему." />

      <Card className="p-4">
        <form onSubmit={handleSubmit} className="space-y-4 text-sm">
          <div className="space-y-1.5">
            <label
              htmlFor="oldPassword"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Текущий пароль
            </label>
            <input
              id="oldPassword"
              name="oldPassword"
              type="password"
              autoComplete="current-password"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Введите текущий пароль"
              value={oldPassword}
              onChange={(event) => setOldPassword(event.target.value)}
              disabled={isSubmitting}
            />
          </div>

          <div className="space-y-1.5">
            <label
              htmlFor="newPassword"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Новый пароль
            </label>
            <input
              id="newPassword"
              name="newPassword"
              type="password"
              autoComplete="new-password"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Минимум 8 символов"
              value={newPassword}
              onChange={(event) => setNewPassword(event.target.value)}
              disabled={isSubmitting}
            />
          </div>

          <div className="space-y-1.5">
            <label
              htmlFor="confirmPassword"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Подтверждение нового пароля
            </label>
            <input
              id="confirmPassword"
              name="confirmPassword"
              type="password"
              autoComplete="new-password"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Повторите новый пароль"
              value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)}
              disabled={isSubmitting}
            />
          </div>

          {error ? (
            <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
              {error}
            </div>
          ) : null}

          {success ? (
            <div className="rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-xs text-emerald-700">
              {success}
            </div>
          ) : null}

          <div className="flex items-center gap-2">
            <button
              type="submit"
              disabled={isSubmitting}
              className="inline-flex items-center justify-center rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-400"
            >
              {isSubmitting ? "Сохраняем..." : "Сохранить"}
            </button>
            <button
              type="button"
              onClick={() => router.back()}
              disabled={isSubmitting}
              className="inline-flex items-center justify-center rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
            >
              Отмена
            </button>
          </div>
        </form>
      </Card>
    </section>
  );
}


