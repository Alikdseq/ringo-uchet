"use client";

import React, { FormEvent, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { OrdersApi } from "@/shared/api/ordersApi";
import { UsersApi } from "@/shared/api/usersApi";
import { PageHeader } from "@/shared/components/ui/PageHeader";
import { Card } from "@/shared/components/ui/Card";
import { useDebouncedValue } from "@/shared/hooks";
import type { ClientInfo, Order, OrderItem, OrderStatus } from "@/shared/types/orders";
import type { UserInfo } from "@/shared/types/auth";
import { httpClient, AppError } from "@/shared/api/httpClient";
import { CatalogApi } from "@/shared/api/catalogApi";
import type { Equipment, MaterialItem, ServiceItem } from "@/shared/types/catalog";
import type { OrderRequestPayload } from "@/shared/api/ordersApi";

type ClientListItem = ClientInfo;
const ORDER_DRAFT_STORAGE_KEY = "order-create-draft-v1";

function formatUtcWithoutMillis(date: Date): string {
  const iso = date.toISOString();
  return iso.replace(/\.\d+Z$/, "Z");
}

interface SelectedItem extends OrderItem {
  localId: string;
}

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("ru-RU", {
    style: "currency",
    currency: "RUB",
    maximumFractionDigits: 0,
  }).format(value);
}

