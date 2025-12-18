export interface OperatorSalaryOrder {
  id: string;
  number: string;
  clientName: string | null;
  status: string;
  totalAmount: number;
  salaryAmount: number;
  createdAt: Date;
  startDt: Date | null;
  endDt: Date | null;
  address: string;
}

export interface OperatorSalaryResponse {
  totalSalary: number;
  orders: OperatorSalaryOrder[];
}

function asObject(input: unknown): Record<string, unknown> {
  if (!input || typeof input !== "object") {
    return {};
  }
  return input as Record<string, unknown>;
}

function parseNumber(value: unknown, defaultValue: number): number {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : defaultValue;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : defaultValue;
  }
  return defaultValue;
}

function parseDate(value: unknown): Date {
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const d = new Date(value);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return new Date(0);
}

function parseOptionalDate(value: unknown): Date | null {
  if (value == null) return null;
  const d = parseDate(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

function mapOperatorSalaryOrderFromApi(
  payload: unknown,
): OperatorSalaryOrder | null {
  const obj = asObject(payload);
  const salaryRaw = asObject(obj.salary);

  const id = String(obj.id ?? "");
  const number = String(obj.number ?? obj.order_number ?? "");

  if (!id || !number) {
    return null;
  }

  const clientName =
    (obj.client_name as string | null | undefined) ??
    (obj.clientName as string | null | undefined) ??
    null;

  const status = String(obj.status ?? "");

  const totalAmount = parseNumber(
    obj.total_amount ?? obj.totalAmount ?? obj.amount,
    0,
  );
  const salaryAmount = parseNumber(salaryRaw.amount, 0);

  const createdSource =
    obj.start_dt ??
    obj.created_at ??
    salaryRaw.created_at ??
    new Date().toISOString();
  const createdAt = parseDate(createdSource);

  const startDt = parseOptionalDate(obj.start_dt);
  const endDt = parseOptionalDate(obj.end_dt);

  const address =
    (obj.address as string | null | undefined) ??
    (obj.order_address as string | null | undefined) ??
    "";

  return {
    id,
    number,
    clientName,
    status,
    totalAmount,
    salaryAmount,
    createdAt,
    startDt,
    endDt,
    address,
  };
}

export function mapOperatorSalaryFromApi(
  payload: unknown,
): OperatorSalaryResponse {
  const root = asObject(payload);
  const totalSalary = parseNumber(root.total_salary, 0);

  const ordersRaw = Array.isArray(root.orders) ? root.orders : [];
  const orders: OperatorSalaryOrder[] = ordersRaw
    .map((item) => mapOperatorSalaryOrderFromApi(item))
    .filter((item): item is OperatorSalaryOrder => item != null);

  return {
    totalSalary,
    orders,
  };
}


