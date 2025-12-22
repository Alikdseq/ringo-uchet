import { httpClient } from "./httpClient";
import type { UserInfo } from "@/shared/types/auth";
import type { MaybePaginated } from "./types";

function mapUserFromApi(payload: unknown): UserInfo {
  const raw = (payload ?? {}) as Record<string, unknown>;

  return {
    id: typeof raw.id === "number" ? raw.id : 0,
    username: (raw.username as string | null | undefined) ?? null,
    email: (raw.email as string | null | undefined) ?? null,
    phone: (raw.phone as string | null | undefined) ?? null,
    firstName: (raw.first_name as string | null | undefined) ?? null,
    lastName: (raw.last_name as string | null | undefined) ?? null,
    fullNameFromApi: (raw.full_name as string | null | undefined) ?? null,
    role: typeof raw.role === "string" ? raw.role : "",
    roleDisplay: (raw.role_display as string | null | undefined) ?? null,
    avatar: (raw.avatar as string | null | undefined) ?? null,
    locale: (raw.locale as string | null | undefined) ?? null,
    position: (raw.position as string | null | undefined) ?? null,
  };
}

function mapMaybePaginatedUsers(
  payload: MaybePaginated<unknown>,
): UserInfo[] {
  if (Array.isArray(payload)) {
    return payload.map((item) => mapUserFromApi(item));
  }
  if (
    payload &&
    typeof payload === "object" &&
    Array.isArray((payload as { results?: unknown[] }).results)
  ) {
    return (payload as { results: unknown[] }).results.map((item) =>
      mapUserFromApi(item),
    );
  }
  return [];
}

export interface UsersListParams {
  role?: string;
  search?: string;
  is_active?: boolean;
}

export const UsersApi = {
  async getOperators(): Promise<UserInfo[]> {
    const response = await httpClient.get<unknown[]>("/users/operators/");
    const raw = Array.isArray(response.data) ? response.data : [];
    return raw.map((item) => mapUserFromApi(item));
  },

  async getUsers(params: UsersListParams = {}): Promise<UserInfo[]> {
    const query: Record<string, unknown> = {};
    if (params.role) query.role = params.role;
    if (params.search) query.search = params.search;
    if (params.is_active !== undefined) query.is_active = params.is_active;

    const response = await httpClient.get<MaybePaginated<unknown>>("/users/", {
      params: query,
    });
    return mapMaybePaginatedUsers(response.data);
  },

  async createUser(payload: {
    first_name: string;
    last_name: string;
    phone: string;
    password: string;
    email?: string;
    role?: string;
    username?: string;
  }): Promise<UserInfo> {
    const response = await httpClient.post<unknown>("/users/", payload);
    return mapUserFromApi(response.data);
  },

  async updateUser(
    id: number,
    payload: Partial<{
      first_name: string;
      last_name: string;
      phone: string;
      email: string;
      password: string;
      role: string;
      username: string;
      is_active: boolean;
    }>,
  ): Promise<UserInfo> {
    const response = await httpClient.patch<unknown>(`/users/${id}/`, payload);
    return mapUserFromApi(response.data);
  },

  async deleteUser(id: number): Promise<void> {
    await httpClient.delete(`/users/${id}/`);
  },
};
