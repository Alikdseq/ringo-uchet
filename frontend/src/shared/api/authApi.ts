import { httpClient } from "./httpClient";
import type {
  AuthResponse,
  ChangePasswordRequest,
  LoginRequest,
  RefreshTokenRequest,
  RefreshTokenResponse,
  RegisterRequest,
  UserInfo,
} from "@/shared/types/auth";

export const AuthApi = {
  async login(data: LoginRequest): Promise<AuthResponse> {
    const response = await httpClient.post<AuthResponse>("/token/", data);
    return response.data;
  },

  async refreshToken(data: RefreshTokenRequest): Promise<RefreshTokenResponse> {
    const response = await httpClient.post<RefreshTokenResponse>(
      "/token/refresh/",
      data,
    );
    return response.data;
  },

  async logout(refresh: string): Promise<void> {
    // Даже если logout завершится ошибкой, на фронте мы всё равно будем
    // принудительно очищать сессию, поэтому ошибки можно гасить по месту вызова.
    await httpClient.post("/token/blacklist/", { refresh });
  },

  async getCurrentUser(): Promise<UserInfo> {
    const response = await httpClient.get<UserInfo>("/users/me/");
    return response.data;
  },

  async register(data: RegisterRequest): Promise<void> {
    await httpClient.post("/users/register/", {
      phone: data.phone,
      password: data.password,
      first_name: data.firstName,
      last_name: data.lastName,
    });
  },

  async changePassword(data: ChangePasswordRequest): Promise<void> {
    await httpClient.post("/users/change-password/", {
      old_password: data.oldPassword,
      new_password: data.newPassword,
      confirm_password: data.confirmPassword,
    });
  },
};


