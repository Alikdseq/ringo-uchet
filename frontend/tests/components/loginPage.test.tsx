import React from "react";
import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import LoginPage from "@/app/(auth)/login/page";

vi.mock("next/navigation", () => ({
  useRouter: () => ({
    replace: vi.fn(),
  }),
}));

vi.mock("@/shared/store/authStore", () => {
  const loginMock = vi.fn();
  type AuthStateShape = {
    isAuthenticated: boolean;
    isLoading: boolean;
    error: string | null;
    login: (payload: unknown) => Promise<void> | void;
  };

  return {
    useAuthStore: (selector: (state: AuthStateShape) => unknown) =>
      selector({
        isAuthenticated: false,
        isLoading: false,
        error: null,
        login: loginMock,
      }),
  };
});

describe("LoginPage", () => {
  it("shows validation error when submitting empty form", async () => {
    render(<LoginPage />);

    const submitButton = screen.getByRole("button", { name: "Войти" });
    fireEvent.click(submitButton);

    expect(
      await screen.findByText("Заполните телефон/email и пароль"),
    ).toBeInTheDocument();
  });
});


