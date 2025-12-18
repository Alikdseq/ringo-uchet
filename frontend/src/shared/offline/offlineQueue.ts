import { AppError, httpClient } from "@/shared/api/httpClient";

export type OfflineQueueMethod = "POST" | "PATCH" | "PUT" | "DELETE";

export interface OfflineQueueMeta {
  label?: string;
  orderId?: string;
  orderNumber?: string;
}

export interface OfflineQueueItem {
  id: string;
  action: string;
  endpoint: string;
  method: OfflineQueueMethod;
  payload: unknown;
  createdAt: string;
  retries: number;
  lastError?: string | null;
  meta?: OfflineQueueMeta;
}

const STORAGE_KEY = "ringo-offline-queue-v1";

function hasWindow(): boolean {
  return typeof window !== "undefined";
}

function readQueue(): OfflineQueueItem[] {
  if (!hasWindow()) return [];
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed as OfflineQueueItem[];
  } catch {
    return [];
  }
}

function writeQueue(items: OfflineQueueItem[]): void {
  if (!hasWindow()) return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  } catch {
    // Игнорируем ошибки записи (quota exceeded и т.п.)
  }
}

function generateId(): string {
  if (hasWindow() && window.crypto && "randomUUID" in window.crypto) {
    return window.crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(16).slice(2)}`;
}

export interface EnqueueParams {
  action: string;
  endpoint: string;
  method: OfflineQueueMethod;
  payload: unknown;
  meta?: OfflineQueueMeta;
}

export const OfflineQueueService = {
  list(): OfflineQueueItem[] {
    return readQueue();
  },

  enqueue(params: EnqueueParams): OfflineQueueItem {
    const items = readQueue();
    const item: OfflineQueueItem = {
      id: generateId(),
      action: params.action,
      endpoint: params.endpoint,
      method: params.method,
      payload: params.payload,
      createdAt: new Date().toISOString(),
      retries: 0,
      lastError: null,
      meta: params.meta,
    };
    items.push(item);
    writeQueue(items);
    return item;
  },

  remove(id: string): void {
    const items = readQueue();
    const next = items.filter((item) => item.id !== id);
    writeQueue(next);
  },

  async retryItem(id: string): Promise<void> {
    const items = readQueue();
    const index = items.findIndex((item) => item.id === id);
    if (index === -1) {
      return;
    }

    const item = items[index];

    try {
      await httpClient.request({
        url: item.endpoint,
        method: item.method,
        data: item.payload,
      });

      const next = readQueue().filter((entry) => entry.id !== id);
      writeQueue(next);
    } catch (error) {
      const appError =
        error instanceof AppError
          ? error
          : new AppError(
              error instanceof Error ? error.message : "Ошибка при синхронизации",
            );
      const updatedItems = readQueue().map((entry) =>
        entry.id === id
          ? {
              ...entry,
              retries: entry.retries + 1,
              lastError: appError.message,
            }
          : entry,
      );
      writeQueue(updatedItems);
    }
  },

  async retryAll(): Promise<void> {
    const snapshot = readQueue();
    // Запускаем последовательно, чтобы не создавать лишнюю нагрузку
    for (const item of snapshot) {
      await this.retryItem(item.id);
    }
  },
};


