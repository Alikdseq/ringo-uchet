import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import { AuthApi } from "@/shared/api/authApi";
import type {
  AuthResponse,
  LoginRequest,
  RefreshTokenResponse,
  UserInfo,
} from "@/shared/types/auth";

interface SavedCredentials {
  identifier: string;
  password: string;
}

export interface AuthState {
  user: UserInfo | null;
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  /** true пока читаем localStorage и пробуем авто-вход */
  isBootstrapping: boolean;
  error: string | null;
  savedCredentials: SavedCredentials | null;
  lastLoginIp: string | null;
  login: (payload: LoginRequest) => Promise<void>;
  logout: (options?: { clearSavedCredentials?: boolean }) => Promise<void>;
  tryAutoLogin: () => Promise<void>;
  refreshTokenSafe: () => Promise<RefreshTokenResponse | null>;
  loadCurrentUser: () => Promise<void>;
  setBootstrapping: (value: boolean) => void;
}

type PersistedAuthSlice = Pick<
  AuthState,
  "user" | "accessToken" | "refreshToken" | "savedCredentials" | "lastLoginIp"
>;

async function detectClientIp(): Promise<string | null> {
  if (typeof window === "undefined") return null;
  try {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 2500);
    const res = await fetch("https://api.ipify.org?format=json", {
      signal: controller.signal,
    });
    window.clearTimeout(timer);
    if (!res.ok) return null;
    const data = (await res.json()) as { ip?: string };
    return typeof data.ip === "string" ? data.ip : null;
  } catch {
    return null;
  }
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      accessToken: null,
      refreshToken: null,
      isAuthenticated: false,
      isLoading: false,
      isBootstrapping: true,
      error: null,
      savedCredentials: null,
      lastLoginIp: null,

      setBootstrapping(value: boolean) {
        set({ isBootstrapping: value });
      },

      async login(payload: LoginRequest): Promise<void> {
        set({ isLoading: true, error: null });
        try {
          // 1. Получаем access/refresh по логину
          const response: AuthResponse = await AuthApi.login(payload);
          const { access, refresh } = response;

          const identifier =
            payload.phone ?? payload.email ?? payload.username ?? "";

          const clientIp = await detectClientIp();

          // 2. Сохраняем токены и базовое состояние авторизации
          // (пароль — для авто-входа на этом устройстве после истечения refresh)
          set({
            accessToken: access,
            refreshToken: refresh,
            isAuthenticated: true,
            error: null,
            lastLoginIp: clientIp,
            savedCredentials: identifier
              ? {
                  identifier,
                  password: payload.password,
                }
              : null,
          });

          // 3. Подтягиваем профиль текущего пользователя, чтобы знать его роль
          const currentUser = await AuthApi.getCurrentUser();

          set({
            user: currentUser,
            isLoading: false,
            isAuthenticated: true,
            isBootstrapping: false,
          });
        } catch (e) {
          const message =
            e instanceof Error ? e.message : "Не удалось выполнить вход";
          set({
            user: null,
            accessToken: null,
            refreshToken: null,
            isLoading: false,
            error: message,
            isAuthenticated: false,
            isBootstrapping: false,
          });
          throw e;
        }
      },

      async logout(options?: {
        clearSavedCredentials?: boolean;
      }): Promise<void> {
        const { refreshToken, savedCredentials, lastLoginIp } = get();
        try {
          if (refreshToken) {
            await AuthApi.logout(refreshToken);
          }
        } catch {
          // Игнорируем ошибки logout, всё равно локально чистим состояние.
        }
        set({
          user: null,
          accessToken: null,
          refreshToken: null,
          isAuthenticated: false,
          isLoading: false,
          isBootstrapping: false,
          error: null,
          savedCredentials: options?.clearSavedCredentials
            ? null
            : savedCredentials,
          lastLoginIp: options?.clearSavedCredentials ? null : lastLoginIp,
        });
      },

      async refreshTokenSafe(): Promise<RefreshTokenResponse | null> {
        const { refreshToken } = get();
        if (!refreshToken) {
          return null;
        }

        try {
          const response = await AuthApi.refreshToken({ refresh: refreshToken });
          set({
            accessToken: response.access,
          });
          return response;
        } catch {
          // Если refresh не удался (401, истёк или отозван), не считаем это
          // критической ошибкой, но токены больше использовать нельзя.
          set({
            accessToken: null,
            refreshToken: null,
            isAuthenticated: false,
          });
          return null;
        }
      },

      async loadCurrentUser(): Promise<void> {
        const { accessToken } = get();
        if (!accessToken) {
          return;
        }
        try {
          const user = await AuthApi.getCurrentUser();
          set({
            user,
            isAuthenticated: true,
          });
        } catch (e) {
          // Если получаем 401/403, считаем, что сессия недействительна,
          // но сохранённые креды не трогаем
          set({
            user: null,
            accessToken: null,
            refreshToken: null,
            isAuthenticated: false,
          });
          throw e;
        }
      },

      async tryAutoLogin(): Promise<void> {
        // На сервере авто-логин не выполняем
        if (typeof window === "undefined") {
          set({ isBootstrapping: false });
          return;
        }

        const { accessToken, refreshToken, isAuthenticated, savedCredentials } =
          get();

        // Если в рамках текущей сессии уже есть accessToken и флаг авторизации,
        // авто-логин не нужен.
        if (isAuthenticated && accessToken) {
          set({ isBootstrapping: false, isLoading: false });
          return;
        }

        set({ isLoading: true, error: null, isBootstrapping: true });

        // 1) Пытаемся обновить access по refresh-токену
        if (refreshToken) {
          const refreshed = await get().refreshTokenSafe();
          if (refreshed && get().accessToken) {
            try {
              await get().loadCurrentUser();
              set({
                isAuthenticated: true,
                isLoading: false,
                isBootstrapping: false,
              });
            } catch {
              // Если не удалось подтянуть пользователя, считаем сессию
              // недействительной и попросим залогиниться вручную.
              set({
                user: null,
                accessToken: null,
                refreshToken: null,
                isAuthenticated: false,
                isLoading: false,
              });
              // fall through to saved credentials
            }
            if (get().isAuthenticated) {
              return;
            }
          }
        }

        // 2) Если refresh не сработал или его нет — пробуем авто-логин
        // по сохранённым учётным данным (телефон/email + пароль) на этом устройстве
        if (savedCredentials?.identifier && savedCredentials.password) {
          const trimmed = savedCredentials.identifier.trim();
          const payload: LoginRequest = {
            password: savedCredentials.password,
          };

          if (/^\+?\d{5,}$/.test(trimmed)) {
            payload.phone = trimmed;
          } else if (trimmed.includes("@")) {
            payload.email = trimmed;
          } else {
            payload.username = trimmed;
          }

          try {
            await get().login(payload);
            set({ isLoading: false, isBootstrapping: false });
            return;
          } catch {
            // Если авто-логин не удался (пароль изменили и т.п.), оставляем
            // пользователя неавторизованным — его перекинет на экран входа.
            set({
              isLoading: false,
              isAuthenticated: false,
              isBootstrapping: false,
            });
            return;
          }
        }

        // 3) Нечего восстанавливать — остаёмся неавторизованными
        set({
          isLoading: false,
          isAuthenticated: false,
          isBootstrapping: false,
        });
      },
    }),
    {
      name: "ringo-auth",
      storage:
        typeof window !== "undefined"
          ? createJSONStorage(() => window.localStorage)
          : undefined,
      partialize: (state): PersistedAuthSlice => ({
        user: state.user,
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
        savedCredentials: state.savedCredentials,
        lastLoginIp: state.lastLoginIp,
      }),
      onRehydrateStorage: () => () => {
        // hydration finished — AuthBootstrap вызовет tryAutoLogin
      },
    },
  ),
);

