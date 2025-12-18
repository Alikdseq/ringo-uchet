import type { UserInfo } from "@/shared/types/auth";
import type { MaybePaginated } from "@/shared/api/types";

export type OrderStatus =
  | "DRAFT"
  | "CREATED"
  | "APPROVED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "CANCELLED";

export type OrderItemType = "equipment" | "service" | "material" | "attachment";

export interface ClientInfo {
  id: number;
  name: string;
  contactPerson?: string | null;
  phone: string;
  email?: string | null;
  address?: string | null;
  city?: string | null;
  geoLat?: number | null;
  geoLng?: number | null;
}

export interface OrderItem {
  id?: number | null;
  itemType: OrderItemType;
  refId?: number | null;
  nameSnapshot: string;
  quantity: number;
  unit: string;
  unitPrice: number;
  taxRate: number;
  discount: number;
  fuelExpense?: number | null;
  repairExpense?: number | null;
  metadata: Record<string, unknown>;
  displayQuantity?: string | null;
  displayUnit?: string | null;
  lineTotal?: number | null;
}

export interface OrderStatusLog {
  id: number;
  fromStatus?: string | null;
  toStatus: string;
  actor?: UserInfo | null;
  actorName?: string | null;
  comment: string;
  attachmentUrl?: string | null;
  createdAt: Date;
}

