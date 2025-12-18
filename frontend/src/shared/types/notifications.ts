export interface NotificationPreferences {
  orderCreated: boolean;
  statusChanged: boolean;
  paymentReceived: boolean;
  invoiceReady: boolean;
  kassaFull: boolean;
}

export interface NotificationLog {
  id?: number;
  type?: string;
  message?: string;
  createdAt?: Date;
  [key: string]: unknown;
}

export function mapNotificationPreferencesFromApi(
  payload: unknown,
): NotificationPreferences {
  const raw = (payload ?? {}) as Record<string, unknown>;
  return {
    orderCreated:
      typeof raw.order_created === "boolean" ? raw.order_created : true,
    statusChanged:
      typeof raw.status_changed === "boolean" ? raw.status_changed : true,
    paymentReceived:
      typeof raw.payment_received === "boolean" ? raw.payment_received : true,
    invoiceReady:
      typeof raw.invoice_ready === "boolean" ? raw.invoice_ready : true,
    kassaFull: typeof raw.kassa_full === "boolean" ? raw.kassa_full : true,
  };
}

export function mapNotificationPreferencesToApi(
  prefs: NotificationPreferences,
): Record<string, boolean> {
  return {
    order_created: prefs.orderCreated,
    status_changed: prefs.statusChanged,
    payment_received: prefs.paymentReceived,
    invoice_ready: prefs.invoiceReady,
    kassa_full: prefs.kassaFull,
  };
}

export function mapNotificationLogFromApi(payload: unknown): NotificationLog {
  const raw = (payload ?? {}) as Record<string, unknown>;
  const createdRaw = raw.created_at ?? raw.createdAt;
  let createdAt: Date | undefined;
  if (createdRaw instanceof Date) {
    createdAt = createdRaw;
  } else if (
    typeof createdRaw === "string" ||
    typeof createdRaw === "number"
  ) {
    const d = new Date(createdRaw);
    if (!Number.isNaN(d.getTime())) {
      createdAt = d;
    }
  }

  return {
    ...raw,
    createdAt,
  };
}


