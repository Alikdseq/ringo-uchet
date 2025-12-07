"""
Скрипт для диагностики проблемы с UUID в админке Django.
Запустите: docker compose exec django-api python check_admin_issue.py
"""
import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ringo_backend.settings.local")
django.setup()

from django.contrib.admin.sites import site
from orders.models import Order
from finance.models import Invoice

print("🔍 Проверка конфигурации админки...")
print(f"Зарегистрированные модели: {len(site._registry)}")

# Проверяем, есть ли записи с integer ID
print("\n📊 Проверка данных в базе:")
try:
    orders = Order.objects.all()
    print(f"Заказов в БД: {orders.count()}")
    if orders.exists():
        for order in orders[:5]:
            print(f"  - Order {order.id} (type: {type(order.id).__name__})")
except Exception as e:
    print(f"Ошибка при проверке Order: {e}")

try:
    invoices = Invoice.objects.all()
    print(f"Счетов в БД: {invoices.count()}")
    if invoices.exists():
        for invoice in invoices[:5]:
            print(f"  - Invoice {invoice.id}, order_id: {invoice.order_id} (type: {type(invoice.order_id).__name__})")
except Exception as e:
    print(f"Ошибка при проверке Invoice: {e}")

# Проверяем URL patterns
print("\n🔗 Проверка URL patterns:")
from django.urls import get_resolver
resolver = get_resolver()
admin_urls = [p for p in resolver.url_patterns if 'admin' in str(p)]
print(f"Admin URL patterns: {len(admin_urls)}")

print("\n✅ Диагностика завершена")

