export type EquipmentStatus = "available" | "busy" | "maintenance" | "inactive";

export interface Equipment {
  id: number;
  code: string;
  name: string;
  description: string;
  hourlyRate: number;
  dailyRate?: number | null;
  fuelConsumption?: number | null;
  status: EquipmentStatus;
  photos: string[];
  lastMaintenanceDate?: Date | null;
  attributes: Record<string, unknown>;
}

export interface ServiceCategory {
  id: number;
  name: string;
  description: string;
  sortOrder: number;
}

export interface ServiceItem {
  id: number;
  category: number;
  categoryName?: string | null;
  name: string;
  unit: string;
  price: number;
  defaultDuration?: number | null;
  includedItems: unknown[];
  isActive: boolean;
}

export interface MaterialItem {
  id: number;
  name: string;
  category: string;
  unit: string;
  price: number;
  density?: number | null;
  supplier?: string | null;
  isActive: boolean;
}

export interface Attachment {
  id: number;
  equipment: number;
  equipmentName?: string | null;
  equipmentCode?: string | null;
  name: string;
  pricingModifier: number;
  status: EquipmentStatus;
  metadata: Record<string, unknown>;
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

function parseOptionalNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function parseDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const d = new Date(value);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return null;
}

export function mapEquipmentFromApi(payload: unknown): Equipment {
  const raw = (payload ?? {}) as Record<string, unknown>;
  return {
    id: parseNumber(raw.id, -1),
    code: String(raw.code ?? ""),
    name: String(raw.name ?? ""),
    description: String(raw.description ?? ""),
    hourlyRate: parseNumber(raw.hourly_rate ?? raw.hourlyRate, 0),
    dailyRate: parseOptionalNumber(raw.daily_rate ?? raw.dailyRate),
    fuelConsumption: parseOptionalNumber(
      raw.fuel_consumption ?? raw.fuelConsumption,
    ),
    status: (raw.status as EquipmentStatus) ?? "available",
    photos: Array.isArray(raw.photos) ? (raw.photos as string[]) : [],
    lastMaintenanceDate: parseDate(raw.last_maintenance_date),
    attributes:
      (raw.attributes && typeof raw.attributes === "object"
        ? (raw.attributes as Record<string, unknown>)
        : {}) ?? {},
  };
}

export function mapServiceFromApi(payload: unknown): ServiceItem {
  const raw = (payload ?? {}) as Record<string, unknown>;

  const categoryValue = raw.category;
  let categoryId = 0;
  if (typeof categoryValue === "number") {
    categoryId = categoryValue;
  } else if (
    categoryValue &&
    typeof categoryValue === "object" &&
    "id" in (categoryValue as Record<string, unknown>)
  ) {
    const idValue = (categoryValue as { id?: unknown }).id;
    if (typeof idValue === "number") categoryId = idValue;
  }

  return {
    id: parseNumber(raw.id, -1),
    category: categoryId,
    categoryName:
      (raw.category_name as string | null | undefined) ?? null,
    name: String(raw.name ?? ""),
    unit: String(raw.unit ?? ""),
    price: parseNumber(raw.price, 0),
    defaultDuration: parseOptionalNumber(raw.default_duration),
    includedItems: Array.isArray(raw.included_items)
      ? raw.included_items
      : [],
    isActive:
      typeof raw.is_active === "boolean" ? raw.is_active : Boolean(raw.is_active),
  };
}

export function mapMaterialFromApi(payload: unknown): MaterialItem {
  const raw = (payload ?? {}) as Record<string, unknown>;
  return {
    id: parseNumber(raw.id, -1),
    name: String(raw.name ?? ""),
    category: String(raw.category ?? ""),
    unit: String(raw.unit ?? ""),
    price: parseNumber(raw.price, 0),
    density: parseOptionalNumber(raw.density),
    supplier: (raw.supplier as string | null | undefined) ?? null,
    isActive:
      typeof raw.is_active === "boolean" ? raw.is_active : Boolean(raw.is_active),
  };
}

export function mapAttachmentFromApi(payload: unknown): Attachment {
  const raw = (payload ?? {}) as Record<string, unknown>;
  return {
    id: parseNumber(raw.id, -1),
    equipment: parseNumber(raw.equipment, 0),
    equipmentName:
      (raw.equipment_name as string | null | undefined) ?? null,
    equipmentCode:
      (raw.equipment_code as string | null | undefined) ?? null,
    name: String(raw.name ?? ""),
    pricingModifier: parseNumber(raw.pricing_modifier, 0),
    status: (raw.status as EquipmentStatus) ?? "available",
    metadata:
      (raw.metadata && typeof raw.metadata === "object"
        ? (raw.metadata as Record<string, unknown>)
        : {}) ?? {},
  };
}


