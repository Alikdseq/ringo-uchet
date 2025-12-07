from __future__ import annotations

import csv
from datetime import datetime
from io import StringIO

from django.contrib import admin, messages
from django.http import HttpResponse

from finance.models import Invoice
from .models import Order, OrderItem, OrderStatus, OrderStatusLog, PhotoEvidence


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ("item_type", "name_snapshot", "quantity", "unit_price", "discount", "fuel_expense", "repair_expense")
    verbose_name = "Позиция заказа"
    verbose_name_plural = "Позиции заказа"


class PhotoEvidenceInline(admin.TabularInline):
    model = PhotoEvidence
    extra = 0
    readonly_fields = ("photo_type", "file_url", "gps_lat", "gps_lng", "captured_at")
    verbose_name = "Фото-доказательство"
    verbose_name_plural = "Фото-доказательства"


class StatusLogInline(admin.TabularInline):
    model = OrderStatusLog
    extra = 0
    readonly_fields = ("from_status", "to_status", "actor", "comment", "created_at")
    verbose_name = "Лог изменения статуса"
    verbose_name_plural = "Логи изменений статусов"


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ("number", "client", "status", "manager", "operator", "start_dt", "end_dt", "total_amount")
    list_filter = ("status", "start_dt", "manager")
    search_fields = ("number", "client__name", "client__phone", "description")
    date_hierarchy = "start_dt"
    inlines = (OrderItemInline, PhotoEvidenceInline, StatusLogInline)
    actions = ("export_orders_csv", "mark_completed", "generate_invoice_pdf")
    readonly_fields = ("id", "created_at", "updated_at")

    def get_readonly_fields(self, request, obj=None):
        """Все поля ID должны быть readonly"""
        return self.readonly_fields + ("id",) if "id" not in self.readonly_fields else self.readonly_fields

    @admin.action(description="Экспортировать выбранные заказы в CSV")
    def export_orders_csv(self, request, queryset):
        buffer = StringIO()
        writer = csv.writer(buffer)
        writer.writerow(
            [
                "number",
                "client",
                "status",
                "manager",
                "operator",
                "start_dt",
                "end_dt",
                "total_amount",
            ]
        )
        for order in queryset:
            writer.writerow(
                [
                    order.number,
                    order.client.name if order.client else "",
                    order.status,
                    order.manager.get_full_name() if order.manager else "",
                    order.operator.get_full_name() if order.operator else "",
                    order.start_dt,
                    order.end_dt,
                    order.total_amount,
                ]
            )
        response = HttpResponse(buffer.getvalue(), content_type="text/csv")
        response["Content-Disposition"] = f'attachment; filename="orders_{datetime.now():%Y%m%d%H%M%S}.csv"'
        return response

    @admin.action(description="Отметить выбранные заказы как завершённые")
    def mark_completed(self, request, queryset):
        updated = queryset.update(status=OrderStatus.COMPLETED, end_dt=datetime.now())
        self.message_user(request, f"Обновлено {updated} заказов", messages.SUCCESS)

    @admin.action(description="Сгенерировать PDF для выбранных заказов")
    def generate_invoice_pdf(self, request, queryset):
        generated = 0
        for order in queryset:
            invoice, _ = Invoice.objects.get_or_create(order=order, defaults={"number": f"INV-{order.number}"})
            invoice.status = invoice.status or "sent"
            invoice.pdf_url = invoice.pdf_url or f"https://example.com/invoices/{invoice.number}.pdf"
            invoice.save()
            generated += 1
        self.message_user(request, f"Подготовлено {generated} PDF (заглушка)", messages.INFO)

