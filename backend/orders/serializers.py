from __future__ import annotations

import logging
from decimal import Decimal
from typing import Any

from django.db import transaction
from django.utils import timezone
from drf_spectacular.utils import extend_schema_field, extend_schema_serializer
from rest_framework import serializers

from catalog.models import Equipment
from crm.models import Client
from users.models import User

from .models import Order, OrderItem, OrderStatus, OrderStatusLog, PhotoEvidence
from .services.pricing import calculate_order_total, _get_duration_hours, _round_half_hour

logger = logging.getLogger(__name__)


class OrderItemSerializer(serializers.ModelSerializer):
    name_snapshot = serializers.CharField(required=False, allow_blank=True)
    unit_price = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True)
    tax_rate = serializers.DecimalField(max_digits=5, decimal_places=2, required=False, default=0.0)
    discount = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, default=0.0)
    display_quantity = serializers.SerializerMethodField()
    display_unit = serializers.SerializerMethodField()
    line_total = serializers.SerializerMethodField()
    
    fuel_expense = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        required=False,
        allow_null=True,
        help_text="Расходы на топливо для данной техники (только для техники)",
    )
    repair_expense = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        required=False,
        allow_null=True,
        help_text="Расходы на ремонт техники (только для техники)",
    )
    
    class Meta:
        model = OrderItem
        fields = (
            "id",
            "item_type",
            "ref_id",
            "name_snapshot",
            "quantity",
            "unit",
            "unit_price",
            "tax_rate",
            "discount",
            "fuel_expense",
            "repair_expense",
            "metadata",
            "display_quantity",
            "display_unit",
            "line_total",
        )
        read_only_fields = ("id", "display_quantity", "display_unit", "line_total")
    
    def get_display_quantity(self, obj) -> str:
        """Возвращает строку для отображения количества с учетом смен и часов."""
        if obj.item_type == OrderItem.ItemType.EQUIPMENT:
            metadata = obj.metadata or {}
            shifts = Decimal(str(metadata.get("shifts", 0) or 0))
            hours = Decimal(str(metadata.get("hours", 0) or 0))
            
            parts = []
            if shifts > 0:
                parts.append(f"{int(shifts)} смен")
            if hours > 0:
                parts.append(f"{float(hours):.1f} ч")
            
            if parts:
                return ", ".join(parts)
        
        # Для других типов возвращаем обычное количество
        qty = Decimal(str(obj.quantity or 0))
        return f"{qty:.2f}".rstrip('0').rstrip('.')
    
    def get_display_unit(self, obj) -> str:
        """Возвращает единицу измерения для отображения."""
        if obj.item_type == OrderItem.ItemType.EQUIPMENT:
            metadata = obj.metadata or {}
            shifts = Decimal(str(metadata.get("shifts", 0) or 0))
            hours = Decimal(str(metadata.get("hours", 0) or 0))
            
            if shifts > 0:
                return "смена" if shifts == 1 else "смены"
            elif hours > 0:
                return "час" if hours == 1 else "часа" if hours < 5 else "часов"
        
        return obj.unit or "-"
    
    def get_line_total(self, obj) -> Decimal:
        """Рассчитывает итоговую стоимость позиции с учетом смен, часов и скидки."""
        metadata = obj.metadata or {}
        discount = Decimal(str(obj.discount or 0))
        tax_rate = Decimal(str(obj.tax_rate or 0))
        
        if obj.item_type == OrderItem.ItemType.EQUIPMENT:
            shifts = Decimal(str(metadata.get("shifts", 0) or 0))
            hours = Decimal(str(metadata.get("hours", 0) or 0))
            daily_rate = Decimal(str(metadata.get("daily_rate", 0) or 0))
            hourly_rate = Decimal(str(obj.unit_price or 0))
            
            # Рассчитываем стоимость: смены * daily_rate + часы * hourly_rate
            shifts_cost = shifts * daily_rate if daily_rate > 0 else Decimal("0")
            hours_cost = hours * hourly_rate
            total_cost = shifts_cost + hours_cost
            
            # Применяем скидку (процент)
            discount_amount = total_cost * (discount / Decimal("100")) if discount > 0 else Decimal("0")
            line_total = total_cost - discount_amount
            
            # Применяем налог
            tax_amount = (line_total * (tax_rate / Decimal("100"))).quantize(Decimal("0.01"))
            return line_total + tax_amount
        else:
            # Для других типов позиций
            quantity = Decimal(str(obj.quantity or 0))
            unit_price = Decimal(str(obj.unit_price or 0))
            total_cost = unit_price * quantity
            
            # Применяем скидку (процент)
            discount_amount = total_cost * (discount / Decimal("100")) if discount > 0 else Decimal("0")
            line_total = total_cost - discount_amount
            
            # Применяем налог
            tax_amount = (line_total * (tax_rate / Decimal("100"))).quantize(Decimal("0.01"))
            return line_total + tax_amount


