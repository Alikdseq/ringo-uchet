from __future__ import annotations

from django.db import models


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания", help_text="Дата и время создания записи")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления", help_text="Дата и время последнего обновления")

    class Meta:
        abstract = True


class EquipmentStatus(models.TextChoices):
    AVAILABLE = "available", "Доступна"
    BUSY = "busy", "Занята"
    MAINTENANCE = "maintenance", "На обслуживании"
    INACTIVE = "inactive", "Неактивна"


class Equipment(TimeStampedModel):
    code = models.CharField(
        max_length=50, unique=True, verbose_name="Код", help_text="Уникальный код техники"
    )
    name = models.CharField(max_length=255, verbose_name="Название", help_text="Название техники")
    description = models.TextField(blank=True, verbose_name="Описание", help_text="Подробное описание техники")
    hourly_rate = models.DecimalField(
        max_digits=10, decimal_places=2, verbose_name="Почасовая ставка", help_text="Стоимость аренды за час"
    )
    daily_rate = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name="Дневная ставка",
        help_text="Стоимость аренды за день",
    )
    fuel_consumption = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name="Расход топлива",
        help_text="Расход топлива (л/час)",
    )
    status = models.CharField(
        max_length=20,
        choices=EquipmentStatus.choices,
        default=EquipmentStatus.AVAILABLE,
        verbose_name="Статус",
        help_text="Текущий статус техники",
    )
    photos = models.JSONField(default=list, blank=True, verbose_name="Фотографии", help_text="Список фотографий техники")
    last_maintenance_date = models.DateField(
        null=True,
        blank=True,
        verbose_name="Дата последнего обслуживания",
        help_text="Дата последнего технического обслуживания",
    )
    attributes = models.JSONField(default=dict, blank=True, verbose_name="Атрибуты", help_text="Дополнительные атрибуты")

    class Meta:
        verbose_name = "Техника"
        verbose_name_plural = "Техника"
        ordering = ["code"]

    def __str__(self) -> str:
        return f"{self.code} — {self.name}"


class ServiceCategory(TimeStampedModel):
    name = models.CharField(max_length=200, verbose_name="Название", help_text="Название категории услуг")
    description = models.TextField(blank=True, verbose_name="Описание", help_text="Описание категории")
    sort_order = models.PositiveIntegerField(default=0, verbose_name="Порядок сортировки", help_text="Порядок отображения")

    class Meta:
        verbose_name = "Категория услуг"
        verbose_name_plural = "Категории услуг"
        ordering = ["sort_order", "name"]

    def __str__(self) -> str:
        return self.name


class ServiceItem(TimeStampedModel):
    category = models.ForeignKey(
        ServiceCategory,
        on_delete=models.CASCADE,
        related_name="items",
        verbose_name="Категория",
        help_text="Категория услуги",
    )
    name = models.CharField(max_length=200, verbose_name="Название", help_text="Название услуги")
    unit = models.CharField(max_length=32, default="hour", verbose_name="Единица измерения", help_text="Единица измерения")
    price = models.DecimalField(
        max_digits=10, decimal_places=2, null=True, blank=True, verbose_name="Цена", help_text="Цена услуги (необязательно, услуга может не иметь фиксированной цены)"
    )
    default_duration = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True, verbose_name="Длительность по умолчанию", help_text="Длительность по умолчанию"
    )
    included_items = models.JSONField(default=list, blank=True, verbose_name="Включённые элементы", help_text="Список включённых элементов")
    is_active = models.BooleanField(default=True, verbose_name="Активна", help_text="Услуга активна и доступна для заказа")

    class Meta:
        verbose_name = "Услуга"
        verbose_name_plural = "Услуги"
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name