export default function OrderCreatePage() {
  const router = useRouter();
  const queryClient = useQueryClient();

  // Клиент
  const [clientSearch, setClientSearch] = useState("");
  const debouncedClientSearch = useDebouncedValue(clientSearch, 400);
  const [clients, setClients] = useState<ClientListItem[]>([]);
  const [isLoadingClients, setIsLoadingClients] = useState(false);
  const [selectedClient, setSelectedClient] = useState<ClientListItem | null>(
    null,
  );
  const [newClientName, setNewClientName] = useState("");
  const [newClientPhone, setNewClientPhone] = useState("");
  const [newClientEmail, setNewClientEmail] = useState("");
  const [address, setAddress] = useState("");

  // Описание
  const [description, setDescription] = useState("");

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

  // Финансы
  const [approxTotal, setApproxTotal] = useState<string>("");
  const [approveOnCreate, setApproveOnCreate] = useState(false);

  // Дата начала
  const [startDt, setStartDt] = useState<string>("");

  const [status, setStatus] = useState<OrderStatus>("CREATED");

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Загружаем черновик из localStorage (если есть)
  useEffect(() => {
    if (typeof window === "undefined") return;
    try {
      const raw = window.localStorage.getItem(ORDER_DRAFT_STORAGE_KEY);
      if (!raw) return;
      const draft = JSON.parse(raw) as Partial<{
        selectedClient: ClientListItem | null;
        newClientName: string;
        newClientPhone: string;
        newClientEmail: string;
        address: string;
        description: string;
        operatorIds: number[];
        items: SelectedItem[];
        approxTotal: string;
        approveOnCreate: boolean;
        startDt: string;
      }>;

      if (draft.selectedClient) {
        setSelectedClient(draft.selectedClient);
      }
      if (typeof draft.newClientName === "string") {
        setNewClientName(draft.newClientName);
      }
      if (typeof draft.newClientPhone === "string") {
        setNewClientPhone(draft.newClientPhone);
      }
      if (typeof draft.newClientEmail === "string") {
        setNewClientEmail(draft.newClientEmail);
      }
      if (typeof draft.address === "string") {
        setAddress(draft.address);
      }
      if (typeof draft.description === "string") {
        setDescription(draft.description);
      }
      if (Array.isArray(draft.operatorIds)) {
        setOperatorIds(draft.operatorIds);
      }
      if (Array.isArray(draft.items)) {
        setItems(draft.items as SelectedItem[]);
      }
      if (typeof draft.approxTotal === "string") {
        setApproxTotal(draft.approxTotal);
      }
      if (typeof draft.startDt === "string") {
        setStartDt(draft.startDt);
      }
      if (typeof draft.approveOnCreate === "boolean") {
        setApproveOnCreate(draft.approveOnCreate);
      }
    } catch {
      // Игнорируем битые черновики
    }
  }, []);

  const handleSelectClient = (client: ClientListItem) => {
    setSelectedClient(client);

    // Автоподстановка всех полей по выбранному клиенту
    setNewClientName(client.name ?? "");
    setNewClientPhone(client.phone ?? "");

    if (client.email) {
      setNewClientEmail(client.email);
    } else {
      setNewClientEmail("");
    }

    // Адрес заполняем автоматически, если он есть у клиента
    if (client.address) {
      setAddress(client.address);
    }
  };

  // Если черновик уже содержит выбранного клиента, но поля ещё пустые —
  // один раз подставляем их из клиента (мгновенное заполнение при открытии)
  useEffect(() => {
    if (!selectedClient) return;

    const hasName = newClientName.trim().length > 0;
    const hasPhone = newClientPhone.trim().length > 0;

    if (!hasName) {
      setNewClientName(selectedClient.name ?? "");
    }
    if (!hasPhone) {
      setNewClientPhone(selectedClient.phone ?? "");
    }
    if (!newClientEmail && selectedClient.email) {
      setNewClientEmail(selectedClient.email);
    }
    if (!address && selectedClient.address) {
      setAddress(selectedClient.address);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedClient]);

  useEffect(() => {
    const loadOperators = async () => {
      try {
        const list = await UsersApi.getOperators();
        setOperators(list);
        setOperatorsLoadError(null);
      } catch (err) {
          const message =
          err instanceof Error ? err.message : "Не удалось загрузить операторов";
        setOperatorsLoadError(message);
      }
    };

    void loadOperators();
  }, []);

  useEffect(() => {
    setStatus(approveOnCreate ? "APPROVED" : "CREATED");
  }, [approveOnCreate]);

  // Сохраняем черновик при каждом изменении значимых полей
  useEffect(() => {
    if (typeof window === "undefined") return;

    const isEmpty =
      !selectedClient &&
      !newClientName &&
      !newClientPhone &&
      !newClientEmail &&
      !address &&
      !description &&
      operatorIds.length === 0 &&
      items.length === 0 &&
      !approxTotal &&
      !approveOnCreate &&
      !startDt;

    if (isEmpty) {
      window.localStorage.removeItem(ORDER_DRAFT_STORAGE_KEY);
      return;
    }

    const draft = {
      selectedClient,
      newClientName,
      newClientPhone,
      newClientEmail,
      address,
      description,
      operatorIds,
      items,
      approxTotal,
      approveOnCreate,
      startDt,
    };

    try {
      window.localStorage.setItem(
        ORDER_DRAFT_STORAGE_KEY,
        JSON.stringify(draft),
      );
    } catch {
      // Переполнен localStorage — тихо игнорируем
    }
  }, [
    selectedClient,
    newClientName,
    newClientPhone,
    newClientEmail,
    address,
    description,
    operatorIds,
    items,
    approxTotal,
    approveOnCreate,
    startDt,
  ]);

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
        err instanceof Error ? err.message : "Не удалось загрузить номенклатуру";
      setError(message);
    } finally {
      setIsLoadingCatalog(false);
    }
  };

  const loadClients = async (searchQuery?: string) => {
    setIsLoadingClients(true);
    try {
      const query = searchQuery ?? debouncedClientSearch;
      const clientsList = await CatalogApi.getClients(
        query ? { search: query } : {},
      );
      setClients(clientsList);
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Не удалось загрузить клиентов";
      setError(message);
      setClients([]);
    } finally {
      setIsLoadingClients(false);
    }
  };

  useEffect(() => {
    void loadCatalog();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [catalogType, debouncedCatalogSearch]);

  // Автоматическая загрузка клиентов при изменении поискового запроса
  useEffect(() => {
    void loadClients();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debouncedClientSearch]);

  // Загружаем всех клиентов при первом открытии страницы (если поле поиска пустое)
  useEffect(() => {
    if (clientSearch === "" && clients.length === 0 && !isLoadingClients) {
      void loadClients("");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const toggleOperator = (id: number) => {
    setOperatorIds((prev) =>
      prev.includes(id) ? prev.filter((value) => value !== id) : [...prev, id],
    );
  };

  const generateLocalId = () =>
    typeof window !== "undefined" && window.crypto?.randomUUID
      ? window.crypto.randomUUID()
      : `${Date.now().toString(36)}-${Math.random().toString(16).slice(2)}`;

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

  const itemsTotal = useMemo(
    () => items.reduce((sum, item) => sum + (item.lineTotal ?? 0), 0),
    [items],
  );

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();

    if (!selectedClient && (!newClientName || !newClientPhone)) {
      setError("Укажите клиента: выберите из списка или создайте нового");
      return;
    }
    if (!address.trim()) {
      setError("Заполните адрес");
      return;
    }
    if (!startDt) {
      setError("Укажите дату и время начала");
      return;
    }

    setError(null);
    setIsSubmitting(true);

    try {
      let clientId = selectedClient?.id ?? null;

      if (!clientId) {
        const response = await httpClient.post<ClientListItem>("/clients/", {
          name: newClientName,
          phone: newClientPhone,
          email: newClientEmail || undefined,
          address: address || undefined,
        });
        clientId = response.data.id;
      }

      const start = new Date(startDt);

      const explicitOperatorIds =
        operatorIds.length > 0 ? operatorIds : [];

      const hasItems = items.length > 0;

      const payloadItems = hasItems
        ? items.map((item) => {
            return {
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
            };
          })
        : null;

      const payload: OrderRequestPayload = {
        client_id: clientId,
        address,
        start_dt: formatUtcWithoutMillis(start),
        description,
        status,
      };

      if (explicitOperatorIds.length === 1) {
        payload.operator_id = explicitOperatorIds[0];
      } else if (explicitOperatorIds.length > 1) {
        payload.operator_ids = explicitOperatorIds;
      }

      if (hasItems && payloadItems) {
        payload.items = payloadItems;
      } else if (!hasItems && approxTotal) {
        payload.total_amount = Number(approxTotal);
      }

      const created = await OrdersApi.create(payload);

      // Удаляем локальный черновик и обновляем кэш заявок
      if (typeof window !== "undefined") {
        window.localStorage.removeItem(ORDER_DRAFT_STORAGE_KEY);
      }
      queryClient.setQueryData<Order>(["order", created.id], created);
      // Инвалидируем кэш заявок для всех пользователей, включая операторов
      // Это гарантирует, что заявка сразу появится в списке у назначенного оператора
      void queryClient.invalidateQueries({ queryKey: ["orders"] });
      void queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      void queryClient.invalidateQueries({ queryKey: ["profile", "operator-salary"] });

      // После создания возвращаемся к списку заявок (каталогу)
      router.replace("/orders");
    } catch (err) {
      if (err instanceof AppError && err.status === 400 && err.details) {
        // Пытаемся собрать понятное сообщение из ошибок валидации DRF
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
            : "Не удалось создать заявку, попробуйте позже";
        setError(message);
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section className="space-y-4">
      <PageHeader
        title="Создание заявки"
        subtitle="Форма создания заявки: клиент, адрес, операторы, номенклатура и примерная стоимость."
      />

      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {error}
        </div>
      ) : null}

      <form onSubmit={handleSubmit} className="space-y-4 text-xs">
        <Card className="space-y-4 p-4">
          <h2 className="text-sm font-semibold text-slate-900">
            1. Данные клиента
          </h2>

          <div className="space-y-2">
            <label className="mb-1 block text-xs font-medium uppercase tracking-wide text-slate-600">
              Поиск клиента
            </label>
            <div className="flex gap-2">
              <input
                type="text"
                className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                placeholder="Имя или телефон клиента"
                value={clientSearch}
                onChange={(event) => setClientSearch(event.target.value)}
              />
              <button
                type="button"
                onClick={() => {
                  // При нажатии кнопки используем текущее значение поиска, а не debounced
                  void loadClients(clientSearch);
                }}
                disabled={isLoadingClients}
                className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {isLoadingClients ? "Поиск..." : "Найти"}
              </button>
            </div>
            {isLoadingClients ? (
              <div className="mt-2 rounded-md border border-slate-200 bg-slate-50 p-2 text-xs text-slate-500">
                Загрузка клиентов...
              </div>
            ) : clients.length > 0 ? (
              <ul className="mt-2 max-h-40 space-y-1 overflow-y-auto rounded-md border border-slate-200 bg-slate-50 p-2 text-xs">
                {clients.map((client) => {
                  const active = selectedClient?.id === client.id;
                  return (
                    <li
                      key={client.id}
                      className={`flex cursor-pointer items-center justify-between rounded px-2 py-1.5 transition-colors ${
                        active
                          ? "bg-slate-900 text-white"
                          : "hover:bg-slate-200"
                      }`}
                      onClick={() => handleSelectClient(client)}
                    >
                      <span className="truncate">
                        {client.name} · {client.phone}
                      </span>
                      {active ? (
                        <span className="ml-2 text-xs">✓</span>
                      ) : null}
                    </li>
                  );
                })}
              </ul>
            ) : (clientSearch || debouncedClientSearch) && !isLoadingClients ? (
              <div className="mt-2 rounded-md border border-slate-200 bg-slate-50 p-2 text-xs text-slate-500">
                Клиенты не найдены
              </div>
            ) : null}
          </div>

          <div className="border-t border-dashed border-slate-200 pt-3 text-xs text-slate-500">
            Или создайте нового клиента:
          </div>

          <div className="grid gap-3 md:grid-cols-2">
            <div className="space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                ФИО клиента *
              </label>
              <input
                type="text"
                className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                value={newClientName}
                onChange={(event) => setNewClientName(event.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                Телефон *
              </label>
              <input
                type="tel"
                className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
                value={newClientPhone}
                onChange={(event) => setNewClientPhone(event.target.value)}
              />
            </div>
          </div>
          <div className="space-y-1.5">
            <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
              Email (опционально)
            </label>
            <input
              type="email"
              className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              value={newClientEmail}
              onChange={(event) => setNewClientEmail(event.target.value)}
            />
          </div>

          <div className="space-y-1.5">
            <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
              Адрес *
            </label>
            <textarea
              className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              rows={3}
              value={address}
              onChange={(event) => setAddress(event.target.value)}
            />
          </div>
        </Card>

        <Card className="space-y-4 p-4">
          <h2 className="text-sm font-semibold text-slate-900">
            2. Описание заявки
          </h2>
          <div className="space-y-1.5">
            <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
              Описание (опционально)
            </label>
            <textarea
              className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
              rows={4}
              value={description}
              onChange={(event) => setDescription(event.target.value)}
            />
          </div>
        </Card>

        <Card className="space-y-4 p-4">
          <h2 className="text-sm font-semibold text-slate-900">3. Операторы</h2>

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
          ) : null}
        </Card>

        <Card className="space-y-4 p-4">
          <h2 className="text-sm font-semibold text-slate-900">
            4. Номенклатура (опционально)
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
                считаться только по этим позициям, примерная стоимость ниже
                будет проигнорирована.
              </div>
            </div>
          ) : (
            <p className="text-[11px] text-slate-500">
              Вы можете добавить технику, услуги или материалы. Если номенклатура
              не указана, заявка будет создана с примерной стоимостью.
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
              <span>Добавить</span>
            </button>
          </div>
        </Card>

        <Card className="space-y-4 p-4">
          <h2 className="text-sm font-semibold text-slate-900">
            5. Примерная стоимость и статус
          </h2>
          <div className="grid gap-3 md:grid-cols-2">
            <div className="space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                Примерная стоимость, ₽ (опционально)
              </label>
              <input
                type="number"
                min={0}
                className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
                value={approxTotal}
                onChange={(event) => setApproxTotal(event.target.value)}
              />
              <p className="text-[11px] text-slate-500">
                Можно оставить пустым, если стоимость будет рассчитана позже по
                номенклатуре.
              </p>
            </div>
            <div className="space-y-1.5">
              <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
                Статус при создании
              </label>
              <label className="flex cursor-pointer items-center gap-2 rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-xs text-slate-700 hover:bg-slate-100">
                <input
                  type="checkbox"
                  checked={approveOnCreate}
                  onChange={(event) =>
                    setApproveOnCreate(event.target.checked)
                  }
                  className="h-4 w-4 rounded border-slate-300 text-slate-900 focus:ring-slate-900"
                />
                <span>
                  Одобрить при создании{" "}
                  <span className="text-[11px] text-slate-500">
                    (если включено, заявка сразу будет в статусе «Одобрена»)
                  </span>
                </span>
              </label>
            </div>
          </div>
        </Card>

        <Card className="space-y-4 p-4">
          <h2 className="text-sm font-semibold text-slate-900">
            6. Дата начала
          </h2>
          <div className="space-y-1.5">
            <label className="block text-xs font-medium uppercase tracking-wide text-slate-600">
              Дата и время начала *
            </label>
            <input
              type="datetime-local"
              className="block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 focus:border-slate-900"
              value={startDt}
              onChange={(event) => setStartDt(event.target.value)}
            />
          </div>
        </Card>

        <div className="flex items-center justify-between gap-2 pt-2 text-xs text-slate-500">
          <button
            type="button"
            onClick={() => router.back()}
            className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 shadow-sm hover:bg-slate-50"
            disabled={isSubmitting}
          >
            Назад
          </button>
          <button
            type="submit"
            disabled={isSubmitting}
            className="rounded-md border border-slate-900 bg-slate-900 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isSubmitting ? "Создаём..." : "Создать заявку"}
          </button>
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
    </section>
  );
}


