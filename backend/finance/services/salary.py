from __future__ import annotations

from decimal import Decimal

from django.db import transaction

from orders.models import Order

from ..models import SalaryRecord


def calculate_salary_for_order(order: Order, rate_percent: Decimal = Decimal("10")) -> SalaryRecord:
    """
    Simple salary calculator: operator receives percent from order total.
    """
    if not order.operator:
        raise ValueError("Order has no assigned operator")

    rate_percent = Decimal(rate_percent)
    amount = (order.total_amount or Decimal("0")) * rate_percent / Decimal("100")

    with transaction.atomic():
        record, created = SalaryRecord.objects.get_or_create(
            user=order.operator,
            order=order,
            defaults={
                "rate_type": SalaryRecord.RateType.PERCENT,
                "rate_value": rate_percent,
                "amount": amount,
            },
        )
        if not created:
            record.rate_value = rate_percent
            record.amount = amount
            record.save(update_fields=["rate_value", "amount"])

    return record

