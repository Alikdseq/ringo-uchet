"use client";

import React, { FormEvent, useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { OrdersApi } from "@/shared/api/ordersApi";
import { UsersApi } from "@/shared/api/usersApi";
import { CatalogApi } from "@/shared/api/catalogApi";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import { Card } from "@/shared/components/ui/Card";
import { useDebouncedValue } from "@/shared/hooks";
import type { Order, OrderItem, OrderStatus } from "@/shared/types/orders";
import type { UserInfo } from "@/shared/types/auth";
import type {
  Equipment,
  MaterialItem,
  ServiceItem,
} from "@/shared/types/catalog";
import { AppError } from "@/shared/api/httpClient";
import type { OrderRequestPayload } from "@/shared/api/ordersApi";

function formatUtcWithoutMillis(date: Date): string {
  const iso = date.toISOString();
  return iso.replace(/\.\d+Z$/, "Z");
}

type SelectedItem = OrderItem & { localId: string };

function generateLocalId(): string {
  if (typeof window !== "undefined" && window.crypto?.randomUUID) {
    return window.crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(16).slice(2)}`;
}

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    maximumFractionDigits: 0,
  }).format(value);
}

export default function OrderEditPage() {
  const params = useParams();
  const router = useRouter();
  const orderId = params?.orderId as string | undefined;
  const queryClient = useQueryClient();

  const { data: order, isLoading, refetch } = useQuery({
    queryKey: ["order-edit", orderId],
    enabled: Boolean(orderId),
    queryFn: () => OrdersApi.get(orderId as string),
  });

  // Основные поля
  const [address, setAddress] = useState("");
  const [startDt, setStartDt] = useState<string>("");
  const [endDt, setEndDt] = useState<string>("");
  const [description, setDescription] = useState<string>("");
  const [prepaymentAmount, setPrepaymentAmount] = useState<string>("");
  const [totalAmount, setTotalAmount] = useState<string>("");
  const [status, setStatus] = useState<OrderStatus>("CREATED");

  // Операторы
  const [operators, setOperators] = useState<UserInfo[]>([]);
  const [operatorIds, setOperatorIds] = useState<number[]>([]);
  const [operatorsLoadError, setOperatorsLoadError] = useState<string | null>(
    null,
  );

  // Номенклатура
  const [items, setItems] = useState<SelectedItem[]>([]);
  const [catalogType, setCatalogType] = useState<
    "equipment" | "services" | "materials"
  >("equipment");
  const [catalogSearch, setCatalogSearch] = useState("");
  const debouncedCatalogSearch = useDebouncedValue(catalogSearch, 300);
  const [equipmentOptions, setEquipmentOptions] = useState<Equipment[]>([]);
  const [serviceOptions, setServiceOptions] = useState<ServiceItem[]>([]);
  const [materialOptions, setMaterialOptions] = useState<MaterialItem[]>([]);
  const [isLoadingCatalog, setIsLoadingCatalog] = useState(false);
  const [isNomenclatureModalOpen, setIsNomenclatureModalOpen] = useState(false);
  const [nomenclatureStep, setNomenclatureStep] = useState<"list" | "form">(
    "list",
  );
  type NomenclatureFormTarget =
    | { type: "equipment"; equipment: Equipment }
    | { type: "service"; service: ServiceItem }
    | { type: "material"; material: MaterialItem };
  const [activeItemForForm, setActiveItemForForm] =
    useState<NomenclatureFormTarget | null>(null);
  const [equipmentShifts, setEquipmentShifts] = useState("1");
  const [equipmentHours, setEquipmentHours] = useState("0");
  const [equipmentFuelExpense, setEquipmentFuelExpense] = useState("");
  const [equipmentRepairExpense, setEquipmentRepairExpense] = useState("");
  const [simpleQuantity, setSimpleQuantity] = useState("1");
  const [simpleDiscount, setSimpleDiscount] = useState("0");

  const itemsTotal = useMemo(
    () => items.reduce((sum, item) => sum + (item.lineTotal ?? 0), 0),
    [items],
  );

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [operatorSalaries, setOperatorSalaries] = useState<
    { operatorId: number; name: string; salary: string }[]
  >([]);
  const [isReceiptLoading, setIsReceiptLoading] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  // Загружаем операторов один раз
  useEffect(() => {
    const loadOperators = async () => {
      try {
        const list = await UsersApi.getOperators();
        setOperators(list);
        setOperatorsLoadError(null);
      } catch (err) {
        const message =
          err instanceof Error
            ? err.message
            : "Не удалось загрузить операторов";
        setOperatorsLoadError(message);
      }
    };

    void loadOperators();
  }, []);

  // Заполняем форму из заявки
  useEffect(() => {
    if (!order) return;

    setAddress(order.address);

    setStartDt(
      order.startDt
        ? new Date(order.startDt).toISOString().slice(0, 16)
        : "",
    );
    setEndDt(
      order.endDt ? new Date(order.endDt).toISOString().slice(0, 16) : "",
    );

    setDescription(order.description);
    setPrepaymentAmount(order.prepaymentAmount.toString());
    setTotalAmount(order.totalAmount.toString());
    setStatus(order.status);

    // Операторы
    const nextOperatorIds: number[] = [];
    if (order.operators && order.operators.length > 0) {
      order.operators.forEach((op) => {
        if (typeof op.id === "number") nextOperatorIds.push(op.id);
      });
    } else if (typeof order.operatorId === "number") {
      nextOperatorIds.push(order.operatorId);
    }
    setOperatorIds(nextOperatorIds);

    // Подготавливаем структуру для ввода зарплат в завершённой заявке
    if (order.status === "COMPLETED") {
      const salaries: { operatorId: number; name: string; salary: string }[] =
        [];
      if (order.operators && order.operators.length > 0) {
        order.operators.forEach((op) => {
          if (typeof op.id !== "number") return;
          const name =
            op.fullNameFromApi ||
            `${op.firstName ?? ""} ${op.lastName ?? ""}`.trim() ||
            op.username ||
            `Оператор #${op.id}`;
          salaries.push({ operatorId: op.id, name, salary: "" });
        });
      } else if (order.operator && typeof order.operator.id === "number") {
        const op = order.operator;
        const name =
          op.fullNameFromApi ||
          `${op.firstName ?? ""} ${op.lastName ?? ""}`.trim() ||
          op.username ||
          `Оператор #${op.id}`;
        salaries.push({ operatorId: op.id, name, salary: "" });
      }
      setOperatorSalaries(salaries);
    } else {
      setOperatorSalaries([]);
    }

    // Номенклатура
    const nextItems: SelectedItem[] = (order.items ?? []).map(
      (item: OrderItem) => ({
        localId: generateLocalId(),
        id: item.id ?? null,
        itemType: item.itemType,
        refId: item.refId ?? null,
        nameSnapshot: item.nameSnapshot,
        quantity: item.quantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        taxRate: item.taxRate,
        discount: item.discount,
        fuelExpense: item.fuelExpense ?? null,
        repairExpense: item.repairExpense ?? null,
        metadata: item.metadata ?? {},
        displayQuantity: item.displayQuantity ?? null,
        displayUnit: item.displayUnit ?? null,
        lineTotal: item.lineTotal ?? null,
      }),
    );
    setItems(nextItems);
  }, [order]);

  const loadCatalog = async () => {
    setIsLoadingCatalog(true);
    try {
      if (catalogType === "equipment") {
        const list = await CatalogApi.getEquipment({
          search: debouncedCatalogSearch || undefined,
          pageSize: 50,
        });
        setEquipmentOptions(list);
      } else if (catalogType === "services") {
        const list = await CatalogApi.getServices({
          search: debouncedCatalogSearch || undefined,
          pageSize: 50,
        });
        setServiceOptions(list);
      } else {
        const list = await CatalogApi.getMaterials({
          search: debouncedCatalogSearch || undefined,
          pageSize: 50,
        });
        setMaterialOptions(list);
      }
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : "Не удалось загрузить номенклатуру";
      setError(message);
    } finally {
      setIsLoadingCatalog(false);
    }
  };

  useEffect(() => {
    void loadCatalog();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [catalogType, debouncedCatalogSearch]);

  const toggleOperator = (id: number) => {
    setOperatorIds((prev) =>
      prev.includes(id) ? prev.filter((value) => value !== id) : [...prev, id],
    );
  };

  const openEquipmentForm = (equipment: Equipment) => {
    setActiveItemForForm({ type: "equipment", equipment });
    setEquipmentShifts("1");
    setEquipmentHours("0");
    setEquipmentFuelExpense("");
    setEquipmentRepairExpense("");
    setNomenclatureStep("form");
  };

  const openServiceForm = (service: ServiceItem) => {
    setActiveItemForForm({ type: "service", service });
    setSimpleQuantity("1");
    setSimpleDiscount("0");
    setNomenclatureStep("form");
  };

  const openMaterialForm = (material: MaterialItem) => {
    setActiveItemForForm({ type: "material", material });
    setSimpleQuantity("1");
    setSimpleDiscount("0");
    setNomenclatureStep("form");
  };

  const handleConfirmItemFromForm = () => {
    if (!activeItemForForm) return;

    if (activeItemForForm.type === "equipment") {
      const { equipment } = activeItemForForm;
      const shifts = Number(equipmentShifts.replace(",", ".")) || 0;
      const hours = Number(equipmentHours.replace(",", ".")) || 0;
      const fuel = Number(equipmentFuelExpense.replace(",", ".")) || 0;
      const repair = Number(equipmentRepairExpense.replace(",", ".")) || 0;

      if (shifts <= 0 && hours <= 0) {
        setError("Укажите количество смен или часов для техники");
        return;
      }

      const hourlyRate = equipment.hourlyRate;
      const dailyRate = equipment.dailyRate ?? 0;

      const totalFromHours = hours * hourlyRate;
      const totalFromShifts = shifts * (dailyRate || hourlyRate);
      const lineTotal = totalFromHours + totalFromShifts;

      const quantity = hours > 0 ? hours : shifts;
      const unit = hours > 0 ? "ч" : "смена";

      const next: SelectedItem = {
        localId: generateLocalId(),
        id: undefined,
        itemType: "equipment",
        refId: equipment.id,
        nameSnapshot: equipment.name,
        quantity,
        unit,
        unitPrice: hourlyRate,
        taxRate: 0,
        discount: 0,
        fuelExpense: fuel > 0 ? fuel : null,
        repairExpense: repair > 0 ? repair : null,
        metadata: {
          shifts,
          hours,
          hourlyRate: equipment.hourlyRate,
          dailyRate: equipment.dailyRate ?? null,
        },
        displayQuantity: null,
        displayUnit: null,
        lineTotal,
      };

      setItems((prev) => [...prev, next]);
    } else if (activeItemForForm.type === "service") {
      const { service } = activeItemForForm;
      const quantity = Number(simpleQuantity.replace(",", ".")) || 0;
      const discount = Number(simpleDiscount.replace(",", ".")) || 0;

      if (quantity <= 0) {
        setError("Укажите количество для услуги");
        return;
      }

      const unitPrice = service.price;
      const gross = quantity * unitPrice;
      const afterDiscount = gross * (1 - Math.max(discount, 0) / 100);
      const lineTotal = afterDiscount;

      const next: SelectedItem = {
        localId: generateLocalId(),
        id: undefined,
        itemType: "service",
        refId: service.id,
        nameSnapshot: service.name,
        quantity,
        unit: service.unit,
        unitPrice,
        taxRate: 0,
        discount: Math.max(discount, 0),
        fuelExpense: null,
        repairExpense: null,
        metadata: {},
        displayQuantity: null,
        displayUnit: null,
        lineTotal,
      };

      setItems((prev) => [...prev, next]);
    } else if (activeItemForForm.type === "material") {
      const { material } = activeItemForForm;
      const quantity = Number(simpleQuantity.replace(",", ".")) || 0;
      const discount = Number(simpleDiscount.replace(",", ".")) || 0;

      if (quantity <= 0) {
        setError("Укажите количество для материала");
        return;
      }

      const unitPrice = material.price;
      const gross = quantity * unitPrice;
      const afterDiscount = gross * (1 - Math.max(discount, 0) / 100);
      const lineTotal = afterDiscount;

      const next: SelectedItem = {
        localId: generateLocalId(),
        id: undefined,
        itemType: "material",
        refId: material.id,
        nameSnapshot: material.name,
        quantity,
        unit: material.unit,
        unitPrice,
        taxRate: 0,
        discount: Math.max(discount, 0),
        fuelExpense: null,
        repairExpense: null,
        metadata: {},
        displayQuantity: null,
        displayUnit: null,
        lineTotal,
      };

      setItems((prev) => [...prev, next]);
    }

    setIsNomenclatureModalOpen(false);
    setNomenclatureStep("list");
    setActiveItemForForm(null);
  };

  const handleRemoveItem = (localId: string) => {
    setItems((prev) => prev.filter((item) => item.localId !== localId));
  };

  function getNextStageAction(
    currentStatus: OrderStatus | undefined,
  ): { label: string; type: "status" | "complete"; nextStatus?: OrderStatus } | null {
    if (!currentStatus) return null;
    switch (currentStatus) {
      case "DRAFT":
        return { label: "Создать", type: "status", nextStatus: "CREATED" };
      case "CREATED":
        return { label: "Одобрить", type: "status", nextStatus: "APPROVED" };
      case "APPROVED":
        return {
          label: "Начать работу",
          type: "status",
          nextStatus: "IN_PROGRESS",
        };
      case "IN_PROGRESS":
        return { label: "Завершить", type: "complete" };
      default:
        return null;
    }
  }

  const saveOrder = async (): Promise<Order | null> => {
    if (!orderId || !order) return null;

    if (!address.trim()) {
      setError("Адрес не может быть пустым");
      return null;
    }

    if (!startDt) {
      setError("Укажите дату и время начала");
      return null;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      const start = startDt ? new Date(startDt) : null;
      const end = endDt ? new Date(endDt) : null;
      const explicitOperatorIds =
        operatorIds.length > 0 ? operatorIds : [];

      const hasItems = items.length > 0;
      const hadItemsInitially = (order.items ?? []).length > 0;

      const payloadItems = hasItems
        ? items.map((item) => ({
            item_type: item.itemType,
            ref_id: item.refId,
            name_snapshot: item.nameSnapshot,
            quantity: item.quantity,
            unit: item.unit,
            unit_price: item.unitPrice,
            tax_rate: item.taxRate,
            discount: item.discount,
            fuel_expense: item.fuelExpense,
            repair_expense: item.repairExpense,
            metadata: item.metadata,
          }))
        : [];

      const payload: Partial<OrderRequestPayload> = {
        address,
        description,
      };

      if (order.clientId != null) {
        payload.client_id = order.clientId;
      }

      if (start) {
        payload.start_dt = formatUtcWithoutMillis(start);
      }
      if (end) {
        payload.end_dt = formatUtcWithoutMillis(end);
      }

      if (prepaymentAmount.trim() !== "") {
        payload.prepayment_amount = Number(prepaymentAmount);
      }

      if (hasItems) {
        payload.items = payloadItems;
      } else if (!hasItems && hadItemsInitially) {
        // Пользователь удалил все позиции
        payload.items = [];
      }

      if (!hasItems && totalAmount.trim() !== "") {
        payload.total_amount = Number(totalAmount);
      }

      if (explicitOperatorIds.length === 1) {
        payload.operator_id = explicitOperatorIds[0];
        // Очищаем список множественных операторов
        payload.operator_ids = [];
      } else if (explicitOperatorIds.length > 1) {
        payload.operator_ids = explicitOperatorIds;
        payload.operator_id = null;
      } else {
        // Убираем всех операторов
        payload.operator_id = null;
        payload.operator_ids = [];
      }

      const updated = await OrdersApi.update(orderId, payload);

      // При завершённой заявке дополнительно сохраняем зарплаты операторов
      if (updated.status === "COMPLETED" && operatorSalaries.length > 0) {
        const salariesPayload = operatorSalaries
          .map((entry) => ({
            operator_id: entry.operatorId,
            salary: entry.salary ? Number(entry.salary) : 0,
          }))
          .filter((item) => item.salary > 0);

        if (salariesPayload.length > 0) {
          await OrdersApi.updateSalaries(orderId, {
            operator_salaries: salariesPayload,
          });
          // После обновления зарплат инвалидируем отчёты
          void queryClient.invalidateQueries({ queryKey: ["reports"] });
          void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
        }
      }

      // Обновляем кэш деталей и списка заявок
      queryClient.setQueryData<Order>(["order", orderId], updated);
      void queryClient.invalidateQueries({ queryKey: ["orders"] });

      return updated;
    } catch (err) {
      if (err instanceof AppError && err.status === 400 && err.details) {
        const details = err.details as Record<string, unknown>;
        const fieldMessages: string[] = [];
        for (const [field, value] of Object.entries(details)) {
          if (Array.isArray(value)) {
            fieldMessages.push(
              `${field}: ${value
                .map((v) => (typeof v === "string" ? v : ""))
                .filter(Boolean)
                .join(" ")}`,
            );
          } else if (typeof value === "string") {
            fieldMessages.push(`${field}: ${value}`);
          }
        }
        setError(
          fieldMessages.length > 0
            ? `Проверьте данные формы: ${fieldMessages.join("; ")}`
            : err.message || "Неверные данные запроса",
        );
      } else {
        const message =
          err instanceof Error
            ? err.message
            : "Не удалось сохранить изменения, попробуйте позже";
        setError(message);
      }
    } finally {
      setIsSubmitting(false);
    }

    return null;
  };

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    await saveOrder();
  };

  const handleBack = async () => {
    const updated = await saveOrder();
    if (updated || !orderId) {
      router.back();
    }
  };

  const handleDelete = async () => {
    if (!order) return;
    setIsDeleting(true);
    try {
      await OrdersApi.delete(order.id);
      void queryClient.invalidateQueries({ queryKey: ["orders"] });
      void queryClient.invalidateQueries({ queryKey: ["reports"] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      setIsDeleteModalOpen(false);
      router.replace("/orders");
    } finally {
      setIsDeleting(false);
    }
  };

  const handleStageAction = async () => {
    if (!orderId || !order) return;

    const saved = await saveOrder();
    if (!saved) return;

    const action = getNextStageAction(saved.status);
    if (!action) return;

    if (action.type === "status" && action.nextStatus) {
      const updated = await OrdersApi.changeStatus(orderId, { status: action.nextStatus });
      // Немедленно обновляем кэш заявки для всех возможных ключей
      queryClient.setQueryData<Order>(["order", orderId], updated);
      queryClient.setQueryData<Order>(["order-edit", orderId], updated);
      queryClient.setQueryData<Order>(["order-complete", orderId], updated);
      setStatus(action.nextStatus);
      // Обновляем локальное состояние заявки через refetch
      await refetch();
      // Инвалидируем списки и отчёты в фоне
      void queryClient.invalidateQueries({ queryKey: ["orders"] });
      void queryClient.invalidateQueries({ queryKey: ["reports"] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      // НЕ перенаправляем - остаёмся на странице редактирования
    } else if (action.type === "complete") {
      router.push(`/orders/${saved.id}/complete`);
    }
  };

  const handleDownloadReceipt = async () => {
    if (!order) return;
    try {
      setIsReceiptLoading(true);
      const blob = await OrdersApi.getReceiptPdf(order.id);
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `receipt_${order.number}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(err);
    } finally {
      setIsReceiptLoading(false);
    }
  };

  return (
    <section className="space-y-4">
      <PageHeader
        title={order ? `Редактирование заявки ${order.number}` : "Загрузка..."}
        subtitle="Изменение адреса, дат, операторов и номенклатуры заявки на любом этапе."
      />

      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {error}
        </div>
      ) : null}

      <form onSubmit={handleSubmit} className="space-y-4 text-xs">
        <Card className="p-4 space-y-3">
          <h2 className="mb-1 text-sm font-semibold text-slate-900">
            Основные поля
          </h2>

          {isLoading && !order ? (
            <div className="text-xs text-slate-500">
              Загружаем данные заявки...
            </div>
          ) : null}

          {order ? (
            <div className="space-y-3">
              <div className="space-y-1.5">
                <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                  Адрес
                </label>
                <textarea
                  className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                  rows={3}
                  value={address}
                  onChange={(event) => setAddress(event.target.value)}
                />
              </div>

              <div className="grid gap-3 md:grid-cols-2">
                <div className="space-y-1.5">
                  <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                    Начало
                  </label>
                  <input
                    type="datetime-local"
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                    value={startDt}
                    onChange={(event) => setStartDt(event.target.value)}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                    Окончание
                  </label>
                  <input
                    type="datetime-local"
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                    value={endDt}
                    onChange={(event) => setEndDt(event.target.value)}
                  />
                </div>
              </div>

              <div className="grid gap-3 md:grid-cols-3">
                <div className="space-y-1.5">
                  <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                    Предоплата, ₽
                  </label>
                  <input
                    type="number"
                    min={0}
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                    value={prepaymentAmount}
                    onChange={(event) =>
                      setPrepaymentAmount(event.target.value)
                    }
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                    Сумма, ₽
                  </label>
                  <input
                    type="number"
                    min={0}
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                    value={totalAmount}
                    onChange={(event) => setTotalAmount(event.target.value)}
                    disabled={items.length > 0}
                  />
                  {items.length > 0 ? (
                    <p className="text-[11px] text-slate-500">
                      Итоговая сумма будет пересчитана автоматически по
                      номенклатуре.
                    </p>
                  ) : null}
                </div>
                <div className="space-y-1.5">
                  <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                    Статус
                  </label>
                  <select
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                    value={status}
                    onChange={(event) =>
                      setStatus(event.target.value as OrderStatus)
                    }
                    disabled
                  >
                    <option value="DRAFT">Черновик</option>
                    <option value="CREATED">Создана</option>
                    <option value="APPROVED">Утверждена</option>
                    <option value="IN_PROGRESS">В работе</option>
                    <option value="COMPLETED">Завершена</option>
                    <option value="CANCELLED">Отменена</option>
                  </select>
                </div>
              </div>
            </div>
          ) : null}
        </Card>

        <Card className="p-4 space-y-3">
          <h2 className="text-sm font-semibold text-slate-900">Операторы</h2>

          {operatorsLoadError ? (
            <div className="rounded-md border border-yellow-200 bg-yellow-50 px-3 py-2 text-[11px] text-yellow-800">
              Не удалось загрузить список операторов. Попробуйте обновить
              страницу или повторить позже.
            </div>
          ) : null}

          {operators.length > 0 ? (
            <div className="grid gap-2 md:grid-cols-2">
              {operators.map((operator) => {
                const checked = operatorIds.includes(operator.id);
                const name =
                  `${operator.firstName ?? ""} ${operator.lastName ?? ""}`.trim() ||
                  operator.fullNameFromApi ||
                  operator.username ||
                  `Оператор #${operator.id}`;

                return (
                  <label
                    key={operator.id}
                    className="flex cursor-pointer items-center justify-between gap-3 rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-xs hover:bg-slate-100"
                  >
                    <div>
                      <div className="font-medium text-slate-900">{name}</div>
                      {operator.phone ? (
                        <div className="text-[11px] text-slate-500">
                          {operator.phone}
                        </div>
                      ) : null}
                    </div>
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggleOperator(operator.id)}
                      className="h-4 w-4 rounded border-slate-300 text-slate-900 focus:ring-slate-900"
                    />
                  </label>
                );
              })}
            </div>
          ) : (
            <p className="text-[11px] text-slate-500">
              Операторы не загружены или отсутствуют.
            </p>
          )}
        </Card>

        <Card className="space-y-4 p-4">
          <h2 className="text-sm font-semibold text-slate-900">
            Номенклатура заказа
          </h2>

          {items.length > 0 ? (
            <div className="space-y-1 rounded-md border border-slate-200 bg-slate-50 p-2">
              {items.map((item) => (
                <div
                  key={item.localId}
                  className="flex items-center justify-between gap-3 rounded-md bg-white px-2 py-1 text-xs shadow-sm"
                >
                  <div className="space-y-0.5">
                    <div className="font-medium text-slate-900">
                      {item.nameSnapshot}
                    </div>
                    <div className="text-[11px] text-slate-500">
                      {item.quantity} {item.unit} ×{" "}
                      {formatCurrency(item.unitPrice)}{" "}
                      {item.discount
                        ? `· скидка ${item.discount.toFixed(0)}%`
                        : null}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="text-xs font-semibold text-slate-900">
                      {formatCurrency(item.lineTotal ?? 0)}
                    </div>
                    <button
                      type="button"
                      onClick={() => handleRemoveItem(item.localId)}
                      className="rounded-full border border-slate-200 bg-white px-2 py-0.5 text-[11px] text-slate-500 hover:bg-slate-100"
                    >
                      ×
                    </button>
                  </div>
                </div>
              ))}
              <div className="border-t border-dashed border-slate-200 pt-1 text-[11px] text-slate-600">
                Итого по номенклатуре:{" "}
                <span className="font-semibold">
                  {formatCurrency(itemsTotal)}
                </span>
                . Если номенклатура указана, итоговая стоимость заявки будет
                считаться только по этим позициям.
              </div>
            </div>
          ) : (
            <p className="text-[11px] text-slate-500">
              Сейчас у заявки нет номенклатуры. Вы можете добавить технику,
              услуги или материалы, либо работать только с общей суммой.
            </p>
          )}

          <div className="pt-2">
            <button
              type="button"
              onClick={() => {
                setIsNomenclatureModalOpen(true);
                setNomenclatureStep("list");
                setActiveItemForForm(null);
              }}
              className="inline-flex items-center rounded-md bg-sky-500 px-4 py-2 text-xs font-medium text-white shadow-sm hover:bg-sky-600"
            >
              <span className="mr-1 text-sm">＋</span>
              <span>Добавить позицию</span>
            </button>
          </div>
        </Card>

        {order && order.status === "COMPLETED" && operatorSalaries.length > 0 ? (
          <Card className="space-y-3 p-4">
            <h2 className="text-sm font-semibold text-slate-900">
              Зарплата операторам
            </h2>
            <p className="text-[11px] text-slate-500">
              Укажите или скорректируйте зарплату для операторов по этой завершённой
              заявке. При сохранении изменения автоматически попадут в отчёты.
            </p>
            <div className="space-y-2">
              {operatorSalaries.map((entry, index) => (
                <div key={entry.operatorId} className="space-y-1.5">
                  <label className="block text-[11px] font-medium text-slate-700">
                    ЗП для {entry.name} (₽)
                  </label>
                  <input
                    type="number"
                    min={0}
                    step="0.01"
                    value={entry.salary}
                    onChange={(event) => {
                      const value = event.target.value;
                      setOperatorSalaries((prev) =>
                        prev.map((item, i) =>
                          i === index ? { ...item, salary: value } : item,
                        ),
                      );
                    }}
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                  />
                </div>
              ))}
            </div>
          </Card>
        ) : null}

        <div className="flex flex-col gap-2 pt-2 text-xs text-slate-500">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <button
              type="button"
              onClick={() => {
                void handleBack();
              }}
              className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50"
              disabled={isSubmitting}
            >
              Назад
            </button>

            <div className="flex flex-1 items-center justify-end gap-2">
              {order ? (
                <button
                  type="button"
                  onClick={() => setIsDeleteModalOpen(true)}
                  className="rounded-md border border-red-300 bg-red-50 px-3 py-1.5 text-xs font-medium text-red-700 shadow-sm hover:bg-red-100"
                  disabled={isSubmitting}
                >
                  Удалить
                </button>
              ) : null}

              {order && order.status === "COMPLETED" ? (
                <button
                  type="button"
                  onClick={() => {
                    void handleDownloadReceipt();
                  }}
                  disabled={isReceiptLoading || isSubmitting}
                  className="rounded-md bg-emerald-600 px-4 py-2 text-xs font-semibold text-white shadow-sm hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isReceiptLoading ? "Формируем чек..." : "Получить чек"}
                </button>
              ) : null}

              {order ? (
                (() => {
                  const action = getNextStageAction(order.status);
                  if (!action) return null;
                  return (
                    <button
                      type="button"
                      onClick={() => {
                        void handleStageAction();
                      }}
                      disabled={isSubmitting}
                      className="rounded-md border border-slate-900 bg-slate-900 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {action.label}
                    </button>
                  );
                })()
              ) : null}
            </div>
          </div>
        </div>
      </form>

      {isNomenclatureModalOpen ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-3">
          <div className="flex max-h-[80vh] w-full max-w-xl flex-col overflow-hidden rounded-lg bg-white p-4 shadow-lg">
            {nomenclatureStep === "list" ? (
              <>
                <div className="mb-3 flex items-center justify-between">
                  <h2 className="text-sm font-semibold text-slate-900">
                    Выбор номенклатуры
                  </h2>
                  <button
                    type="button"
                    onClick={() => setIsNomenclatureModalOpen(false)}
                    className="text-xs text-slate-500 hover:text-slate-700"
                  >
                    Закрыть
                  </button>
                </div>

                <div className="mb-3 flex gap-2 text-xs">
                  <button
                    type="button"
                    onClick={() => setCatalogType("equipment")}
                    className={`flex-1 rounded-full px-3 py-1 font-medium ${
                      catalogType === "equipment"
                        ? "bg-sky-500 text-white"
                        : "bg-slate-100 text-slate-700"
                    }`}
                  >
                    Техника
                  </button>
                  <button
                    type="button"
                    onClick={() => setCatalogType("services")}
                    className={`flex-1 rounded-full px-3 py-1 font-medium ${
                      catalogType === "services"
                        ? "bg-sky-500 text-white"
                        : "bg-slate-100 text-slate-700"
                    }`}
                  >
                    Услуги
                  </button>
                  <button
                    type="button"
                    onClick={() => setCatalogType("materials")}
                    className={`flex-1 rounded-full px-3 py-1 font-medium ${
                      catalogType === "materials"
                        ? "bg-sky-500 text-white"
                        : "bg-slate-100 text-slate-700"
                    }`}
                  >
                    Материалы
                  </button>
                </div>

                <div className="mb-3 flex gap-2 text-xs">
                  <input
                    type="text"
                    value={catalogSearch}
                    onChange={(event) => setCatalogSearch(event.target.value)}
                    placeholder="Поиск по названию"
                    className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                  />
                  <button
                    type="button"
                    onClick={() => {
                      void loadCatalog();
                    }}
                    disabled={isLoadingCatalog}
                    className="inline-flex items-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {isLoadingCatalog ? "..." : "Найти"}
                  </button>
                </div>

                <div className="flex-1 space-y-2 overflow-y-auto text-xs">
                  {(catalogType === "equipment"
                    ? equipmentOptions
                    : catalogType === "services"
                      ? serviceOptions
                      : materialOptions
                  ).map((item) => {
                    if (catalogType === "equipment") {
                      const eq = item as Equipment;
                      return (
                        <div
                          key={eq.id}
                          className="flex items-center justify-between rounded-md border border-slate-200 bg-slate-50 px-3 py-2"
                        >
                          <div className="space-y-0.5">
                            <div className="font-semibold text-slate-900">
                              {eq.name}
                            </div>
                            <div className="text-[11px] text-slate-500">
                              Код {eq.code} · {eq.hourlyRate.toFixed(0)} ₽/час
                              {eq.dailyRate != null
                                ? ` · ${eq.dailyRate.toFixed(0)} ₽/смена`
                                : ""}
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => openEquipmentForm(eq)}
                            className="rounded-full bg-sky-500 px-3 py-1 text-xs font-medium text-white hover:bg-sky-600"
                          >
                            Добавить
                          </button>
                        </div>
                      );
                    }
                    if (catalogType === "services") {
                      const service = item as ServiceItem;
                      return (
                        <div
                          key={service.id}
                          className="flex items-center justify-between rounded-md border border-slate-200 bg-slate-50 px-3 py-2"
                        >
                          <div className="space-y-0.5">
                            <div className="font-semibold text-slate-900">
                              {service.name}
                            </div>
                            <div className="text-[11px] text-slate-500">
                              {service.unit} ·{" "}
                              {formatCurrency(service.price)}
                            </div>
                          </div>
                          <button
                            type="button"
                            onClick={() => openServiceForm(service)}
                            className="rounded-full bg-sky-500 px-3 py-1 text-xs font-medium text-white hover:bg-sky-600"
                          >
                            Добавить
                          </button>
                        </div>
                      );
                    }
                    const material = item as MaterialItem;
                    return (
                      <div
                        key={material.id}
                        className="flex items-center justify-between rounded-md border border-slate-200 bg-slate-50 px-3 py-2"
                      >
                        <div className="space-y-0.5">
                          <div className="font-semibold text-slate-900">
                            {material.name}
                          </div>
                          <div className="text-[11px] text-slate-500">
                            {material.unit} ·{" "}
                            {formatCurrency(material.price)}
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => openMaterialForm(material)}
                          className="rounded-full bg-sky-500 px-3 py-1 text-xs font-medium text-white hover:bg-sky-600"
                        >
                          Добавить
                        </button>
                      </div>
                    );
                  })}

                  {!isLoadingCatalog &&
                  (catalogType === "equipment"
                    ? equipmentOptions.length === 0
                    : catalogType === "services"
                      ? serviceOptions.length === 0
                      : materialOptions.length === 0) ? (
                    <div className="rounded-md border border-dashed border-slate-200 bg-slate-50 px-3 py-3 text-center text-[11px] text-slate-500">
                      Позиции не найдены. Измените параметры поиска.
                    </div>
                  ) : null}
                </div>

                <div className="mt-3 flex justify-end">
                  <button
                    type="button"
                    onClick={() => setIsNomenclatureModalOpen(false)}
                    className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                  >
                    Отмена
                  </button>
                </div>
              </>
            ) : activeItemForForm ? (
              <>
                <div className="mb-3 flex items-center justify-between">
                  <h2 className="text-sm font-semibold text-slate-900">
                    Добавить:{" "}
                    {activeItemForForm.type === "equipment"
                      ? activeItemForForm.equipment.name
                      : activeItemForForm.type === "service"
                        ? activeItemForForm.service.name
                        : activeItemForForm.material.name}
                  </h2>
                  <button
                    type="button"
                    onClick={() => setNomenclatureStep("list")}
                    className="text-xs text-slate-500 hover:text-slate-700"
                  >
                    Назад
                  </button>
                </div>

                {activeItemForForm.type === "equipment" ? (
                  <div className="space-y-3 text-xs">
                    <div className="space-y-1.5">
                      <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                        Количество смен
                      </label>
                      <input
                        type="number"
                        min={0}
                        value={equipmentShifts}
                        onChange={(event) =>
                          setEquipmentShifts(event.target.value)
                        }
                        className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                        Количество часов
                      </label>
                      <input
                        type="number"
                        min={0}
                        value={equipmentHours}
                        onChange={(event) =>
                          setEquipmentHours(event.target.value)
                        }
                        className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                        Расходы на топливо (₽)
                      </label>
                      <input
                        type="number"
                        min={0}
                        value={equipmentFuelExpense}
                        onChange={(event) =>
                          setEquipmentFuelExpense(event.target.value)
                        }
                        className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                      />
                      <p className="text-[11px] text-slate-500">Опционально</p>
                    </div>
                    <div className="space-y-1.5">
                      <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                        Расходы на ремонт техники (₽)
                      </label>
                      <input
                        type="number"
                        min={0}
                        value={equipmentRepairExpense}
                        onChange={(event) =>
                          setEquipmentRepairExpense(event.target.value)
                        }
                        className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                      />
                      <p className="text-[11px] text-slate-500">Опционально</p>
                    </div>
                    <div className="mt-2 text-[11px] text-slate-500">
                      Цена за смену:{" "}
                      {formatCurrency(
                        activeItemForForm.equipment.dailyRate ??
                          activeItemForForm.equipment.hourlyRate,
                      )}{" "}
                      · Цена за час:{" "}
                      {formatCurrency(activeItemForForm.equipment.hourlyRate)}
                    </div>
                  </div>
                ) : (
                  <div className="space-y-3 text-xs">
                    <div className="space-y-1.5">
                      <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                        Количество{" "}
                        {activeItemForForm.type === "material"
                          ? `(${activeItemForForm.material.unit})`
                          : `(${activeItemForForm.service.unit})`}
                      </label>
                      <input
                        type="number"
                        min={0}
                        step="0.1"
                        value={simpleQuantity}
                        onChange={(event) =>
                          setSimpleQuantity(event.target.value)
                        }
                        className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="block text-[11px] font-medium uppercase tracking-wide text-slate-600">
                        Скидка (%)
                      </label>
                      <input
                        type="number"
                        min={0}
                        max={100}
                        value={simpleDiscount}
                        onChange={(event) =>
                          setSimpleDiscount(event.target.value)
                        }
                        className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                      />
                    </div>
                  </div>
                )}

                <div className="mt-4 flex justify-end gap-2 text-xs">
                  <button
                    type="button"
                    onClick={() => setIsNomenclatureModalOpen(false)}
                    className="rounded-md border border-slate-300 bg-white px-3 py-1.5 font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                  >
                    Отмена
                  </button>
                  <button
                    type="button"
                    onClick={handleConfirmItemFromForm}
                    className="rounded-md bg-sky-500 px-3 py-1.5 font-medium text-white shadow-sm hover:bg-sky-600"
                  >
                    Добавить
                  </button>
                </div>
              </>
            ) : null}
          </div>
        </div>
      ) : null}

      {order && isDeleteModalOpen ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-3">
          <div className="w-full max-w-sm rounded-lg bg-white p-4 text-xs shadow-lg">
            <h2 className="mb-2 text-sm font-semibold text-slate-900">
              Удалить заявку
            </h2>
            <p className="mb-3 text-[11px] text-slate-600">
              Вы действительно хотите удалить заявку {order.number}? Это действие
              нельзя будет отменить.
            </p>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setIsDeleteModalOpen(false)}
                disabled={isDeleting}
                className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
              >
                Отмена
              </button>
              <button
                type="button"
                onClick={() => {
                  void handleDelete();
                }}
                disabled={isDeleting}
                className="rounded-md border border-red-500 bg-red-500 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-red-600 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {isDeleting ? "Удаляем..." : "Удалить"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  );
}

