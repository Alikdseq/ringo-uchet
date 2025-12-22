"use client";

import React, { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AuthApi } from "@/shared/api/authApi";
import { useAuthStore } from "@/shared/store/authStore";

export default function RegisterPage() {
  const router = useRouter();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const isLoadingGlobal = useAuthStore((state) => state.isLoading);
  const login = useAuthStore((state) => state.login);

  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isAuthenticated) {
      router.replace("/");
    }
  }, [isAuthenticated, router]);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();

    const trimmedPhone = phone.trim();

    if (!firstName || !lastName || !trimmedPhone || !password || !confirmPassword) {
      setError("Заполните все поля формы");
      return;
    }

    if (password !== confirmPassword) {
      setError("Пароли не совпадают");
      return;
    }

    if (password.length < 6) {
      setError("Пароль должен содержать не менее 6 символов");
      return;
    }

    if (!/^\+?\d{5,}$/.test(trimmedPhone)) {
      setError("Введите корректный телефон в формате +79991234567");
      return;
    }

    setError(null);
    setIsSubmitting(true);

    try {
      await AuthApi.register({
        firstName,
        lastName,
        phone: trimmedPhone,
        password,
      });

      // silent-login как во Flutter: сразу входим по телефону и паролю
      await login({
        phone: trimmedPhone,
        password,
      });

      router.replace("/");
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Не удалось завершить регистрацию";
      setError(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const disabled = isSubmitting || isLoadingGlobal;

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4">
      <div className="w-full max-w-md rounded-lg border border-slate-200 bg-white p-8 shadow-sm">
        <h1 className="mb-2 text-center text-2xl font-semibold text-slate-900">
          Регистрация оператора
        </h1>
        <p className="mb-6 text-center text-sm text-slate-500">
          Укажите свои данные, чтобы получить доступ в систему.
        </p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <label
              htmlFor="firstName"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Имя
            </label>
            <input
              id="firstName"
              name="firstName"
              type="text"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Иван"
              value={firstName}
              onChange={(event) => setFirstName(event.target.value)}
              disabled={disabled}
            />
          </div>

          <div className="space-y-1.5">
            <label
              htmlFor="lastName"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Фамилия
            </label>
            <input
              id="lastName"
              name="lastName"
              type="text"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Петров"
              value={lastName}
              onChange={(event) => setLastName(event.target.value)}
              disabled={disabled}
            />
          </div>

          <div className="space-y-1.5">
            <label
              htmlFor="phone"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Телефон
            </label>
            <input
              id="phone"
              name="phone"
              type="tel"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="+79991234567"
              value={phone}
              onChange={(event) => setPhone(event.target.value)}
              disabled={disabled}
            />
          </div>

          <div className="space-y-1.5">
            <label
              htmlFor="password"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Пароль
            </label>
            <input
              id="password"
              name="password"
              type="password"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Минимум 6 символов"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              disabled={disabled}
            />
          </div>

          <div className="space-y-1.5">
            <label
              htmlFor="confirmPassword"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Подтверждение пароля
            </label>
            <input
              id="confirmPassword"
              name="confirmPassword"
              type="password"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Повторите пароль"
              value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)}
              disabled={disabled}
            />
          </div>

          {error ? (
            <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
              {error}
            </div>
          ) : null}

          <button
            type="submit"
            disabled={disabled}
            className="flex w-full items-center justify-center rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-400"
          >
            {disabled ? "Регистрируем..." : "Зарегистрироваться"}
          </button>
        </form>

        <div className="mt-6 border-t border-slate-200 pt-6 text-center">
          <p className="mb-3 text-xs text-slate-500">
            Уже есть аккаунт?
          </p>
          <Link
            href="/login"
            className="inline-flex items-center justify-center rounded-md border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50"
          >
            Войти
          </Link>
        </div>
      </div>
    </main>
  );
}

