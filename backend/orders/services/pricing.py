from __future__ import annotations

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP, ROUND_UP
from typing import Any

from django.conf import settings
from django.utils import timezone

from orders.models import Order, OrderItem

DECIMAL_ZERO = Decimal("0.00")


@dataclass(frozen=True)
class PricingConfig:
    equipment_daily_threshold_hours: int = 8
    late_penalty_percent: Decimal = Decimal("10")

    @classmethod
    def from_settings(cls) -> "PricingConfig":
        cfg = getattr(settings, "PRICING_ENGINE", {})
        return cls(
            equipment_daily_threshold_hours=int(cfg.get("equipment_daily_threshold_hours", 8)),
            late_penalty_percent=Decimal(str(cfg.get("late_penalty_percent", "10"))),
        )


def calculate_order_total(order: Order) -> Decimal:
    """
    Calculate order total with support for equipment hourly/daily billing, materials, services,
    attachments and automatic penalties for late completion.
    """

    config = PricingConfig.from_settings()
    positions: list[dict[str, Any]] = []
    subtotal = DECIMAL_ZERO
    tax_total = DECIMAL_ZERO
    discount_total = DECIMAL_ZERO

    for item in order.items.all():
        item_result = _calculate_item(order, item, config)
        positions.append(item_result)
        subtotal += item_result["line_total"]
        tax_total += item_result["tax_amount"]
        discount_total += item_result["discount_amount"]

    late_discount = _calculate_late_penalty(order, subtotal, config)
    discount_total += late_discount

    total = subtotal + tax_total - discount_total
    prepayment = order.prepayment_amount or DECIMAL_ZERO
    balance = max(total - prepayment, DECIMAL_ZERO)

    order.price_snapshot = {
        "positions": [_serialize_position(p) for p in positions],
        "summary": {
            "subtotal": _to_money(subtotal),
            "tax_total": _to_money(tax_total),
            "discount_total": _to_money(discount_total),
            "late_penalty": _to_money(late_discount),
            "total": _to_money(total),
            "prepayment": _to_money(prepayment),
            "balance": _to_money(balance),
        },
    }
    order.total_amount = total
    order.price_snapshot["generated_at"] = timezone.now().isoformat()
    return total


def _calculate_item(order: Order, item: OrderItem, config: PricingConfig) -> dict[str, Any]:
    quantity = Decimal(item.quantity or 0)
    unit_price = Decimal(item.unit_price or 0)
    tax_rate = Decimal(item.tax_rate or 0)
    discount = Decimal(item.discount or 0)
    metadata = item.metadata or {}
    billing_notes = ""
    effective_qty = quantity

    if item.item_type == OrderItem.ItemType.EQUIPMENT:
        # Используем информацию о сменах и часах из metadata, если она есть
        shifts = Decimal(str(metadata.get("shifts", 0)))
        hours = Decimal(str(metadata.get("hours", 0)))
        daily_rate = Decimal(str(metadata.get("daily_rate", 0)))
        hourly_rate = unit_price  # unit_price уже содержит hourly_rate из Equipment
        
        if shifts > 0 or hours > 0:
            # Рассчитываем стоимость: смены * daily_rate + часы * hourly_rate
            shifts_cost = shifts * daily_rate if daily_rate > 0 else Decimal("0")
            hours_cost = hours * hourly_rate
            total_cost = shifts_cost + hours_cost
            
            # Формируем описание
            notes_parts = []
            if shifts > 0:
                notes_parts.append(f"{int(shifts)} смен")
            if hours > 0:
                notes_parts.append(f"{float(hours):.1f} ч")
            billing_notes = ", ".join(notes_parts) if notes_parts else "Техника"
            
            # ВАЖНО: quantity в snapshot НЕ используется для расчетов!
            # Расчеты выполняются через shifts_cost + hours_cost (строки 93-95)
            # quantity здесь используется только для отображения/сортировки в snapshot
            # НЕ преобразуем смены в часы - это привело бы к неправильным расчетам
            # Используем просто сумму смен и часов для визуального представления
            effective_qty = shifts + hours  # Только для отображения, НЕ для расчетов!
            
            # Применяем скидку (discount - это процент)
            discount_amount = total_cost * (discount / Decimal("100")) if discount > 0 else Decimal("0")
            line_total = total_cost - discount_amount
            tax_amount = (line_total * (tax_rate / Decimal("100"))).quantize(Decimal("0.01"))
            
            return {
                "name": item.name_snapshot,
                "type": item.item_type,
                "quantity": effective_qty,  # Используется только для отображения, не для расчетов
                "unit_price": hourly_rate,  # Базовое значение для отображения
                "line_total": line_total + tax_amount,  # Правильно рассчитанная сумма
                "tax_amount": tax_amount,
                "discount_amount": discount_amount,
                "notes": billing_notes,
                "metadata": {
                    "shifts": int(shifts),
                    "hours": float(hours),
                    "shifts_cost": float(shifts_cost),
                    "hours_cost": float(hours_cost),
                },
            }
        else:
            # Если нет информации о сменах, используем старую логику
            duration_hours = _round_half_hour(_get_duration_hours(order))
            threshold = Decimal(config.equipment_daily_threshold_hours)
            if duration_hours >= threshold and daily_rate > 0:
                days = _ceil(duration_hours / Decimal("24"))
                unit_price = daily_rate
                effective_qty = days
                billing_notes = f"Daily rate ({days} day(s))"
            else:
                effective_qty = duration_hours
                billing_notes = f"Hourly rate ({duration_hours} h)"
    elif item.item_type == OrderItem.ItemType.MATERIAL:
        effective_qty = max(quantity, DECIMAL_ZERO)
        billing_notes = "Materials"
    elif item.item_type == OrderItem.ItemType.SERVICE:
        billing_mode = metadata.get("billing_mode", "fixed")
        if billing_mode == "per_hour":
            effective_qty = _round_half_hour(_get_duration_hours(order))
            billing_notes = "Service per hour"
        else:
            billing_notes = "Fixed service"
    else:
        billing_notes = metadata.get("note", item.item_type.title())

    effective_qty = max(effective_qty, DECIMAL_ZERO)
    # Применяем скидку (discount - это процент)
    discount_amount = (unit_price * effective_qty) * (discount / Decimal("100")) if discount > 0 else DECIMAL_ZERO
    line_total = (unit_price * effective_qty) - discount_amount
    tax_amount = (line_total * (tax_rate / Decimal("100"))).quantize(Decimal("0.01"))

    return {
        "name": item.name_snapshot,
        "type": item.item_type,
        "quantity": effective_qty,
        "unit_price": unit_price,
        "line_total": line_total + tax_amount,
        "tax_amount": tax_amount,
        "discount_amount": discount_amount,
        "notes": billing_notes,
    }


