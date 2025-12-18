import axios, {
  AxiosError,
  AxiosInstance,
  AxiosRequestConfig,
  InternalAxiosRequestConfig,
} from "axios";
import type { ApiErrorBody } from "./types";
import { useAuthStore } from "@/shared/store/authStore";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://ringoouchet.ru/api/v1";

const DEFAULT_TIMEOUT_MS = 25_000;

export class AppError extends Error {
  status?: number;
  code?: string;
  details?: unknown;
  isNetworkError: boolean;
  isTimeout: boolean;

  constructor(message: string, options?: Partial<AppError>) {
    super(message);
    this.name = "AppError";
    this.status = options?.status;
    this.code = options?.code;
    this.details = options?.details;
    this.isNetworkError = options?.isNetworkError ?? false;
    this.isTimeout = options?.isTimeout ?? false;
  }
}

function mapAxiosError(error: AxiosError<ApiErrorBody>): AppError {
  if (error.code === "ECONNABORTED") {
    return new AppError("Превышено время ожидания запроса", {
      isTimeout: true,
      isNetworkError: false,
    });
  }

  if (error.message === "Network Error" && !error.response) {
    return new AppError("Проблема с сетью или сервер недоступен", {
      isNetworkError: true,
    });
  }

  const status = error.response?.status;
  const data = error.response?.data;

  const base: Partial<AppError> = {
    status,
    details: data,
  };

  if (!status) {
    return new AppError("Неизвестная ошибка сети", {
      ...base,
      isNetworkError: true,
    });
  }

  const detail =
    data?.detail ??
    (Array.isArray(data?.non_field_errors)
      ? data?.non_field_errors.join(" ")
      : undefined);

  let message = detail ?? "Ошибка при запросе к серверу";

  switch (status) {
    case 400:
      message = detail ?? "Неверные данные запроса";
      break;
    case 401:
      message = detail ?? "Требуется авторизация";
      break;
    case 403:
      message = detail ?? "Недостаточно прав";
      break;
    case 404:
      message = detail ?? "Ресурс не найден";
      break;
    case 429:
      message = detail ?? "Слишком много запросов, попробуйте позже";
      break;
    default:
      if (status >= 500) {
        message = detail ?? "Ошибка сервера, попробуйте позже";
      }
  }

  return new AppError(message, base);
}

export const httpClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: DEFAULT_TIMEOUT_MS,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

// Флаг и промис для избежания одновременных refresh-запросов
let refreshPromise: Promise<string | null> | null = null;

async function handleAuthAndNetworkError(
  error: AxiosError<ApiErrorBody>,
): Promise<never> {
  const mapped = mapAxiosError(error);

  const originalConfig = error.config as (InternalAxiosRequestConfig & {
    _retry?: boolean;
  }) | undefined;

  const status = error.response?.status;
  const url = originalConfig?.url ?? "";

  const isAuthRequest =
    url.startsWith("/token/") ||
    url.startsWith("token/") ||
    url === "/token" ||
    url === "token";

  // Для не-401 ошибок просто пробрасываем нормализованную ошибку
  if (status !== 401 || isAuthRequest || !originalConfig) {
    return Promise.reject(mapped);
  }

  // Чтобы не уйти в бесконечный цикл
  if (originalConfig._retry) {
    return Promise.reject(mapped);
  }

  // Refresh и повтор запроса выполняем только в браузере
  if (typeof window === "undefined") {
    return Promise.reject(mapped);
  }

  originalConfig._retry = true;

  // Инициализируем единственный refresh-запрос
  if (!refreshPromise) {
    const { refreshTokenSafe } = useAuthStore.getState();
    refreshPromise = (async () => {
      const result = await refreshTokenSafe();
      const nextAccess = useAuthStore.getState().accessToken;
      refreshPromise = null;
      return result ? nextAccess ?? null : null;
    })();
  }

  const newAccessToken = await refreshPromise;

  // Если обновить токен не удалось — очищаем сессию, но оставляем сохранённые креды
  if (!newAccessToken) {
    const { logout } = useAuthStore.getState();
    await logout({ clearSavedCredentials: false });
    return Promise.reject(mapped);
  }

  // Пробуем повторить исходный запрос один раз с новым токеном
  // Для совместимости с типом AxiosHeaders не переопределяем объект, а только устанавливаем поле
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (originalConfig.headers as any).Authorization = `Bearer ${newAccessToken}`;

  return httpClient(originalConfig) as Promise<never>;
}

httpClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError<ApiErrorBody>) => handleAuthAndNetworkError(error),
);

export type HttpRequestConfig = AxiosRequestConfig;


