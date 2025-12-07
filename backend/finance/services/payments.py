from __future__ import annotations

import logging
from decimal import Decimal
from typing import Literal

from django.utils import timezone

from orders.models import Order

from ..models import Payment, PaymentMethod, PaymentStatus

logger = logging.getLogger(__name__)


def initiate_payment(
    order: Order,
    amount: Decimal,
    method: Literal["cash", "bank_transfer", "online", "other"] = PaymentMethod.BANK_TRANSFER,
) -> Payment:
    """
    Stub for payment gateway integration. Simulates asynchronous confirmation.
    """
    payment = Payment.objects.create(
        order=order,
        invoice=getattr(order, "invoice", None),
        method=method,
        amount=amount,
        status=PaymentStatus.PENDING,
    )

    # Stub logic: mark as success immediately for non-online payments
    if method != PaymentMethod.ONLINE:
        payment.status = PaymentStatus.SUCCESS
        payment.paid_at = timezone.now()
        payment.save(update_fields=["status", "paid_at"])
        _update_invoice_status(order)
    else:
        logger.info("Initiated online payment for order %s amount %s", order.number, amount)

    return payment


def _update_invoice_status(order: Order) -> None:
    invoice = getattr(order, "invoice", None)
    if not invoice:
        return
    if order.payments.filter(status=PaymentStatus.SUCCESS).exists():
        invoice.payment_status = PaymentStatus.SUCCESS
        invoice.save(update_fields=["payment_status"])