def _calculate_late_penalty(order: Order, subtotal: Decimal, config: PricingConfig) -> Decimal:
    if subtotal <= DECIMAL_ZERO:
        return DECIMAL_ZERO
    if not _is_late(order):
        return DECIMAL_ZERO
    penalty = (subtotal * config.late_penalty_percent / Decimal("100")).quantize(Decimal("0.01"))
    return penalty


def _round_half_hour(value: Decimal) -> Decimal:
    return (value * 2).quantize(Decimal("1"), rounding=ROUND_HALF_UP) / 2


def _ceil(value: Decimal) -> Decimal:
    return value.quantize(Decimal("1"), rounding=ROUND_UP)


def _get_duration_hours(order: Order) -> Decimal:
    start = order.start_dt
    end = order.end_dt or timezone.now()
    delta = max((end - start).total_seconds(), 0)
    hours = Decimal(delta) / Decimal("3600")
    return hours


def _calculate_shifts_and_hours(start_dt: datetime, end_dt: datetime) -> tuple[Decimal, Decimal]:
    """
    Рассчитывает количество смен (8 часов = 1 смена) и оставшихся часов.
    
    Логика: каждый календарный день, где отработано >= 8 часов, считается как 1 смена.
    Остальные часы (не входящие в полные смены) считаются почасово.
    
    Примеры:
    - 1 число 9:00 - 3 число 18:00: 
      День 1: 9:00-23:59 = ~15 часов = 1 смена + 7 часов
      День 2: 00:00-23:59 = 24 часа = 3 смены
      День 3: 00:00-18:00 = 18 часов = 2 смены + 2 часа
      Итого: 6 смен + 9 часов
      
    Упрощенная логика: считаем каждый день отдельно, >= 8 часов = 1 смена.
    """
    if not start_dt or not end_dt:
        return Decimal("0"), Decimal("0")
    
    from datetime import timedelta, time
    
    shifts = Decimal("0")
    remaining_hours = Decimal("0")
    
    current_date = start_dt.date()
    end_date = end_dt.date()
    
    if current_date == end_date:
        # Один день
        delta = max((end_dt - start_dt).total_seconds(), 0)
        total_hours = Decimal(delta) / Decimal("3600")
        
        if total_hours >= 8:
            shifts = Decimal("1")
            remaining_hours = total_hours - Decimal("8")
        else:
            remaining_hours = total_hours
    else:
        # Несколько дней - обрабатываем каждый день отдельно
        current = start_dt
        
        while current < end_dt:
            day_start = current
            # Конец текущего дня
            day_end_time = time(23, 59, 59)
            day_end = datetime.combine(day_start.date(), day_end_time)
            if day_end > end_dt:
                day_end = end_dt
            
            # Часы в текущем дне
            day_delta = max((day_end - day_start).total_seconds(), 0)
            day_hours = Decimal(day_delta) / Decimal("3600")
            
            if day_hours >= 8:
                shifts += Decimal("1")
                remaining_hours += day_hours - Decimal("8")
            else:
                remaining_hours += day_hours
            
            # Переходим к следующему дню
            next_day = day_start.date() + timedelta(days=1)
            current = datetime.combine(next_day, time(0, 0, 0))
            
            # Защита от бесконечного цикла
            if current.date() > end_date:
                break
    
    # Округляем до 0.5 часа
    remaining_hours = _round_half_hour(remaining_hours)
    
    return shifts, remaining_hours


def _is_late(order: Order) -> bool:
    meta = order.meta or {}
    if meta.get("is_delayed"):
        return True
    planned_end = meta.get("planned_end_dt")
    if planned_end:
        try:
            planned_dt = datetime.fromisoformat(planned_end)
        except ValueError:
            return False
        actual_end = order.end_dt or timezone.now()
        return actual_end > planned_dt
    return False


def _serialize_position(data: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": data["name"],
        "type": data["type"],
        "quantity": str(data["quantity"]),
        "unit_price": _to_money(data["unit_price"]),
        "tax_amount": _to_money(data["tax_amount"]),
        "discount": _to_money(data["discount_amount"]),
        "line_total": _to_money(data["line_total"]),
        "notes": data["notes"],
    }


def _to_money(value: Decimal) -> str:
    return f"{value.quantize(Decimal('0.01'))}"