export interface PhotoEvidence {
  id: number;
  order: string;
  uploadedBy?: UserInfo | null;
  photoType: string;
  fileUrl: string;
  gpsLat?: number | null;
  gpsLng?: number | null;
  capturedAt?: Date | null;
  notes: string;
  metadata: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

export interface Order {
  id: string;
  number: string;
  client?: ClientInfo | null;
  clientId?: number | null;
  address: string;
  geoLat?: number | null;
  geoLng?: number | null;
  startDt: Date;
  endDt?: Date | null;
  description: string;
  status: OrderStatus;
  manager?: UserInfo | null;
  managerId?: number | null;
  operator?: UserInfo | null;
  operatorId?: number | null;
  operators?: UserInfo[] | null;
  operatorIds?: number[] | null;
  prepaymentAmount: number;
  prepaymentStatus: string;
  totalAmount: number;
  priceSnapshot?: Record<string, unknown> | null;
  attachments: unknown[];
  meta: Record<string, unknown>;
  createdBy?: UserInfo | null;
  createdAt: Date;
  updatedAt: Date;
  items: OrderItem[];
  statusLogs: OrderStatusLog[];
  photos: PhotoEvidence[];
}

export interface OrderPricePreviewRequest {
  items: OrderItem[];
}

export interface OrderPricePreviewResponse {
  items: Record<string, unknown>[];
  total: number;
  details?: Record<string, unknown> | null;
}

export interface OrderStatusRequestPayload {
  status: OrderStatus;
  comment?: string;
  attachmentUrl?: string | null;
  operatorSalary?: number | null;
  fuelExpense?: number | null;
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

function asObject(input: unknown): Record<string, unknown> {
  if (!input || typeof input !== "object") {
    return {};
  }
  return input as Record<string, unknown>;
}

function normalizeOrderStatus(status: unknown): OrderStatus {
  if (status === "DELETED") return "CANCELLED";
  const raw = String(status ?? "").toUpperCase();
  const allowed: OrderStatus[] = [
    "DRAFT",
    "CREATED",
    "APPROVED",
    "IN_PROGRESS",
    "COMPLETED",
    "CANCELLED",
  ];
  if (allowed.includes(raw as OrderStatus)) {
    return raw as OrderStatus;
  }
  return "DRAFT";
}

function parseClientInfo(value: unknown): ClientInfo | null {
  const obj = asObject(value);
  const id = parseNumber(obj.id, -1);
  if (id <= 0) return null;
  return {
    id,
    name: String(obj.name ?? ""),
    contactPerson:
      obj.contact_person != null
        ? String(obj.contact_person)
        : (obj.contactPerson as string | null | undefined) ?? null,
    phone: String(obj.phone ?? ""),
    email: (obj.email as string | null | undefined) ?? null,
    address: (obj.address as string | null | undefined) ?? null,
    city: (obj.city as string | null | undefined) ?? null,
    geoLat: parseOptionalNumber(obj.geo_lat),
    geoLng: parseOptionalNumber(obj.geo_lng),
  };
}

function parseOrderItem(value: unknown): OrderItem | null {
  const obj = asObject(value);
  const itemTypeRaw = String(
    obj.item_type ?? obj.itemType ?? "equipment",
  ) as OrderItemType;
  const itemType: OrderItemType =
    itemTypeRaw === "service" ||
    itemTypeRaw === "material" ||
    itemTypeRaw === "attachment"
      ? itemTypeRaw
      : "equipment";

  const quantity = parseNumber(obj.quantity, 1);
  const unitPrice = parseNumber(obj.unit_price ?? obj.unitPrice, 0);
  const taxRate = parseNumber(obj.tax_rate ?? obj.taxRate, 0);
  const discount = parseNumber(obj.discount, 0);

  return {
    id:
      typeof obj.id === "number"
        ? obj.id
        : parseOptionalNumber(obj.id as unknown),
    itemType,
    refId:
      typeof obj.ref_id === "number"
        ? obj.ref_id
        : parseOptionalNumber(obj.refId as unknown),
    nameSnapshot: String(obj.name_snapshot ?? obj.nameSnapshot ?? ""),
    quantity,
    unit: String(obj.unit ?? "шт"),
    unitPrice,
    taxRate,
    discount,
    fuelExpense: parseOptionalNumber(obj.fuel_expense),
    repairExpense: parseOptionalNumber(obj.repair_expense),
    metadata: (asObject(obj.metadata) ?? {}) as Record<string, unknown>,
    displayQuantity:
      (obj.display_quantity as string | null | undefined) ??
      (obj.displayQuantity as string | null | undefined) ??
      null,
    displayUnit:
      (obj.display_unit as string | null | undefined) ??
      (obj.displayUnit as string | null | undefined) ??
      null,
    lineTotal: parseOptionalNumber(obj.line_total),
  };
}

function parseStatusLog(value: unknown): OrderStatusLog | null {
  const obj = asObject(value);
  const id = parseNumber(obj.id, -1);
  if (id <= 0) return null;
  return {
    id,
    fromStatus: (obj.from_status as string | null | undefined) ?? null,
    toStatus: String(obj.to_status ?? ""),
    actor: (obj.actor as UserInfo | null | undefined) ?? null,
    actorName: (obj.actor_name as string | null | undefined) ?? null,
    comment: String(obj.comment ?? ""),
    attachmentUrl:
      (obj.attachment_url as string | null | undefined) ?? null,
    createdAt: parseDate(obj.created_at),
  };
}

function parsePhotoEvidence(value: unknown): PhotoEvidence | null {
  const obj = asObject(value);
  const id = parseNumber(obj.id, -1);
  if (id <= 0) return null;
  return {
    id,
    order: String(obj.order ?? ""),
    uploadedBy: (obj.uploaded_by as UserInfo | null | undefined) ?? null,
    photoType: String(obj.photo_type ?? ""),
    fileUrl: String(obj.file_url ?? ""),
    gpsLat: parseOptionalNumber(obj.gps_lat),
    gpsLng: parseOptionalNumber(obj.gps_lng),
    capturedAt: parseOptionalDate(obj.captured_at),
    notes: String(obj.notes ?? ""),
    metadata: asObject(obj.metadata),
    createdAt: parseDate(obj.created_at),
    updatedAt: parseDate(obj.updated_at),
  };
}

export function mapOrderFromApi(payload: unknown): Order {
  const raw = asObject(payload);

  const id = String(raw.id ?? "");
  const number = String(raw.number ?? "");

  const clientRaw = raw.client;
  let client: ClientInfo | null = null;
  let clientId: number | null = null;
  if (clientRaw != null) {
    if (typeof clientRaw === "number") {
      clientId = clientRaw;
    } else {
      client = parseClientInfo(clientRaw);
      clientId =
        typeof (clientRaw as { id?: unknown }).id === "number"
          ? ((clientRaw as { id?: number }).id as number)
          : client?.id ?? null;
    }
  } else if (typeof raw.client_id === "number") {
    clientId = raw.client_id as number;
  }

  const managerRaw = raw.manager;
  let manager: UserInfo | null = null;
  let managerId: number | null = null;
  if (managerRaw != null) {
    if (typeof managerRaw === "number") {
      managerId = managerRaw;
    } else {
      manager = managerRaw as UserInfo;
      managerId =
        typeof (managerRaw as { id?: unknown }).id === "number"
          ? ((managerRaw as { id?: number }).id as number)
          : null;
    }
  } else if (typeof raw.manager_id === "number") {
    managerId = raw.manager_id as number;
  }

  const operatorRaw = raw.operator;
  let operator: UserInfo | null = null;
  let operatorId: number | null = null;
  if (operatorRaw != null) {
    if (typeof operatorRaw === "number") {
      operatorId = operatorRaw;
    } else {
      operator = operatorRaw as UserInfo;
      operatorId =
        typeof (operatorRaw as { id?: unknown }).id === "number"
          ? ((operatorRaw as { id?: number }).id as number)
          : null;
    }
  } else if (typeof raw.operator_id === "number") {
    operatorId = raw.operator_id as number;
  }

  const operatorsRaw = Array.isArray(raw.operators)
    ? (raw.operators as unknown[])
    : null;
  const operators = operatorsRaw
    ? (operatorsRaw.filter(
        (op) => op && typeof op === "object",
      ) as UserInfo[])
    : null;

  const operatorIds = Array.isArray(raw.operator_ids)
    ? (raw.operator_ids as unknown[])
        .map((v) => (typeof v === "number" ? v : null))
        .filter((v): v is number => v !== null)
    : null;

  const createdByRaw = raw.created_by;
  const createdBy =
    createdByRaw && typeof createdByRaw === "object"
      ? (createdByRaw as UserInfo)
      : null;

  const prepaymentAmount = parseNumber(raw.prepayment_amount, 0);
  const totalAmount = parseNumber(raw.total_amount, 0);

  const prepaymentStatus =
    typeof raw.prepayment_status === "string"
      ? raw.prepayment_status
      : "pending";

  const address =
    typeof raw.address === "string"
      ? raw.address
      : raw.address != null
        ? String(raw.address)
        : "";

  const description =
    typeof raw.description === "string"
      ? raw.description
      : raw.description != null
        ? String(raw.description)
        : "";

  const attachments = Array.isArray(raw.attachments)
    ? raw.attachments
    : [];

  const meta =
    (raw.meta && typeof raw.meta === "object"
      ? (raw.meta as Record<string, unknown>)
      : {}) ?? {};

  const itemsRaw = Array.isArray(raw.items) ? raw.items : [];
  const items: OrderItem[] = itemsRaw
    .map((it) => parseOrderItem(it))
    .filter((it): it is OrderItem => it !== null);

  const statusLogsRaw = Array.isArray(raw.status_logs)
    ? raw.status_logs
    : [];
  const statusLogs: OrderStatusLog[] = statusLogsRaw
    .map((log) => parseStatusLog(log))
    .filter((log): log is OrderStatusLog => log !== null);

  const photosRaw = Array.isArray(raw.photos) ? raw.photos : [];
  const photos: PhotoEvidence[] = photosRaw
    .map((p) => parsePhotoEvidence(p))
    .filter((p): p is PhotoEvidence => p !== null);

  return {
    id,
    number,
    client,
    clientId,
    address,
    geoLat: parseOptionalNumber(raw.geo_lat),
    geoLng: parseOptionalNumber(raw.geo_lng),
    startDt: parseDate(raw.start_dt),
    endDt: parseOptionalDate(raw.end_dt),
    description,
    status: normalizeOrderStatus(raw.status),
    manager,
    managerId,
    operator,
    operatorId,
    operators,
    operatorIds,
    prepaymentAmount,
    prepaymentStatus,
    totalAmount,
    priceSnapshot:
      (raw.price_snapshot as Record<string, unknown> | null | undefined) ??
      null,
    attachments: attachments as unknown[],
    meta,
    createdBy,
    createdAt: parseDate(raw.created_at),
    updatedAt: parseDate(raw.updated_at),
    items,
    statusLogs,
    photos,
  };
}

export function mapOrdersFromApi(
  payload: MaybePaginated<Order>,
): Order[] {
  if (Array.isArray(payload)) {
    return payload.map((item) => mapOrderFromApi(item));
  }
  if (
    payload &&
    typeof payload === "object" &&
    Array.isArray((payload as { results?: unknown[] }).results)
  ) {
    return (payload as { results: unknown[] }).results.map((item) =>
      mapOrderFromApi(item),
    );
  }
  return [];
}


