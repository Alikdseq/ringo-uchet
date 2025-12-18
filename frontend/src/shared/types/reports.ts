export interface SummaryReportPeriod {
  from?: string | null;
  to?: string | null;
}

export interface SummaryReport {
  revenue: number;
  revenueFromServices: number;
  revenueFromServicesDetails: {
    totalAmount: number;
    totalQuantity: number;
    averagePricePerUnit: number;
  };
  revenueFromEquipment: number;
  revenueFromEquipmentDetails: {
    totalAmount: number;
    totalHours: number;
    totalShifts: number;
    averagePricePerHour: number;
  };
  expenses: number;
  expensesFuel: number;
  expensesRepair: number;
  salaries: number;
  margin: number;
  ordersCount: number;
  period: SummaryReportPeriod;
}

export interface EquipmentReportItem {
  equipmentId: number;
  equipmentName: string;
  code: string;
  status: string;
  totalHours: number;
  revenue: number;
  expenses: number;
  fuelExpenses: number;
  repairExpenses: number;
}

export interface EmployeeReportItem {
  userId: number;
  fullName: string;
  totalAmount: number;
  totalHours: number;
  assignments: number;
}

function parseNumber(value: unknown): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const normalized = value.replace(",", ".");
    const parsed = Number(normalized);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (value == null) return 0;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function mapSummaryReportFromApi(payload: unknown): SummaryReport {
  const raw = (payload ?? {}) as Record<string, unknown>;

  const servicesDetails = (raw.revenue_from_services_details ??
    {}) as Record<string, unknown>;
  const equipmentDetails = (raw.revenue_from_equipment_details ??
    {}) as Record<string, unknown>;
  const period = (raw.period ?? {}) as { from?: string | null; to?: string | null };

  return {
    revenue: parseNumber(raw.revenue),
    revenueFromServices: parseNumber(raw.revenue_from_services),
    revenueFromServicesDetails: {
      totalAmount: parseNumber(servicesDetails.total_amount),
      totalQuantity: parseNumber(servicesDetails.total_quantity),
      averagePricePerUnit: parseNumber(servicesDetails.average_price_per_unit),
    },
    revenueFromEquipment: parseNumber(raw.revenue_from_equipment),
    revenueFromEquipmentDetails: {
      totalAmount: parseNumber(equipmentDetails.total_amount),
      totalHours: parseNumber(equipmentDetails.total_hours),
      totalShifts: parseNumber(equipmentDetails.total_shifts),
      averagePricePerHour: parseNumber(equipmentDetails.average_price_per_hour),
    },
    expenses: parseNumber(raw.expenses),
    expensesFuel: parseNumber(raw.expenses_fuel),
    expensesRepair: parseNumber(raw.expenses_repair),
    salaries: parseNumber(raw.salaries),
    margin: parseNumber(raw.margin),
    ordersCount: typeof raw.orders_count === "number" ? raw.orders_count : 0,
    period: {
      from: period.from ?? null,
      to: period.to ?? null,
    },
  };
}

export function mapEquipmentReportFromApi(
  payload: unknown,
): EquipmentReportItem {
  const raw = (payload ?? {}) as Record<string, unknown>;

  return {
    equipmentId:
      typeof raw.equipment_id === "number" ? raw.equipment_id : 0,
    equipmentName: String(raw.equipment_name ?? ""),
    code: String(raw.code ?? ""),
    status: String(raw.status ?? ""),
    totalHours: parseNumber(raw.total_hours),
    revenue: parseNumber(raw.revenue),
    expenses: parseNumber(raw.expenses),
    fuelExpenses: parseNumber(raw.fuel_expenses),
    repairExpenses: parseNumber(raw.repair_expenses),
  };
}

export function mapEmployeeReportFromApi(
  payload: unknown,
): EmployeeReportItem {
  const raw = (payload ?? {}) as Record<string, unknown>;

  return {
    userId: typeof raw.user_id === "number" ? raw.user_id : 0,
    fullName: String(raw.full_name ?? ""),
    totalAmount: parseNumber(raw.total_amount),
    totalHours: parseNumber(raw.total_hours),
    assignments:
      typeof raw.assignments === "number" ? raw.assignments : 0,
  };
}


