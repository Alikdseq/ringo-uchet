import { describe, expect, it } from "vitest";
import { mapOperatorSalaryFromApi } from "@/shared/types/salary";

describe("mapOperatorSalaryFromApi", () => {
  it("parses total salary and orders from API payload", () => {
    const payload = {
      total_salary: "12345.67",
      orders: [
        {
          id: 1,
          number: "ORD-1",
          client_name: "Клиент 1",
          status: "COMPLETED",
          total_amount: "5000",
          salary: {
            amount: "1500.25",
            created_at: "2024-12-01T10:00:00Z",
          },
          created_at: "2024-12-01T09:00:00Z",
          start_dt: "2024-12-01T09:00:00Z",
          end_dt: "2024-12-01T11:00:00Z",
          address: "Адрес 1",
        },
      ],
    };

    const result = mapOperatorSalaryFromApi(payload);

    expect(result.totalSalary).toBeCloseTo(12345.67);
    expect(result.orders).toHaveLength(1);
    const [order] = result.orders;
    expect(order.id).toBe("1");
    expect(order.number).toBe("ORD-1");
    expect(order.clientName).toBe("Клиент 1");
    expect(order.status).toBe("COMPLETED");
    expect(order.totalAmount).toBe(5000);
    expect(order.salaryAmount).toBeCloseTo(1500.25);
    expect(order.createdAt).toBeInstanceOf(Date);
    expect(order.startDt).toBeInstanceOf(Date);
    expect(order.endDt).toBeInstanceOf(Date);
    expect(order.address).toBe("Адрес 1");
  });
});


