import { httpClient } from "./httpClient";
import type {
  Attachment,
  Equipment,
  MaterialItem,
  ServiceItem,
} from "@/shared/types/catalog";
import {
  mapAttachmentFromApi,
  mapEquipmentFromApi,
  mapMaterialFromApi,
  mapServiceFromApi,
} from "@/shared/types/catalog";
import type { ClientInfo } from "@/shared/types/orders";
import type { MaybePaginated } from "@/shared/api/types";

function mapMaybePaginated<T>(
  payload: MaybePaginated<unknown>,
  mapFn: (value: unknown) => T,
): T[] {
  if (Array.isArray(payload)) {
    return payload.map((item) => mapFn(item));
  }
  if (
    payload &&
    typeof payload === "object" &&
    Array.isArray((payload as { results?: unknown[] }).results)
  ) {
    return (payload as { results: unknown[] }).results.map((item) =>
      mapFn(item),
    );
  }
  return [];
}

export interface EquipmentListParams {
  status?: string;
  search?: string;
  pageSize?: number;
}

export interface ServicesListParams {
  category?: number;
  search?: string;
  pageSize?: number;
}

export interface MaterialsListParams {
  search?: string;
  category?: string;
  pageSize?: number;
}

export interface AttachmentsListParams {
  search?: string;
}

export interface ClientsListParams {
  search?: string;
}

function mapClientFromApi(payload: unknown): ClientInfo {
  const raw = (payload ?? {}) as Record<string, unknown>;

  return {
    id: typeof raw.id === "number" ? raw.id : 0,
    name: String(raw.name ?? ""),
    contactPerson:
      (raw.contact_person as string | null | undefined) ??
      (raw.contactPerson as string | null | undefined) ??
      null,
    phone: String(raw.phone ?? ""),
    email: (raw.email as string | null | undefined) ?? null,
    address: (raw.address as string | null | undefined) ?? null,
    city: (raw.city as string | null | undefined) ?? null,
    geoLat:
      typeof raw.geo_lat === "number"
        ? raw.geo_lat
        : null,
    geoLng:
      typeof raw.geo_lng === "number"
        ? raw.geo_lng
        : null,
  };
}

export const CatalogApi = {
  async getEquipment(params: EquipmentListParams = {}): Promise<Equipment[]> {
    const query: Record<string, unknown> = {};
    if (params.status) query.status = params.status;
    if (params.search) query.search = params.search;
    query.page_size = params.pageSize ?? 100;

    const response = await httpClient.get<MaybePaginated<unknown>>(
      "/equipment/",
      {
        params: query,
      },
    );
    return mapMaybePaginated(response.data, mapEquipmentFromApi);
  },

  async createEquipment(payload: {
    code: string;
    name: string;
    description?: string;
    hourly_rate: number;
    daily_rate?: number | null;
  }): Promise<Equipment> {
    const response = await httpClient.post<unknown>("/equipment/", payload);
    return mapEquipmentFromApi(response.data);
  },

  async getServices(params: ServicesListParams = {}): Promise<ServiceItem[]> {
    const query: Record<string, unknown> = {};
    if (typeof params.category === "number") query.category = params.category;
    if (params.search) query.search = params.search;
    query.page_size = params.pageSize ?? 100;

    const response = await httpClient.get<MaybePaginated<unknown>>(
      "/services/",
      {
        params: query,
      },
    );
    return mapMaybePaginated(response.data, mapServiceFromApi);
  },

  async createService(payload: {
    name: string;
    unit: string;
    price: number | null;
  }): Promise<ServiceItem> {
    const response = await httpClient.post<unknown>("/services/", payload);
    return mapServiceFromApi(response.data);
  },

  async getMaterials(
    params: MaterialsListParams = {},
  ): Promise<MaterialItem[]> {
    const query: Record<string, unknown> = {};
    if (params.search) query.search = params.search;
    if (params.category) query.category = params.category;
    query.page_size = params.pageSize ?? 100;

    const response = await httpClient.get<MaybePaginated<unknown>>(
      "/materials/",
      {
        params: query,
      },
    );
    return mapMaybePaginated(response.data, mapMaterialFromApi);
  },

  async createMaterial(payload: {
    name: string;
    unit: string;
    price: number;
  }): Promise<MaterialItem> {
    const response = await httpClient.post<unknown>("/materials/", payload);
    return mapMaterialFromApi(response.data);
  },

  async updateEquipment(
    id: number,
    payload: Partial<{
      code: string;
      name: string;
      description: string;
      hourly_rate: number;
      daily_rate: number | null;
    }>,
  ): Promise<Equipment> {
    const response = await httpClient.patch<unknown>(`/equipment/${id}/`, payload);
    return mapEquipmentFromApi(response.data);
  },

  async deleteEquipment(id: number): Promise<void> {
    await httpClient.delete(`/equipment/${id}/`);
  },

  async updateService(
    id: number,
    payload: Partial<{
      name: string;
      unit: string;
      price: number | null;
    }>,
  ): Promise<ServiceItem> {
    const response = await httpClient.patch<unknown>(`/services/${id}/`, payload);
    return mapServiceFromApi(response.data);
  },

  async deleteService(id: number): Promise<void> {
    await httpClient.delete(`/services/${id}/`);
  },

  async updateMaterial(
    id: number,
    payload: Partial<{
      name: string;
      unit: string;
      price: number;
    }>,
  ): Promise<MaterialItem> {
    const response = await httpClient.patch<unknown>(`/materials/${id}/`, payload);
    return mapMaterialFromApi(response.data);
  },

  async deleteMaterial(id: number): Promise<void> {
    await httpClient.delete(`/materials/${id}/`);
  },

  async getAttachments(
    params: AttachmentsListParams = {},
  ): Promise<Attachment[]> {
    const query: Record<string, unknown> = {};
    if (params.search) query.search = params.search;

    const response = await httpClient.get<MaybePaginated<unknown>>(
      "/attachments/",
      {
        params: query,
      },
    );
    return mapMaybePaginated(response.data, mapAttachmentFromApi);
  },

  async createAttachment(payload: {
    equipment: number;
    name: string;
    price?: number;
    status?: string;
  }): Promise<Attachment> {
    const response = await httpClient.post<unknown>("/attachments/", payload);
    return mapAttachmentFromApi(response.data);
  },

  async updateAttachment(
    id: number,
    payload: Partial<{
      equipment: number;
      name: string;
      price: number;
      status: string;
    }>,
  ): Promise<Attachment> {
    const response = await httpClient.patch<unknown>(
      `/attachments/${id}/`,
      payload,
    );
    return mapAttachmentFromApi(response.data);
  },

  async deleteAttachment(id: number): Promise<void> {
    await httpClient.delete(`/attachments/${id}/`);
  },

  async getClients(params: ClientsListParams = {}): Promise<ClientInfo[]> {
    const query: Record<string, unknown> = {};
    if (params.search) query.search = params.search;

    const response = await httpClient.get<MaybePaginated<unknown>>(
      "/clients/",
      {
        params: query,
      },
    );

    return mapMaybePaginated(response.data, mapClientFromApi);
  },

  async updateClient(
    id: number,
    payload: Partial<{
      name: string;
      phone: string;
      email: string;
      address: string;
      city: string;
    }>,
  ): Promise<ClientInfo> {
    const response = await httpClient.patch<unknown>(`/clients/${id}/`, payload);
    return mapClientFromApi(response.data);
  },

  async deleteClient(id: number): Promise<void> {
    await httpClient.delete(`/clients/${id}/`);
  },
};


