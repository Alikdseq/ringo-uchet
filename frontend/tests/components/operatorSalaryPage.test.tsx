import React from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen } from "@testing-library/react";
import OperatorSalaryPage from "@/app/(app)/profile/salary/page";

vi.mock("@/shared/api/profileApi", () => ({
  ProfileApi: {
    getOperatorSalary: vi.fn().mockResolvedValue({
      totalSalary: 1000,
      orders: [
        {
          id: "1",
          number: "ORD-1",
          clientName: "Клиент",
          status: "COMPLETED",
          totalAmount: 2000,
          salaryAmount: 500,
          createdAt: new Date("2024-12-01T10:00:00Z"),
          startDt: null,
          endDt: null,
          address: "Адрес",
        },
      ],
    }),
  },
}));

vi.mock("@/shared/components/auth/RoleGuard", () => ({
  RoleGuard: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}));

describe("OperatorSalaryPage", () => {
  it("renders period filter controls", () => {
    const client = new QueryClient();

    render(
      <QueryClientProvider client={client}>
        <OperatorSalaryPage />
      </QueryClientProvider>,
    );

    expect(screen.getByText("Период с")).toBeInTheDocument();
    expect(screen.getByText("Период по")).toBeInTheDocument();

    const resetButton = screen.getByRole("button", { name: "Сбросить" });
    fireEvent.click(resetButton);
  });
});