@extend_schema_serializer(
    examples=[
        {
            "number": "ORD-2025-001",
            "client_id": 1,
            "address": "ул. Ленина, д. 10",
            "geo_lat": "55.7558",
            "geo_lng": "37.6173",
            "start_dt": "2025-12-01T09:00:00Z",
            "end_dt": "2025-12-01T18:00:00Z",
            "description": "Копка траншеи для водопровода",
            "status": "CREATED",
            "manager_id": 2,
            "operator_id": 3,
            "prepayment_amount": "5000.00",
            "items": [
                {
                    "item_type": "equipment",
                    "ref_id": 1,
                    "quantity": "8.0",
                    "unit": "hour",
                    "unit_price": "1500.00",
                },
                {
                    "item_type": "service",
                    "ref_id": 5,
                    "quantity": "1.0",
                    "unit": "pcs",
                    "unit_price": "2000.00",
                },
            ],
        }
    ]
)
class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, required=False)  # Теперь можно передавать при создании
    number = serializers.CharField(required=False, allow_blank=True, max_length=32)
    client_id = serializers.PrimaryKeyRelatedField(
        queryset=Client.objects.all(), source="client", write_only=True, allow_null=True
    )
    manager_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), source="manager", write_only=True, allow_null=True, required=False
    )
    operator_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), source="operator", write_only=True, allow_null=True, required=False
    )
    operator_ids = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), many=True, source="operators", write_only=True, required=False
    )
    operators = serializers.SerializerMethodField(read_only=True)
    end_dt = serializers.DateTimeField(required=False, allow_null=True, read_only=True)  # Только для чтения при создании
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True)  # Можно указать при создании

    class Meta:
        model = Order
        fields = (
            "id",
            "number",
            "client",
            "client_id",
            "address",
            "geo_lat",
            "geo_lng",
            "start_dt",
            "end_dt",
            "description",
            "status",
            "manager",
            "manager_id",
            "operator",
            "operator_id",
            "operators",
            "operator_ids",
            "prepayment_amount",
            "prepayment_status",
            "total_amount",
            "price_snapshot",
            "attachments",
            "meta",
            "items",
            "created_by",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_by", "created_at", "updated_at", "client", "manager", "operator", "operators", "end_dt", "price_snapshot")

    def get_operators(self, obj):
        """Возвращает список операторов заказа."""
        operators = obj.operators.all()
        return [
            {
                "id": op.id,
                "first_name": op.first_name,
                "last_name": op.last_name,
                "phone": op.phone,
            }
            for op in operators
        ]
    
    def to_representation(self, instance):
        """Переопределяем для правильной сериализации связанных объектов."""
        representation = super().to_representation(instance)
        # Сериализуем связанные объекты
        if instance.client:
            representation["client"] = {
                "id": instance.client.id,
                "name": instance.client.name,
                "phone": instance.client.phone,
            }
        if instance.manager:
            representation["manager"] = {
                "id": instance.manager.id,
                "first_name": instance.manager.first_name,
                "last_name": instance.manager.last_name,
                "phone": instance.manager.phone,
            }
        # Для обратной совместимости оставляем operator (первый из operators или старый operator)
        if instance.operators.exists():
            first_operator = instance.operators.first()
            representation["operator"] = {
                "id": first_operator.id,
                "first_name": first_operator.first_name,
                "last_name": first_operator.last_name,
                "phone": first_operator.phone,
            }
        elif instance.operator:
            representation["operator"] = {
                "id": instance.operator.id,
                "first_name": instance.operator.first_name,
                "last_name": instance.operator.last_name,
                "phone": instance.operator.phone,
            }
        return representation

    def validate_status(self, value: str) -> str:
        if value not in OrderStatus.values:
            raise serializers.ValidationError("Invalid status")
        return value

    def validate_items(self, value):
        for item in value:
            if item["item_type"] == OrderItem.ItemType.EQUIPMENT and item.get("ref_id"):
                if not Equipment.objects.filter(id=item["ref_id"]).exists():
                    raise serializers.ValidationError("Equipment item not found")
        return value

    def create(self, validated_data: dict[str, Any]) -> Order:
        try:
            # Извлекаем items из validated_data (если переданы)
            items_data = validated_data.pop("items", None)
            # Если items_data - пустой список, считаем его как None (нет items)
            if items_data is not None and len(items_data) == 0:
                items_data = None
                logger.info("Empty items list received, treating as None")
            
            # Извлекаем operators из validated_data
            operators = validated_data.pop("operators", [])
            # Извлекаем total_amount если указан (примерная стоимость)
            total_amount = validated_data.pop("total_amount", None)
            
            logger.info(f"Creating order - items_data: {items_data is not None and len(items_data) if items_data else 0} items, total_amount: {total_amount}")
            user = self.context["request"].user
            validated_data.setdefault("created_by", user)
            # Если manager не указан явно, устанавливаем текущего пользователя как manager
            # Это нужно для того, чтобы создатель заявки мог ее видеть в списке
            if not validated_data.get("manager"):
                validated_data["manager"] = user
            # Генерируем номер заказа, если он не передан или пустой
            number = validated_data.get("number", "").strip()
            if not number:
                validated_data["number"] = self._generate_order_number()
            # Устанавливаем статус CREATED по умолчанию, если не указан
            if not validated_data.get("status"):
                validated_data["status"] = OrderStatus.CREATED
            # end_dt не устанавливается при создании
            validated_data.pop("end_dt", None)
            
            logger.info(f"Creating order. User: {user.id}, Data keys: {list(validated_data.keys())}")
            
            with transaction.atomic():
                order = Order.objects.create(**validated_data)
                # Добавляем операторов
                if operators:
                    order.operators.set(operators)
                # Для обратной совместимости: если указан operator_id, добавляем его в operators
                if validated_data.get("operator"):
                    order.operators.add(validated_data["operator"])
            # Добавляем items если они переданы при создании
            if items_data and len(items_data) > 0:
                self._upsert_items(order, items_data)
                # Рассчитываем стоимость из items
                items_total = calculate_order_total(order)
                
                # Если была указана примерная стоимость, прибавляем к ней стоимость items
                if total_amount is not None:
                    order.total_amount = Decimal(str(total_amount)) + items_total
                    logger.info(f"Creating order with base total {total_amount} + items {items_total} = {order.total_amount}")
                else:
                    # Иначе используем только стоимость items
                    order.total_amount = items_total
                    logger.info(f"Creating order with items total: {items_total}")
            elif total_amount is not None:
                # Если указана примерная стоимость без items, используем её
                order.total_amount = Decimal(str(total_amount))
                logger.info(f"Creating order with estimated total: {total_amount}")
            else:
                # По умолчанию 0
                order.total_amount = Decimal("0.00")
                logger.info("Creating order with default total: 0.00")
            order.save(update_fields=["total_amount"])
            logger.info(f"Order created successfully: {order.id}")
            return order
        except Exception as e:
            logger.error(f"Error creating order: {e}", exc_info=True)
            logger.error(f"Validated data keys: {list(validated_data.keys()) if validated_data else 'None'}")
            raise

    def update(self, instance: Order, validated_data: dict[str, Any]) -> Order:
        try:
            # Проверяем права: только админ может редактировать заявки на любом этапе
            user = self.context["request"].user
            logger.info(f"Updating order {instance.id}. User: {user.id}, Role: {user.role}, Current status: {instance.status}")
            
            if user.role != "admin" and not user.is_superuser:
                # Для не-админов проверяем, что заявка не завершена и не удалена
                if instance.status in [OrderStatus.COMPLETED, OrderStatus.DELETED]:
                    from rest_framework.exceptions import PermissionDenied
                    status_label = "завершенную" if instance.status == OrderStatus.COMPLETED else "удаленную"
                    error_msg = (
                        f"Недостаточно прав для редактирования {status_label} заявку. "
                        f"Текущий статус: {instance.status}. "
                        f"Только администратор может редактировать завершенные или удаленные заявки."
                    )
                    logger.warning(f"Permission denied: {error_msg}")
                    raise PermissionDenied(error_msg)
            
            # Извлекаем many-to-many поля и другие специальные поля ДО setattr
            items_data = validated_data.pop("items", None)
            # Если items_data - пустой список, считаем его как None (нет items для обновления)
            if items_data is not None and len(items_data) == 0:
                items_data = None
                logger.info("Empty items list received in update, treating as None")
            
            total_amount = validated_data.pop("total_amount", None)
            operators = validated_data.pop("operators", None)  # Извлекаем operators (many-to-many)
            
            logger.info(f"Updating order {instance.id} - items_data: {items_data is not None and len(items_data) if items_data else 0} items, total_amount: {total_amount}, current_total: {instance.total_amount}")
            
            # Сохраняем текущую стоимость как базу для расчета
            current_total = instance.total_amount or Decimal("0.00")
            
            # Защищаем поле number от изменения при обновлении (нельзя изменить или очистить)
            # Если передана пустая строка или None, игнорируем её
            if "number" in validated_data:
                number_value = validated_data.get("number", "").strip() if validated_data.get("number") else None
                if not number_value:
                    # Если передана пустая строка, удаляем из validated_data чтобы не перезаписать существующий номер
                    validated_data.pop("number")
                    logger.info(f"Empty number field ignored, keeping existing number: {instance.number}")
                elif number_value == instance.number:
                    # Если номер не изменился, удаляем из validated_data
                    validated_data.pop("number")
                else:
                    # Если номер изменился, проверяем уникальность
                    if Order.objects.filter(number=number_value).exclude(id=instance.id).exists():
                        logger.warning(f"Order number {number_value} already exists, ignoring change")
                        validated_data.pop("number")
            
            # Обновляем обычные поля
            for attr, value in validated_data.items():
                setattr(instance, attr, value)
            
            with transaction.atomic():
                instance.save()
                
                # Обновляем операторов если они переданы
                if operators is not None:
                    instance.operators.set(operators)
                
                # Обновляем items если они переданы
                if items_data is not None and len(items_data) > 0:
                    # Сохраняем стоимость существующих items перед удалением
                    existing_items_total = calculate_order_total(instance) or Decimal("0.00")
                    
                    # Удаляем старые items
                    instance.items.all().delete()
                    
                    # Добавляем новые items
                    self._upsert_items(instance, items_data)
                    
                    # Рассчитываем стоимость новых items
                    new_items_total = calculate_order_total(instance) or Decimal("0.00")
                    
                    # Определяем примерную стоимость (базовая стоимость без items)
                    # Если текущая total_amount больше суммы существующих items, значит есть примерная стоимость
                    estimated_cost = current_total - existing_items_total
                    
                    if estimated_cost > Decimal("0.00"):
                        # Была примерная стоимость - прибавляем стоимость новых items к примерной стоимости
                        instance.total_amount = estimated_cost + new_items_total
                        logger.info(f"Adding new items cost {new_items_total} to estimated cost {estimated_cost} = {instance.total_amount}")
                    else:
                        # Не было примерной стоимости - используем стоимость всех items
                        instance.total_amount = new_items_total
                        logger.info(f"Recalculating total from items: {new_items_total}")
                elif items_data is not None and len(items_data) == 0:
                    # Если передан пустой список items - удаляем все items, но сохраняем примерную стоимость
                    existing_items_total = calculate_order_total(instance) or Decimal("0.00")
                    instance.items.all().delete()
                    
                    # Сохраняем примерную стоимость, если она была
                    estimated_cost = current_total - existing_items_total
                    if estimated_cost > Decimal("0.00"):
                        instance.total_amount = estimated_cost
                        logger.info(f"Removed all items, keeping estimated cost: {estimated_cost}")
                    else:
                        instance.total_amount = Decimal("0.00")
                        logger.info("Removed all items, setting total to 0")
                elif total_amount is not None:
                    # Если явно указана total_amount БЕЗ изменения items - это обновление общей стоимости
                    # Если есть существующие items, их стоимость сохраняется, а примерная стоимость пересчитывается
                    existing_items_total = calculate_order_total(instance) or Decimal("0.00")
                    new_total = Decimal(str(total_amount))
                    
                    if existing_items_total > Decimal("0.00"):
                        # Есть items - новая total_amount = новая примерная стоимость + стоимость items
                        # Но пользователь вводит общую стоимость, поэтому примерная = общая - стоимость items
                        estimated_cost = new_total - existing_items_total
                        if estimated_cost < Decimal("0.00"):
                            # Если общая стоимость меньше стоимости items, устанавливаем total = стоимость items
                            logger.warning(f"Total amount {new_total} is less than items total {existing_items_total}, setting total to items total")
                            instance.total_amount = existing_items_total
                        else:
                            # Новая общая стоимость = новая примерная стоимость + стоимость items
                            instance.total_amount = new_total
                            logger.info(f"Updating total_amount to {new_total} (estimated: {estimated_cost} + items: {existing_items_total})")
                    else:
                        # Нет items - total_amount = примерная стоимость
                        instance.total_amount = new_total
                        logger.info(f"Setting total_amount (estimated cost) to {new_total}")
                else:
                    # Если items не изменены и total_amount не указан, пересчитываем из существующих items + примерной стоимости
                    existing_items_total = calculate_order_total(instance) or Decimal("0.00")
                    current_total = instance.total_amount
                    estimated_cost = current_total - existing_items_total
                    
                    if estimated_cost > Decimal("0.00"):
                        # Сохраняем примерную стоимость + стоимость items
                        instance.total_amount = estimated_cost + existing_items_total
                        logger.info(f"Recalculating: keeping estimated cost {estimated_cost} + items cost {existing_items_total} = {instance.total_amount}")
                    else:
                        # Только стоимость items
                        instance.total_amount = existing_items_total
                        logger.info(f"Recalculating total from existing items: {instance.total_amount}")
                
                instance.save(update_fields=["total_amount"])
            logger.info(f"Order {instance.id} updated successfully")
            return instance
        except Exception as e:
            logger.error(f"Error updating order {instance.id}: {e}", exc_info=True)
            logger.error(f"Validated data keys: {list(validated_data.keys()) if validated_data else 'None'}")
            raise

    def _upsert_items(self, order: Order, items_data: list[dict[str, Any]]) -> None:
        """Создает позиции заказа, автоматически рассчитывая quantity для техники из времени работы."""
        for item in items_data:
            item_data = item.copy()
            # Для техники автоматически рассчитываем количество часов из start_dt и end_dt
            if item_data.get("item_type") == OrderItem.ItemType.EQUIPMENT:
                if order.start_dt and order.end_dt:
                    duration_hours = _get_duration_hours(order)
                    # Округляем до 0.5 часа
                    item_data["quantity"] = _round_half_hour(duration_hours)
                    item_data["unit"] = "hour"
                elif order.start_dt:
                    # Если end_dt не указан, используем переданное quantity или 1
                    item_data["quantity"] = item_data.get("quantity", Decimal("1.00"))
                    item_data["unit"] = item_data.get("unit", "hour")
            # Для услуг с billing_mode="per_hour" также рассчитываем из времени
            elif item_data.get("item_type") == OrderItem.ItemType.SERVICE:
                metadata = item_data.get("metadata", {})
                if metadata.get("billing_mode") == "per_hour" and order.start_dt and order.end_dt:
                    duration_hours = _get_duration_hours(order)
                    item_data["quantity"] = _round_half_hour(duration_hours)
            OrderItem.objects.create(order=order, **item_data)

    def _generate_order_number(self) -> str:
        """Генерирует уникальный номер заявки, проверяя отсутствие дубликатов."""
        max_attempts = 100  # Максимальное количество попыток для избежания бесконечного цикла
        
        for attempt in range(max_attempts):
            # Получаем последнюю заявку по дате создания
            last = Order.objects.order_by("-created_at").first()
            next_seq = 1
            
            if last and last.number and last.number.isdigit():
                next_seq = int(last.number) + 1
            
            # Генерируем номер
            number = f"{next_seq:06d}"
            
            # Проверяем, существует ли уже заявка с таким номером
            if not Order.objects.filter(number=number).exists():
                logger.info(f"Generated unique order number: {number}")
                return number
            
            # Если номер существует, пробуем следующий
            logger.warning(f"Order number {number} already exists, trying next")
            next_seq += 1
        
        # Если не удалось сгенерировать уникальный номер за 100 попыток,
        # используем timestamp для гарантии уникальности
        import time
        timestamp = int(time.time())
        fallback_number = f"{timestamp:010d}"[-6:]  # Последние 6 цифр timestamp
        logger.warning(f"Could not generate sequential number, using fallback: {fallback_number}")
        return fallback_number


class OrderStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=OrderStatus.choices)
    comment = serializers.CharField(required=False, allow_blank=True)
    attachment_url = serializers.URLField(required=False, allow_blank=True)
    operator_salary = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True)


