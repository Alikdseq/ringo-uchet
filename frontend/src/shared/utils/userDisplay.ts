import type { UserInfo } from "@/shared/types/auth";

/**
 * Человекочитаемое ФИО пользователя.
 * Никогда не возвращает «Оператор #id» / «ID n», если есть имя.
 */
export function formatUserDisplayName(
  user:
    | UserInfo
    | {
        id?: number;
        firstName?: string | null;
        lastName?: string | null;
        first_name?: string | null;
        last_name?: string | null;
        fullNameFromApi?: string | null;
        full_name?: string | null;
        username?: string | null;
        phone?: string | null;
      }
    | null
    | undefined,
  fallback = "Без имени",
): string {
  if (!user) return fallback;

  const fullFromApi =
    ("fullNameFromApi" in user ? user.fullNameFromApi : null) ||
    ("full_name" in user ? user.full_name : null);
  if (typeof fullFromApi === "string" && fullFromApi.trim()) {
    return fullFromApi.trim();
  }

  const first =
    ("firstName" in user && user.firstName) ||
    ("first_name" in user && user.first_name) ||
    "";
  const last =
    ("lastName" in user && user.lastName) ||
    ("last_name" in user && user.last_name) ||
    "";
  const full = `${first ?? ""} ${last ?? ""}`.trim();
  if (full) return full;

  if (user.username && String(user.username).trim()) {
    return String(user.username).trim();
  }
  if (user.phone && String(user.phone).trim()) {
    return String(user.phone).trim();
  }

  return fallback;
}

export function mapUserInfoFromApi(payload: unknown): UserInfo | null {
  if (!payload || typeof payload !== "object") return null;
  const raw = payload as Record<string, unknown>;
  const id = typeof raw.id === "number" ? raw.id : null;
  if (id == null) return null;

  return {
    id,
    username: (raw.username as string | null | undefined) ?? null,
    email: (raw.email as string | null | undefined) ?? null,
    phone: (raw.phone as string | null | undefined) ?? null,
    firstName:
      (raw.first_name as string | null | undefined) ??
      (raw.firstName as string | null | undefined) ??
      null,
    lastName:
      (raw.last_name as string | null | undefined) ??
      (raw.lastName as string | null | undefined) ??
      null,
    fullNameFromApi:
      (raw.full_name as string | null | undefined) ??
      (raw.fullNameFromApi as string | null | undefined) ??
      null,
    role: typeof raw.role === "string" ? raw.role : "",
    roleDisplay: (raw.role_display as string | null | undefined) ?? null,
    avatar: (raw.avatar as string | null | undefined) ?? null,
    locale: (raw.locale as string | null | undefined) ?? null,
    position: (raw.position as string | null | undefined) ?? null,
  };
}
