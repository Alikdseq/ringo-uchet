from __future__ import annotations

from decimal import Decimal
from typing import Iterable

from ..models import Expense


def aggregate_expenses(expenses: Iterable[Expense]) -> dict[str, str]:
    totals: dict[str, Decimal] = {}
    for exp in expenses:
        category = exp.category
        totals.setdefault(category, Decimal("0.00"))
        totals[category] += exp.amount
    totals["overall"] = sum(totals.values(), Decimal("0.00"))
    return {key: f"{value:.2f}" for key, value in totals.items()}