class OperatorSalarySerializer(serializers.Serializer):
    """Сериализатор для зарплаты оператора."""
    operator_id = serializers.IntegerField(help_text="ID оператора")
    salary = serializers.DecimalField(
        max_digits=12, decimal_places=2, required=True, help_text="Зарплата оператора"
    )


class OrderCompleteSerializer(serializers.Serializer):
    """Сериализатор для завершения заявки с добавлением элементов номенклатуры."""
    comment = serializers.CharField(required=False, allow_blank=True, help_text="Комментарий к завершению заявки")
    end_dt = serializers.DateTimeField(required=True, help_text="Дата и время окончания работ")
    operator_salary = serializers.DecimalField(
        max_digits=12, decimal_places=2, required=False, allow_null=True, help_text="Зарплата оператору (устаревшее, используйте operator_salaries)"
    )
    operator_salaries = OperatorSalarySerializer(
        many=True, required=False, help_text="Список зарплат для каждого оператора"
    )
    items = OrderItemSerializer(many=True, required=True, help_text="Список элементов номенклатуры (техника, инструменты, грунт). Для техники можно указать fuel_expense для каждой единицы.")
    
    def validate(self, attrs):
        """Валидация всех данных."""
        # Убеждаемся, что items валидированы правильно
        items = attrs.get("items", [])
        if not items:
            raise serializers.ValidationError({"items": "Необходимо добавить хотя бы один элемент номенклатуры"})
        return attrs
    
    def validate_items(self, value):
        """Валидация элементов заказа."""
        if not value:
            raise serializers.ValidationError("Необходимо добавить хотя бы один элемент номенклатуры")
        for item in value:
            # item_type может быть строкой или enum, нормализуем к строке для сравнения
            item_type = item.get("item_type")
            if isinstance(item_type, OrderItem.ItemType):
                item_type_str = item_type.value
            elif hasattr(item_type, 'value'):
                item_type_str = item_type.value
            else:
                item_type_str = str(item_type).lower()
            
            if item_type_str == "equipment":
                if not item.get("ref_id"):
                    raise serializers.ValidationError("Для техники необходимо указать ref_id")
                # Проверяем, что указаны смены или часы в metadata
                metadata = item.get("metadata", {})
                if not isinstance(metadata, dict):
                    metadata = {}
                shifts = Decimal(str(metadata.get("shifts", 0) or 0))
                hours = Decimal(str(metadata.get("hours", 0) or 0))
                if shifts <= 0 and hours <= 0:
                    raise serializers.ValidationError("Для техники необходимо указать количество смен или часов в metadata")
            elif item_type_str == "material":
                if not item.get("ref_id"):
                    raise serializers.ValidationError("Для материала необходимо указать ref_id")
                if not item.get("quantity") or Decimal(str(item.get("quantity", 0))) <= 0:
                    raise serializers.ValidationError("Для материала необходимо указать количество")
        return value


class OrderAttachmentSerializer(serializers.Serializer):
    file_name = serializers.CharField()
    content_type = serializers.CharField()


class OrderPricePreviewSerializer(serializers.Serializer):
    items = OrderItemSerializer(many=True)

    def create_snapshot(self) -> dict[str, Any]:
        total = sum(
            (
                (item.get("unit_price") or 0)
                * (item.get("quantity") or 1)
                - (item.get("discount") or 0)
            )
            for item in self.validated_data["items"]
        )
        return {"items": self.validated_data["items"], "total": total}


class OrderStatusLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source="actor.get_full_name", read_only=True)

    class Meta:
        model = OrderStatusLog
        fields = ("id", "from_status", "to_status", "actor", "actor_name", "comment", "attachment_url", "created_at")


class PhotoEvidenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = PhotoEvidence
        fields = "__all__"
        read_only_fields = ("id", "created_at", "updated_at")

