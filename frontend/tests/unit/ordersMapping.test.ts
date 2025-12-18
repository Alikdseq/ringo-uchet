import { describe, expect, it } from "vitest";
import { type OrderStatus, mapOrderFromApi } from "@/shared/types/orders";

describe("mapOrderFromApi", () => {
  it("parses decimal fields and dates from string payload", () => {
    const payload = {
      id: 1,
      number: "ORD-1",
      client: {
        id: 10,
        name: "Тестовый клиент",
        phone: "+79990000000",
      },
      address: "Москва, ул. Тестовая, д.1",
      start_dt: "2024-12-01T10:00:00Z",
      end_dt: "2024-12-01T12:00:00Z",
      status: "CREATED" as OrderStatus,
      prepayment_amount: "1000.50",
      total_amount: "5000.75",
      prepayment_status: "paid",
      created_at: "2024-11-30T09:00:00Z",
      updated_at: "2024-11-30T10:00:00Z",
      items: [],
      attachments: [],
      meta: {},
    };

    const order = mapOrderFromApi(payload);

    expect(order.id).toBe("1");
    expect(order.number).toBe("ORD-1");
    expect(order.client?.id).toBe(10);
    expect(order.client?.name).toBe("Тестовый клиент");
    expect(order.address).toBe(payload.address);
    expect(order.status).toBe("CREATED");
    expect(order.prepaymentAmount).toBeCloseTo(1000.5);
    expect(order.totalAmount).toBeCloseTo(5000.75);
    expect(order.prepaymentStatus).toBe("paid");
    expect(order.startDt).toBeInstanceOf(Date);
    expect(order.endDt).toBeInstanceOf(Date);
    expect(order.createdAt).toBeInstanceOf(Date);
    expect(order.updatedAt).toBeInstanceOf(Date);
  });

  it("normalizes missing or malformed values", () => {
    const payload = {
      id: "xyz",
      number: null,
      client_id: 20,
      address: null,
      status: "UNKNOWN",
      prepayment_amount: "NaN",
      total_amount: null,
      created_at: null,
      updated_at: undefined,
      items: null,
    };

    const order = mapOrderFromApi(payload);

    expect(order.id).toBe("xyz");
    expect(order.number).toBe("");
    expect(order.clientId).toBe(20);
    expect(order.address).toBe("");
    // UNKNOWN -> DRAFT по normalizeOrderStatus
    expect(order.status).toBe("DRAFT");
    expect(order.prepaymentAmount).toBe(0);
    expect(order.totalAmount).toBe(0);
    expect(order.items).toEqual([]);
  });
});


