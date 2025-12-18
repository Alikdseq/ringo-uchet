import { httpClient } from "./httpClient";
import type {
  Order,
  OrderPricePreviewRequest,
  OrderPricePreviewResponse,
  OrderStatus,
  OrderStatusRequestPayload,
} from "@/shared/types/orders";
import { mapOrderFromApi, mapOrdersFromApi } from "@/shared/types/orders";
import { AppError } from "./httpClient";
import { OfflineQueueService } from "@/shared/offline/offlineQueue";

export interface OrdersListParams {
  status?: OrderStatus;
  search?: string;
  page?: number;
  pageSize?: number;
}

interface OrdersListQueryParams {
  status?: string;
  search?: string;
  page?: number;
  page_size?: number;
}

interface OrderRequestPayload {
  number?: string | null;
  client_id?: number | null;
  address: string;
  geo_lat?: number | null;
  geo_lng?: number | null;
  start_dt: string;
  end_dt?: string | null;
  description: string;
  status?: OrderStatus | null;
  manager_id?: number | null;
  operator_id?: number | null;
  operator_ids?: number[] | null;
  prepayment_amount?: number | null;
  total_amount?: number | null;
  items?: unknown[] | null;
}

const LIST_CACHE_PREFIX = "orders:list:";
const DETAIL_CACHE_PREFIX = "orders:detail:";
const LIST_CACHE_TTL_MS = 5 * 60 * 1000;

function buildListCacheKey(params: OrdersListParams): string {
  const status = params.status ?? "ALL";
  const search = params.search ?? "";
  const page = params.page ?? 1;
  const pageSize = params.pageSize ?? 50;
  return `${LIST_CACHE_PREFIX}${status}:${page}:${pageSize}:${search}`;
}

function readOrdersListCache(key: string): Order[] | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { at: number; data: unknown[] };
    if (!parsed || typeof parsed.at !== "number" || !Array.isArray(parsed.data)) {
      return null;
    }
    if (Date.now() - parsed.at > LIST_CACHE_TTL_MS) {
      window.localStorage.removeItem(key);
      return null;
    }
    return parsed.data.map((item) => mapOrderFromApi(item));
  } catch {
    return null;
  }
}

function writeOrdersListCache(key: string, orders: Order[]): void {
  if (typeof window === "undefined") return;
  try {
    const payload = {
      at: Date.now(),
      data: orders,
    };
    window.localStorage.setItem(key, JSON.stringify(payload));
  } catch {
    // Игнорируем ошибки записи в localStorage (например, переполнен)
  }
}

function readOrderDetailCache(id: string): Order | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(`${DETAIL_CACHE_PREFIX}${id}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object") {
      return null;
    }
    return mapOrderFromApi(parsed);
  } catch {
    return null;
  }
}

function writeOrderDetailCache(order: Order): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(
      `${DETAIL_CACHE_PREFIX}${order.id}`,
      JSON.stringify(order),
    );
  } catch {
    // Игнорируем ошибки записи в localStorage
  }
}

export const OrdersApi = {
  async list(params: OrdersListParams = {}): Promise<Order[]> {
    const query: OrdersListQueryParams = {};
    if (params.status) query.status = params.status;
    if (params.search) query.search = params.search;
    if (params.page) query.page = params.page;
    if (params.pageSize) query.page_size = params.pageSize;

    const cacheKey = buildListCacheKey(params);

    try {
      const response = await httpClient.get("/orders/", { params: query });
      const orders = mapOrdersFromApi(response.data as never);
      writeOrdersListCache(cacheKey, orders);
      return orders;
    } catch (error) {
      const appError = error as AppError;
      if (appError.isNetworkError || appError.isTimeout) {
        const cached = readOrdersListCache(cacheKey);
        if (cached) {
          return cached;
        }
      }
      throw error;
    }
  },

  async get(id: string | number): Promise<Order> {
    const idStr = String(id);
    try {
      const response = await httpClient.get(`/orders/${idStr}/`);
      const order = mapOrderFromApi(response.data);
      writeOrderDetailCache(order);
      return order;
    } catch (error) {
      const appError = error as AppError;
      if (appError.isNetworkError || appError.isTimeout) {
        const cached = readOrderDetailCache(idStr);
        if (cached) {
          return cached;
        }
      }
      throw error;
    }
  },

  async create(payload: OrderRequestPayload): Promise<Order> {
    try {
      const response = await httpClient.post("/orders/", payload);
      const order = mapOrderFromApi(response.data);
      writeOrderDetailCache(order);
      return order;
    } catch (error) {
      const appError = error as AppError;
      if (appError.isNetworkError || appError.isTimeout) {
        OfflineQueueService.enqueue({
          action: "order_create",
          endpoint: "/orders/",
          method: "POST",
          payload,
          meta: {
            label: "Создание заявки",
          },
        });
      }
      throw error;
    }
  },

  async update(id: string | number, payload: OrderRequestPayload): Promise<Order> {
    const response = await httpClient.patch(`/orders/${id}/`, payload);
    const order = mapOrderFromApi(response.data);
    writeOrderDetailCache(order);
    return order;
  },

  async changeStatus(
    id: string | number,
    data: OrderStatusRequestPayload,
  ): Promise<void> {
    try {
      await httpClient.patch(`/orders/${id}/status/`, data);
    } catch (error) {
      const appError = error as AppError;
      if (appError.isNetworkError || appError.isTimeout) {
        OfflineQueueService.enqueue({
          action: "order_status_change",
          endpoint: `/orders/${id}/status/`,
          method: "PATCH",
          payload: data,
          meta: {
            label: "Смена статуса заявки",
            orderId: String(id),
          },
        });
      }
      throw error;
    }
  },

  async previewPrice(
    id: string | number,
    data: OrderPricePreviewRequest,
  ): Promise<OrderPricePreviewResponse> {
    const response = await httpClient.post<OrderPricePreviewResponse>(
      `/orders/${id}/calculate/preview/`,
      data,
    );
    return response.data;
  },

  async complete(id: string | number, payload: unknown): Promise<Order> {
    try {
      const response = await httpClient.post(`/orders/${id}/complete/`, payload);
      const order = mapOrderFromApi(response.data);
      writeOrderDetailCache(order);
      return order;
    } catch (error) {
      const appError = error as AppError;
      if (appError.isNetworkError || appError.isTimeout) {
        OfflineQueueService.enqueue({
          action: "order_complete",
          endpoint: `/orders/${id}/complete/`,
          method: "POST",
          payload,
          meta: {
            label: "Завершение заявки",
            orderId: String(id),
          },
        });
      }
      throw error;
    }
  },

  async updateSalaries(
    id: string | number,
    payload: {
      operator_salaries?: { operator_id: number; salary: number }[];
      operator_salary?: number | null;
    },
  ): Promise<void> {
    await httpClient.post(`/orders/${id}/salaries/`, payload);
  },

  async generateInvoice(id: string | number): Promise<void> {
    await httpClient.post(`/orders/${id}/generate_invoice/`);
  },

  async getReceiptPdf(id: string | number): Promise<Blob> {
    const response = await httpClient.get<ArrayBuffer>(
      `/orders/${id}/receipt/`,
      {
        responseType: "arraybuffer",
      },
    );
    return new Blob([response.data], { type: "application/pdf" });
  },

  async delete(id: string | number): Promise<void> {
    await httpClient.post(`/orders/${id}/delete/`);
  },
};


