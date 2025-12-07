from __future__ import annotations

from django.db import models


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания", help_text="Дата и время создания записи")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления", help_text="Дата и время последнего обновления")

    class Meta:
        abstract = True


class Client(TimeStampedModel):
    name = models.CharField(max_length=255, verbose_name="Название", help_text="Название компании или ФИО клиента")
    contact_person = models.CharField(
        max_length=255, blank=True, verbose_name="Контактное лицо", help_text="ФИО контактного лица"
    )
    phone = models.CharField(max_length=32, verbose_name="Телефон", help_text="Номер телефона")
    email = models.EmailField(blank=True, verbose_name="Email", help_text="Адрес электронной почты")
    address = models.CharField(max_length=500, blank=True, verbose_name="Адрес", help_text="Адрес клиента")
    city = models.CharField(max_length=120, blank=True, verbose_name="Город", help_text="Город")
    geo_lat = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True, verbose_name="Широта", help_text="Географическая широта"
    )
    geo_lng = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True, verbose_name="Долгота", help_text="Географическая долгота"
    )
    billing_details = models.JSONField(
        default=dict, blank=True, verbose_name="Платёжные реквизиты", help_text="Банковские реквизиты клиента"
    )
    inn = models.CharField(max_length=20, blank=True, verbose_name="ИНН", help_text="ИНН организации")
    kpp = models.CharField(max_length=20, blank=True, verbose_name="КПП", help_text="КПП организации")
    notes = models.TextField(blank=True, verbose_name="Примечания", help_text="Дополнительные примечания")
    is_active = models.BooleanField(default=True, verbose_name="Активен", help_text="Клиент активен")

    class Meta:
        verbose_name = "Клиент"
        verbose_name_plural = "Клиенты"
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name

