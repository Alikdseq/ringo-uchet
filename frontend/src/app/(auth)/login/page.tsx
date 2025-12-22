"use client";

import React, { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/shared/store/authStore";
import type { LoginRequest } from "@/shared/types/auth";

export default function LoginPage() {
  const router = useRouter();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const isLoading = useAuthStore((state) => state.isLoading);
  const storeError = useAuthStore((state) => state.error);
  const login = useAuthStore((state) => state.login);

  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [formError, setFormError] = useState<string | null>(null);

  useEffect(() => {
    if (isAuthenticated) {
      router.replace("/");
    }
  }, [isAuthenticated, router]);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    const trimmedId = identifier.trim();

    if (!trimmedId || !password) {
      setFormError("Заполните телефон/email и пароль");
      return;
    }

    const payload: LoginRequest = {
      password,
    };

    if (/^\+?\d{5,}$/.test(trimmedId)) {
      payload.phone = trimmedId;
    } else if (trimmedId.includes("@")) {
      payload.email = trimmedId;
    } else {
      payload.username = trimmedId;
    }

    setFormError(null);

    try {
      await login(payload);
      router.replace("/");
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Не удалось выполнить вход";
      setFormError(message);
    }
  };

  const errorMessage = formError ?? storeError;

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-4">
      <div className="w-full max-w-md rounded-lg border border-slate-200 bg-white p-8 shadow-sm">
        <h1 className="mb-2 text-center text-2xl font-semibold text-slate-900">
          Вход в систему
        </h1>
        <p className="mb-6 text-center text-sm text-slate-500">
          Введите телефон или email и пароль для входа.
        </p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <label
              htmlFor="identifier"
              className="block text-xs font-medium uppercase tracking-wide text-slate-600"
            >
              Телефон или email
            </label>
            <input
              id="identifier"
              name="identifier"
              type="text"
              autoComplete="username"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="+79991234567 или user@example.com"
              value={identifier}
              onChange={(event) => setIdentifier(event.target.value)}
              disabled={isLoading}
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
              autoComplete="current-password"
              className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              placeholder="Введите пароль"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              disabled={isLoading}
            />
          </div>

          {errorMessage ? (
            <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
              {errorMessage}
            </div>
          ) : null}

          <button
            type="submit"
            disabled={isLoading}
            className="flex w-full items-center justify-center rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-400"
          >
            {isLoading ? "Входим..." : "Войти"}
          </button>
        </form>

        <div className="mt-6 border-t border-slate-200 pt-6 text-center">
          <p className="mb-3 text-xs text-slate-500">
            Нет аккаунта?
          </p>
          <Link
            href="/register"
            className="inline-flex items-center justify-center rounded-md border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm transition hover:bg-slate-50"
          >
            Зарегистрироваться
          </Link>
        </div>
      </div>
    </main>
  );
}

