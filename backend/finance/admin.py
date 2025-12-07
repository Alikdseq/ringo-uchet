from __future__ import annotations

from django.contrib import admin

from .models import DocumentTemplate, Expense, Invoice, Payment, SalaryRecord


@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ("number", "order", "payment_status", "amount", "issued_at")
    search_fields = ("number", "order__number", "order__client__name")
    list_filter = ("payment_status",)


@admin.register(Expense)
class ExpenseAdmin(admin.ModelAdmin):
    list_display = ("category", "amount", "date", "order", "equipment")
    list_filter = ("category", "date")
    search_fields = ("order__number", "equipment__code", "reported_by__email")


@admin.register(SalaryRecord)
class SalaryRecordAdmin(admin.ModelAdmin):
    list_display = ("user", "order", "amount", "status", "created_at")
    list_filter = ("status",)
    search_fields = ("user__email", "order__number")


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ("order", "amount", "method", "status", "paid_at")
    list_filter = ("status", "method")
    search_fields = ("order__number", "transaction_id")


@admin.register(DocumentTemplate)
class DocumentTemplateAdmin(admin.ModelAdmin):
    list_display = ("template_type", "slug", "version", "template_path", "is_active")
    list_filter = ("template_type", "is_active")
    search_fields = ("slug", "template_path")

