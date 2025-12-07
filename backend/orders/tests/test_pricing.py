from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone

from catalog.models import Equipment
from crm.models import Client
from orders.models import Order, OrderItem
from orders.services.pricing import calculate_order_total
from users.models import User


class PricingEngineTests(TestCase):
    def setUp(self):
        self.client_obj = Client.objects.create(name="ACME", phone="+1000000000")
        self.manager = User.objects.create_user(username="manager", password="pass")

    def _create_order(self, hours: float = 4.0, **kwargs) -> Order:
        start = timezone.now() - timedelta(hours=hours)
        end = timezone.now()
        order = Order.objects.create(
            number="000001",
            client=self.client_obj,
            address="Test address",
            start_dt=start,
            end_dt=end,
            manager=self.manager,
            prepayment_amount=Decimal("100.00"),
            **kwargs,
        )
        return order

    def test_equipment_hourly_rounds_to_half_hour(self):
        equipment = Equipment.objects.create(code="EQ-1", name="Excavator", hourly_rate=Decimal("120.00"))
        order = self._create_order(hours=3.25)
        OrderItem.objects.create(
            order=order,
            item_type=OrderItem.ItemType.EQUIPMENT,
            name_snapshot="Excavator",
            unit_price=Decimal("120.00"),
            quantity=Decimal("1"),
            ref_id=equipment.id,
        )
        total = calculate_order_total(order)
        # 3.25h -> 3.5h * 120
        self.assertEqual(total, Decimal("420.00"))
        self.assertEqual(order.total_amount, Decimal("420.00"))
        positions = order.price_snapshot["positions"]
        self.assertEqual(positions[0]["quantity"], "3.5")

    def test_equipment_daily_rate_after_threshold(self):
        equipment = Equipment.objects.create(code="EQ-2", name="Bulldozer", hourly_rate=Decimal("150.00"))
        order = self._create_order(hours=10)
        OrderItem.objects.create(
            order=order,
            item_type=OrderItem.ItemType.EQUIPMENT,
            name_snapshot="Bulldozer",
            unit_price=Decimal("150.00"),
            quantity=Decimal("1"),
            ref_id=equipment.id,
            metadata={"daily_rate": "800"},
        )
        total = calculate_order_total(order)
        self.assertEqual(total, Decimal("800.00"))
        self.assertIn("Daily rate", order.price_snapshot["positions"][0]["notes"])

    def test_material_negative_quantity_sanitized(self):
        order = self._create_order(hours=1)
        OrderItem.objects.create(
            order=order,
            item_type=OrderItem.ItemType.MATERIAL,
            name_snapshot="Sand",
            unit_price=Decimal("50.00"),
            quantity=Decimal("-5"),
        )
        total = calculate_order_total(order)
        self.assertEqual(total, Decimal("0.00"))
        self.assertEqual(order.price_snapshot["summary"]["total"], "0.00")

    def test_late_penalty_applies_automatic_discount(self):
        planned_end = (timezone.now() - timedelta(hours=1)).isoformat()
        order = self._create_order(meta={"planned_end_dt": planned_end})
        OrderItem.objects.create(
            order=order,
            item_type=OrderItem.ItemType.SERVICE,
            name_snapshot="Work",
            unit_price=Decimal("1000.00"),
            quantity=Decimal("1"),
        )
        total = calculate_order_total(order)
        # 10% penalty from 1000
        self.assertEqual(total, Decimal("900.00"))
        summary = order.price_snapshot["summary"]
        self.assertEqual(summary["late_penalty"], "100.00")
        self.assertEqual(summary["discount_total"], "100.00")