class MaterialItem(TimeStampedModel):
    class MaterialCategory(models.TextChoices):
        SOIL = "soil", "Грунт"
        TOOL = "tool", "Инструмент"
        ATTACHMENT = "attachment", "Навеска"

    name = models.CharField(max_length=200, verbose_name="Название", help_text="Название материала")
    category = models.CharField(
        max_length=20,
        choices=MaterialCategory.choices,
        default=MaterialCategory.SOIL,
        verbose_name="Категория",
        help_text="Категория материала",
    )
    unit = models.CharField(max_length=32, default="m3", verbose_name="Единица измерения", help_text="Единица измерения")
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Цена", help_text="Цена за единицу")
    density = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True, verbose_name="Плотность", help_text="Плотность материала"
    )
    supplier = models.CharField(max_length=255, blank=True, verbose_name="Поставщик", help_text="Поставщик материала")
    is_active = models.BooleanField(default=True, verbose_name="Активен", help_text="Материал активен и доступен для заказа")

    class Meta:
        verbose_name = "Материал"
        verbose_name_plural = "Материалы"
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name


class SoilItem(MaterialItem):
    """Прокси-модель для отображения только грунтов в админке как отдельного раздела."""

    class Meta:
        proxy = True
        verbose_name = "Грунт"
        verbose_name_plural = "Грунт"
        ordering = ["name"]


class ToolItem(MaterialItem):
    """Прокси-модель для отображения только инструментов в админке как отдельного раздела."""

    class Meta:
        proxy = True
        verbose_name = "Инструмент"
        verbose_name_plural = "Инструменты"
        ordering = ["name"]


class AttachmentMaterialItem(MaterialItem):
    """Прокси-модель для отображения только навесок в админке как отдельного раздела номенклатуры."""

    class Meta:
        proxy = True
        verbose_name = "Навеска (каталог)"
        verbose_name_plural = "Навеска (каталог)"
        ordering = ["name"]


class Attachment(TimeStampedModel):
    equipment = models.ForeignKey(
        Equipment,
        on_delete=models.CASCADE,
        related_name="attachments",
        verbose_name="Техника",
        help_text="Техника, к которой относится навеска",
    )
    name = models.CharField(max_length=200, verbose_name="Название", help_text="Название навески")
    pricing_modifier = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        default=0,
        verbose_name="Модификатор цены",
        help_text="Модификатор цены в процентах (например, 10 = +10%)",
    )
    status = models.CharField(
        max_length=20,
        choices=EquipmentStatus.choices,
        default=EquipmentStatus.AVAILABLE,
        verbose_name="Статус",
        help_text="Текущий статус навески",
    )
    metadata = models.JSONField(default=dict, blank=True, verbose_name="Метаданные", help_text="Дополнительные метаданные")

    class Meta:
        verbose_name = "Навеска"
        verbose_name_plural = "Навески"

    def __str__(self) -> str:
        return f"{self.name} ({self.equipment.code})"


class MaintenanceRecord(TimeStampedModel):
    equipment = models.ForeignKey(
        Equipment,
        on_delete=models.CASCADE,
        related_name="maintenance_records",
        verbose_name="Техника",
        help_text="Техника, для которой выполнено обслуживание",
    )
    performed_at = models.DateField(verbose_name="Дата выполнения", help_text="Дата выполнения обслуживания")
    description = models.TextField(blank=True, verbose_name="Описание", help_text="Описание выполненных работ")
    cost = models.DecimalField(
        max_digits=10, decimal_places=2, null=True, blank=True, verbose_name="Стоимость", help_text="Стоимость обслуживания"
    )
    odometer = models.PositiveIntegerField(null=True, blank=True, verbose_name="Пробег", help_text="Пробег на момент обслуживания")
    attachments = models.JSONField(default=list, blank=True, verbose_name="Вложения", help_text="Список прикреплённых файлов")

    class Meta:
        verbose_name = "Запись обслуживания"
        verbose_name_plural = "Записи обслуживания"
        ordering = ["-performed_at"]

    def __str__(self) -> str:
        return f"{self.equipment.code} — {self.performed_at}"

