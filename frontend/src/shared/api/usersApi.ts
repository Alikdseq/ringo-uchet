import { httpClient } from "./httpClient";
import type { UserInfo } from "@/shared/types/auth";

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

export const UsersApi = {
  async getOperators(): Promise<UserInfo[]> {
    const response = await httpClient.get<unknown[]>("/users/operators/");
    const raw = Array.isArray(response.data) ? response.data : [];
    return raw.map((item) => mapUserFromApi(item));
  },
};
