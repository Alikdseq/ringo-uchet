export interface UserInfo {
  id: number;
  username?: string | null;
  email?: string | null;
  phone?: string | null;
  firstName?: string | null;
  lastName?: string | null;
  /**
   * Значение `full_name`, которое приходит напрямую из API.
   * В Flutter это `fullNameFromApi`.
   */
  fullNameFromApi?: string | null;
  role: string;
  roleDisplay?: string | null;
  avatar?: string | null;
  locale?: string | null;
  position?: string | null;
}

export interface AuthResponse {
  access: string;
  refresh: string;
  user?: UserInfo | null;
}

export interface LoginRequest {
  phone?: string;
  email?: string;
  username?: string;
  password: string;
  captchaToken?: string;
}

export interface OTPRequest {
  phone: string;
  captchaToken?: string;
}

export interface OTPVerifyRequest {
  phone: string;
  code: string;
}

export interface RefreshTokenRequest {
  refresh: string;
}

export interface RefreshTokenResponse {
  access: string;
}

export interface RegisterRequest {
  phone: string;
  password: string;
  firstName: string;
  lastName: string;
}

export interface ChangePasswordRequest {
  oldPassword: string;
  newPassword: string;
  confirmPassword: string;
}

