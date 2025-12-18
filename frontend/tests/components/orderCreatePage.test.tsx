"use client";

import React from "react";
import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import OrderCreatePage from "@/app/(app)/orders/create/page";

vi.mock("next/navigation", () => ({
  useRouter: () => ({
    replace: vi.fn(),
  }),
}));

vi.mock("@/shared/api/ordersApi", () => ({
  OrdersApi: {
    create: vi.fn(),
  },
}));

vi.mock("@/shared/api/httpClient", () => ({
  httpClient: {
    get: vi.fn(),
    post: vi.fn(),
  },
}));

describe("OrderCreatePage", () => {
  it("renders first step of create order wizard", () => {
    render(<OrderCreatePage />);

    expect(
      screen.getByRole("heading", { name: "Создание заявки" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Шаг 1. Клиент" }),
    ).toBeInTheDocument();

    const nextButton = screen.getByRole("button", { name: "Далее" });
    fireEvent.click(nextButton);
  });
});


