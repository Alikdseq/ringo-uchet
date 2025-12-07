from __future__ import annotations

from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone

from catalog.models import Equipment
from orders.models import Order


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания", help_text="Дата и время создания записи")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления", help_text="Дата и время последнего обновления")

    class Meta:
        abstract = True


class PaymentStatus(models.TextChoices):
    PENDING = "pending", "Ожидает"
    SUCCESS = "success", "Успешно"
    FAILED = "failed", "Ошибка"
    REFUNDED = "refunded", "Возвращено"


class PaymentMethod(models.TextChoices):
    CASH = "cash", "Наличные"
    BANK_TRANSFER = "bank_transfer", "Банковский перевод"
    ONLINE = "online", "Онлайн"
    OTHER = "other", "Другое"


class Invoice(TimeStampedModel):
    order = models.OneToOneField(
        Order,
        on_delete=models.CASCADE,
        related_name="invoice",
        verbose_name="Заказ",
        help_text="Заказ, для которого выписан счёт",
    )
    number = models.CharField(
        max_length=50, unique=True, blank=True, verbose_name="Номер счёта", help_text="Уникальный номер счёта"
    )
    payment_status = models.CharField(
        max_length=20,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING,
        verbose_name="Статус оплаты",
        help_text="Статус оплаты счёта",
    )
    pdf_url = models.URLField(blank=True, verbose_name="URL PDF", help_text="URL PDF файла счёта")
    pdf_file = models.FileField(upload_to="invoices/", blank=True, null=True, verbose_name="PDF файл", help_text="PDF файл счёта")
    issued_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата выписки", help_text="Дата выписки счёта")
    due_date = models.DateTimeField(null=True, blank=True, verbose_name="Срок оплаты", help_text="Срок оплаты счёта")
    amount = models.DecimalField(
        max_digits=12, decimal_places=2, default=Decimal("0.00"), verbose_name="Сумма", help_text="Сумма счёта"
    )
    currency = models.CharField(max_length=8, default="RUB", verbose_name="Валюта", help_text="Валюта счёта")
    metadata = models.JSONField(default=dict, blank=True, verbose_name="Метаданные", help_text="Дополнительные метаданные")

    class Meta:
        verbose_name = "Счёт"
        verbose_name_plural = "Счета"

    def __str__(self) -> str:
        return self.number or "Новый счёт"

    def save(self, *args, **kwargs):
        if not self.number:
            self.number = self.generate_number()
        super().save(*args, **kwargs)

    @staticmethod
    def generate_number() -> str:
        prefix = timezone.now().strftime("INV-%Y%m")
        last = Invoice.objects.filter(number__startswith=prefix).order_by("number").last()
        seq = 1
        if last:
            try:
                seq = int(last.number.split("-")[-1]) + 1
            except ValueError:
                seq = 1
        return f"{prefix}-{seq:04d}"


class Expense(TimeStampedModel):
    CATEGORY_CHOICES = [
        ("fuel", "Топливо"),
        ("repair", "Ремонт"),
        ("rent", "Аренда техники"),
        ("other", "Прочее"),
    ]

    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True, related_name="expenses")
    equipment = models.ForeignKey(
        Equipment, on_delete=models.SET_NULL, null=True, blank=True, related_name="expenses"
    )
    reported_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reported_expenses",
    )
    category = models.CharField(max_length=50, choices=CATEGORY_CHOICES, default="other")
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    date = models.DateField()
    comment = models.TextField(blank=True)
    attachment_url = models.URLField(blank=True)

    class Meta:
        verbose_name = "Расход"
        verbose_name_plural = "Расходы"
        ordering = ["-date"]

    def __str__(self) -> str:
        return f"{self.category} {self.amount}"


class SalaryRecord(TimeStampedModel):
    class RateType(models.TextChoices):
        HOURLY = "hourly", "Почасовая"
        FIXED = "fixed", "Фиксированная"
        PERCENT = "percent", "Процентная"

    class SalaryStatus(models.TextChoices):
        PENDING = "pending", "Ожидает"
        APPROVED = "approved", "Одобрена"
        PAID = "paid", "Выплачена"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="salary_records")
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True, related_name="salary_records")
    hours_worked = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal("0.00"))
    rate_type = models.CharField(max_length=20, choices=RateType.choices, default=RateType.FIXED)
    rate_value = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    status = models.CharField(max_length=20, choices=SalaryStatus.choices, default=SalaryStatus.PENDING)
    paid_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        verbose_name = "Запись зарплаты"
        verbose_name_plural = "Записи зарплат"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.user} — {self.amount}"


class Payment(TimeStampedModel):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="payments")
    invoice = models.ForeignKey(Invoice, on_delete=models.SET_NULL, null=True, blank=True, related_name="payments")
    method = models.CharField(max_length=32, choices=PaymentMethod.choices, default=PaymentMethod.BANK_TRANSFER)
    status = models.CharField(max_length=20, choices=PaymentStatus.choices, default=PaymentStatus.PENDING)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    currency = models.CharField(max_length=8, default="RUB")
    transaction_id = models.CharField(max_length=120, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        verbose_name = "Платёж"
        verbose_name_plural = "Платежи"
        ordering = ["-paid_at", "-created_at"]

    def __str__(self) -> str:
        return f"{self.order.number} {self.amount} {self.status}"


class DocumentTemplate(TimeStampedModel):
    class TemplateType(models.TextChoices):
        INVOICE = "invoice", "Счёт"
        ACT = "act", "Акт"
        RECEIPT = "receipt", "Квитанция"

    slug = models.SlugField(max_length=100)
    version = models.PositiveIntegerField(default=1)
    template_type = models.CharField(max_length=20, choices=TemplateType.choices, default=TemplateType.INVOICE)
    template_path = models.CharField(max_length=255, default="invoices/default.html")
    description = models.CharField(max_length=255, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = "Шаблон документа"
        verbose_name_plural = "Шаблоны документов"
        unique_together = ("slug", "version")
        ordering = ("template_type", "-version")

    def __str__(self) -> str:
        return f"{self.get_template_type_display()} {self.slug} v{self.version}"

