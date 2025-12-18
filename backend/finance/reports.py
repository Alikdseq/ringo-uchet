from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from django.db.models import DecimalField, ExpressionWrapper, F, Q, Sum
from django.db import models

from catalog.models import Equipment, MaterialItem
from finance.models import Expense, SalaryRecord
from orders.models import Order, OrderItem, OrderStatus
from orders.services.pricing import _get_duration_hours


def _parse_date(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        # Парсим дату в формате YYYY-MM-DD
        if isinstance(value, str):
            from django.utils import timezone
            # Если только дата без времени, добавляем время начала дня
            if len(value) == 10:  # YYYY-MM-DD
                parsed = datetime.strptime(value, "%Y-%m-%d")
            else:
                parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
            # Делаем дату timezone-aware используя текущий timezone Django
            if timezone.is_naive(parsed):
                tz = timezone.get_current_timezone()
                parsed = timezone.make_aware(parsed, tz)
            return parsed
        return None
    except (ValueError, AttributeError, TypeError):
        return None


def filter_range(queryset, field: str, date_from: Optional[str], date_to: Optional[str]):
    """Фильтрует queryset по диапазону дат. Если даты не указаны, возвращает все записи."""
    if not date_from and not date_to:
        return queryset
    df = _parse_date(date_from)
    dt = _parse_date(date_to)
    if df:
        queryset = queryset.filter(**{f"{field}__gte": df})
    if dt:
        # Добавляем 1 день к конечной дате, чтобы включить весь день
        from datetime import timedelta
        from django.utils import timezone
        dt_end = dt + timedelta(days=1)
        # Убеждаемся, что дата timezone-aware
        if timezone.is_naive(dt_end):
            dt_end = timezone.make_aware(dt_end, timezone.get_current_timezone())
        queryset = queryset.filter(**{f"{field}__lt": dt_end})
    return queryset


def summary_report(date_from: Optional[str], date_to: Optional[str]) -> dict:
    # Для доходов учитываем только завершенные заказы (COMPLETED)
    # Удаленные заявки больше не существуют в БД (hard delete)
    # Не завершенные заявки не должны учитываться в отчетах
    orders = Order.objects.filter(status=OrderStatus.COMPLETED)
    
    # Применяем фильтр по дате создания заказа
    # Если период указан, фильтруем по created_at
    # Если период не указан, показываем все заказы
    if date_from or date_to:
        orders = filter_range(orders, "created_at", date_from, date_to)
    
    # Для расходов и зарплат учитываем только те, что связаны с заказами из периода
    # Расходы: учитываем расходы, привязанные к заказам из периода, И расходы без привязки, но в периоде по дате
    expense_q = Q(order__in=orders)
    if date_from or date_to:
        # Также добавляем расходы без привязки к заказу, но в периоде по дате
        expenses_without_orders = filter_range(Expense.objects.filter(order__isnull=True), "date", date_from, date_to)
        expense_q |= Q(id__in=expenses_without_orders.values_list('id', flat=True))
    expenses = Expense.objects.filter(expense_q)
    
    # Зарплаты: учитываем только зарплаты за заказы из периода
    salaries = SalaryRecord.objects.filter(order__in=orders)

    # Суммируем total_amount всех заказов
    # Sum возвращает None если нет записей или все значения NULL
    revenue_result = orders.aggregate(total=Sum("total_amount"))
    revenue = revenue_result["total"] if revenue_result["total"] is not None else Decimal("0")
    
    # Рассчитываем доходы по услугам и технике с детализацией
    # Доходы с услуг: включаем услуги (SERVICE) и материалы с категориями грунт и инструменты (SOIL, TOOL)
    
    # Получаем услуги
    service_items = OrderItem.objects.filter(
        order__in=orders,
        item_type=OrderItem.ItemType.SERVICE
    )
    
    # Получаем материалы с категориями грунт и инструменты
    material_items = OrderItem.objects.filter(
        order__in=orders,
        item_type=OrderItem.ItemType.MATERIAL,
    )
    
    # Фильтруем материалы: только грунт (SOIL) и инструменты (TOOL)
    # Избегаем N+1 запросов к MaterialItem, заранее подтягивая все нужные записи.
    material_items_soil_tool = []
    # Собираем ref_id для тех позиций, где категория не проставлена в metadata
    ref_ids_to_resolve = {
        item.ref_id
        for item in material_items
        if item.ref_id and not (item.metadata or {}).get("material_category")
    }
    material_map = {}
    if ref_ids_to_resolve:
        material_map = {
            m.id: m
            for m in MaterialItem.objects.filter(id__in=ref_ids_to_resolve)
        }
    
    for item in material_items:
        metadata = item.metadata or {}
        material_category = metadata.get("material_category")
        # Если категория не указана в metadata, пытаемся получить из заранее загруженных MaterialItem
        if not material_category and item.ref_id:
            material = material_map.get(item.ref_id)
            if not material:
                continue
            material_category = material.category
        
        # Включаем только грунт и инструменты
        if material_category in [
            MaterialItem.MaterialCategory.SOIL,
            MaterialItem.MaterialCategory.TOOL,
        ]:
            material_items_soil_tool.append(item)
    
    # Объединяем услуги и материалы (грунт и инструменты) для расчета доходов
    all_service_items = list(service_items) + material_items_soil_tool
    
    # Рассчитываем общую сумму доходов от услуг и материалов
    service_revenue = Decimal("0")
    service_total_quantity = Decimal("0")
    
    for item in all_service_items:
        quantity = Decimal(str(item.quantity or 0))
        unit_price = Decimal(str(item.unit_price or 0))
        discount = Decimal(str(item.discount or 0))
        tax_rate = Decimal(str(item.tax_rate or 0))
        
        # Рассчитываем стоимость с учетом скидки
        total_cost = quantity * unit_price
        discount_amount = total_cost * (discount / Decimal("100")) if discount > 0 else Decimal("0")
        line_total = total_cost - discount_amount
        
        # Применяем налог
        tax_amount = (line_total * (tax_rate / Decimal("100"))).quantize(Decimal("0.01"))
        service_revenue += line_total + tax_amount
        service_total_quantity += quantity
    
    service_avg_price = service_revenue / service_total_quantity if service_total_quantity > 0 else Decimal("0")
    
    # Доходы с техники - правильный расчет через смены и часы
    equipment_items = OrderItem.objects.filter(
        order__in=orders,
        item_type=OrderItem.ItemType.EQUIPMENT
    ).select_related("order")
    
    # Рассчитываем доходы правильно: смены * daily_rate + часы * hourly_rate
    equipment_revenue = Decimal("0")
    equipment_total_hours = Decimal("0")
    equipment_total_shifts = Decimal("0")
    
    for item in equipment_items:
        metadata = item.metadata or {}
        shifts = Decimal(str(metadata.get("shifts", 0) or 0))
        hours = Decimal(str(metadata.get("hours", 0) or 0))
        daily_rate = Decimal(str(metadata.get("daily_rate", 0) or 0))
        hourly_rate = Decimal(str(item.unit_price or 0))
        discount = Decimal(str(item.discount or 0))
        tax_rate = Decimal(str(item.tax_rate or 0))
        
        if shifts > 0 or hours > 0:
            # Правильный расчет: смены * daily_rate + часы * hourly_rate
            shifts_cost = shifts * daily_rate if daily_rate > 0 else Decimal("0")
            hours_cost = hours * hourly_rate
            total_cost = shifts_cost + hours_cost
            
            # Применяем скидку (процент)
            discount_amount = total_cost * (discount / Decimal("100")) if discount > 0 else Decimal("0")
            line_total = total_cost - discount_amount
            
            # Применяем налог
            tax_amount = (line_total * (tax_rate / Decimal("100"))).quantize(Decimal("0.01"))
            equipment_revenue += line_total + tax_amount
            
            # Для статистики считаем общее количество часов и смен
            equipment_total_hours += hours
            equipment_total_shifts += shifts
        else:
            # Если нет информации о сменах/часах, используем старую логику для совместимости
            quantity = Decimal(str(item.quantity or 0))
            unit_price = Decimal(str(item.unit_price or 0))
            discount = Decimal(str(item.discount or 0))
            tax_rate = Decimal(str(item.tax_rate or 0))
            
            total_cost = unit_price * quantity
            discount_amount = total_cost * (discount / Decimal("100")) if discount > 0 else Decimal("0")
            line_total = total_cost - discount_amount
            tax_amount = (line_total * (tax_rate / Decimal("100"))).quantize(Decimal("0.01"))
            equipment_revenue += line_total + tax_amount
            equipment_total_hours += quantity
    
    equipment_avg_price_per_hour = equipment_revenue / equipment_total_hours if equipment_total_hours > 0 else Decimal("0")
    
    expense_total = expenses.aggregate(total=Sum("amount"))["total"] or Decimal("0")
    
    # Рассчитываем расходы на топливо отдельно
    fuel_expenses = expenses.filter(category="fuel")
    fuel_expense_total = fuel_expenses.aggregate(total=Sum("amount"))["total"] or Decimal("0")
    
    # Рассчитываем расходы на ремонт отдельно
    repair_expenses = expenses.filter(category="repair")
    repair_expense_total = repair_expenses.aggregate(total=Sum("amount"))["total"] or Decimal("0")
    
    salaries_total = salaries.aggregate(total=Sum("amount"))["total"] or Decimal("0")
    margin = revenue - expense_total - salaries_total

    summary = {
        "revenue": str(revenue),
        "revenue_from_services": str(service_revenue),
        "revenue_from_services_details": {
            "total_amount": str(service_revenue),  # Общая сумма доходов от услуг
            "total_quantity": str(service_total_quantity),  # Общее количество единиц (часов/дней/шт)
            "average_price_per_unit": str(service_avg_price),  # Средняя цена за единицу
        },
        "revenue_from_equipment": str(equipment_revenue),
        "revenue_from_equipment_details": {
            "total_amount": str(equipment_revenue),  # Общая сумма доходов от техники
            "total_hours": str(equipment_total_hours),  # Общее количество часов работы
            "total_shifts": str(equipment_total_shifts),  # Общее количество смен
            "average_price_per_hour": str(equipment_avg_price_per_hour),  # Средняя цена за час (только для информации)
        },
        "expenses": str(expense_total),
        "expenses_fuel": str(fuel_expense_total),  # Суммирующий расход по топливу
        "expenses_repair": str(repair_expense_total),  # Суммирующий расход по ремонту
        "salaries": str(salaries_total),
        "margin": str(margin),
        "orders_count": orders.count(),
        "period": {"from": date_from, "to": date_to},
    }
    return summary


def equipment_report(date_from: Optional[str], date_to: Optional[str]) -> list[dict]:
    """Отчет по технике с правильным расчетом часов работы из start_dt и end_dt заказов."""
    # Фильтруем только завершенные заявки (COMPLETED)
    # Удаленные заявки автоматически исключены через CASCADE
    items = filter_range(
        OrderItem.objects.filter(item_type=OrderItem.ItemType.EQUIPMENT)
        .filter(order__status=OrderStatus.COMPLETED)
        .select_related("order"),
        "order__start_dt",
        date_from,
        date_to,
    )
    
    # Группируем по технике и рассчитываем реальное время работы
    equipment_data = {}
    for item in items:
        eq_id = item.ref_id
        if not eq_id:
            continue
        
        # Используем правильный расчет через metadata (смены и часы)
        metadata = item.metadata or {}
        shifts = Decimal(str(metadata.get("shifts", 0) or 0))
        hours = Decimal(str(metadata.get("hours", 0) or 0))
        daily_rate = Decimal(str(metadata.get("daily_rate", 0) or 0))
        hourly_rate = Decimal(str(item.unit_price or 0))
        discount = Decimal(str(item.discount or 0))
        tax_rate = Decimal(str(item.tax_rate or 0))
        
        # Рассчитываем реальное время работы и доход
        if shifts > 0 or hours > 0:
            # Правильный расчет: смены * daily_rate + часы * hourly_rate
            shifts_cost = shifts * daily_rate if daily_rate > 0 else Decimal("0")
            hours_cost = hours * hourly_rate
            total_cost = shifts_cost + hours_cost
            
            # Применяем скидку (процент)
            discount_amount = total_cost * (discount / Decimal("100")) if discount > 0 else Decimal("0")
            line_total = total_cost - discount_amount
            
            # Применяем налог
            tax_amount = (line_total * (tax_rate / Decimal("100"))).quantize(Decimal("0.01"))
            line_total = line_total + tax_amount
            
            # Для статистики используем реальное время
            actual_hours = hours  # Только часы, смены учитываем отдельно
        else:
            # Если нет информации о сменах/часах, используем старую логику
            order = item.order
            if order.start_dt and order.end_dt:
                actual_hours = _get_duration_hours(order)
            else:
                actual_hours = Decimal(item.quantity or 0)
            
            # Рассчитываем доход с учетом скидки
            line_total = (Decimal(item.unit_price or 0) * actual_hours) * (1 - Decimal(item.discount or 0) / Decimal("100"))
        
        if eq_id not in equipment_data:
            equipment_data[eq_id] = {
                "total_hours": Decimal("0"),
                "revenue": Decimal("0"),
            }
        
        equipment_data[eq_id]["total_hours"] += actual_hours
        equipment_data[eq_id]["revenue"] += line_total

    equipment_ids = list(equipment_data.keys())
    equipment_map = {eq.id: eq for eq in Equipment.objects.filter(id__in=equipment_ids)}

    # Получаем расходы по технике, включая расходы на топливо
    expenses = filter_range(
        Expense.objects.filter(equipment_id__in=equipment_ids),
        "date",
        date_from,
        date_to,
    ).values("equipment_id").annotate(total=Sum("amount"))
    expense_map = {entry["equipment_id"]: entry["total"] for entry in expenses}
    
    # Получаем расходы на топливо отдельно для каждой техники
    fuel_expenses = filter_range(
        Expense.objects.filter(equipment_id__in=equipment_ids, category="fuel"),
        "date",
        date_from,
        date_to,
    ).values("equipment_id").annotate(total=Sum("amount"))
    fuel_expense_map = {entry["equipment_id"]: entry["total"] for entry in fuel_expenses}
    
    # Получаем расходы на ремонт отдельно для каждой техники
    repair_expenses = filter_range(
        Expense.objects.filter(equipment_id__in=equipment_ids, category="repair"),
        "date",
        date_from,
        date_to,
    ).values("equipment_id").annotate(total=Sum("amount"))
    repair_expense_map = {entry["equipment_id"]: entry["total"] for entry in repair_expenses}

    report = []
    for eq_id, data in equipment_data.items():
        equipment = equipment_map.get(eq_id)
        if not equipment:
            continue

        total_expenses = expense_map.get(eq_id, Decimal("0")) or Decimal("0")
        fuel_total = fuel_expense_map.get(eq_id, Decimal("0")) or Decimal("0")
        repair_total = repair_expense_map.get(eq_id, Decimal("0")) or Decimal("0")

        # В отчёте по технике показываем "выручку" как чистый результат:
        # доходы по заявкам минус расходы на топливо и ремонт.
        gross_revenue = data["revenue"]
        net_revenue = gross_revenue - fuel_total - repair_total

        report.append(
            {
                "equipment_id": eq_id,
                "equipment_name": equipment.name,
                "code": equipment.code,
                "status": equipment.status,
                "total_hours": str(data["total_hours"]),
                "revenue": str(net_revenue.quantize(Decimal("0.01"))),
                "expenses": str(total_expenses),
                "fuel_expenses": str(fuel_total),  # Расходы на топливо для данной техники
                "repair_expenses": str(repair_total),  # Расходы на ремонт для данной техники
            }
        )
    return report


def employees_report(date_from: Optional[str], date_to: Optional[str]) -> list[dict]:
    """Отчет по сотрудникам с фильтрацией зарплат по дате заказа."""
    # Фильтруем только завершенные заказы (COMPLETED)
    # Удаленные заявки больше не существуют в БД (hard delete)
    # Не завершенные заявки не должны учитываться в отчетах
    orders = Order.objects.filter(status=OrderStatus.COMPLETED)
    if date_from or date_to:
        orders = filter_range(orders, "created_at", date_from, date_to)
    
    # Фильтруем зарплаты по заказам из периода
    salaries = SalaryRecord.objects.filter(order__in=orders).select_related("user", "order")
    salaries = salaries.values("user_id", "user__first_name", "user__last_name").annotate(
        total_amount=Sum("amount"),
        total_hours=Sum("hours_worked"),
        assignments=Sum(1),
    )
    report: list[dict] = []
    for entry in salaries:
        report.append(
            {
                "user_id": entry["user_id"],
                "full_name": f"{entry['user__first_name']} {entry['user__last_name']}".strip(),
                "total_amount": str(entry["total_amount"] or Decimal("0")),
                "total_hours": str(entry["total_hours"] or Decimal("0")),
                "assignments": entry["assignments"],
            }
        )
    return report

