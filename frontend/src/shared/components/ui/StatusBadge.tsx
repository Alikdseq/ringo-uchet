import React from "react";

export type OrderStatus =
  | "DRAFT"
  | "CREATED"
  | "APPROVED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "CANCELLED"
  | "DELETED";

interface StatusBadgeProps {
  status: OrderStatus | string;
  className?: string;
}

function toDisplayLabel(status: string): string {
  const upper = status.toUpperCase();
  switch (upper) {
    case "DRAFT":
      return "Черновик";
    case "CREATED":
      return "Создана";
    case "APPROVED":
      return "Утверждена";
    case "IN_PROGRESS":
      return "В работе";
    case "COMPLETED":
      return "Завершена";
    case "CANCELLED":
      return "Отменена";
    case "DELETED":
      return "Удалена";
    default:
      return upper;
  }
}

function statusClasses(status: string): string {
  const upper = status.toUpperCase();
  switch (upper) {
    case "DRAFT":
      return "bg-status-draft/10 text-status-draft border-status-draft/30";
    case "CREATED":
      return "bg-status-created/10 text-status-created border-status-created/30";
    case "APPROVED":
      return "bg-status-approved/10 text-status-approved border-status-approved/30";
    case "IN_PROGRESS":
      return "bg-status-in-progress/10 text-status-in-progress border-status-in-progress/30";
    case "COMPLETED":
      return "bg-status-completed/10 text-status-completed border-status-completed/30";
    case "CANCELLED":
      return "bg-status-cancelled/10 text-status-cancelled border-status-cancelled/30";
    case "DELETED":
      return "bg-status-deleted/10 text-status-deleted border-status-deleted/30";
    default:
      return "bg-slate-200 text-slate-700 border-slate-300";
  }
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const base =
    "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold uppercase tracking-wide";
  const color = statusClasses(status);

  return (
    <span className={`${base} ${color} ${className ?? ""}`.trim()}>
      {toDisplayLabel(status)}
    </span>
  );
}


