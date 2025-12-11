from __future__ import annotations

import logging
import os
from decimal import Decimal
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, NoCredentialsError
from django.db import models, transaction
from django.utils import timezone
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from audit.models import AuditAction
from audit.permissions import IsOwnerOrManager
from audit.services import log_action
from catalog.models import Equipment
from finance.models import Expense, Invoice, SalaryRecord
from finance.tasks import generate_invoice_pdf
from notifications.tasks import notify_order_created, notify_order_status_changed
from .models import Order, OrderItem, OrderStatus, OrderStatusLog, PhotoEvidence
from .serializers import (
    OrderAttachmentSerializer,
    OrderCompleteSerializer,
    OrderPricePreviewSerializer,
    OrderSerializer,
    OrderStatusLogSerializer,
    OrderStatusSerializer,
)
from .services.pricing import calculate_order_total

logger = logging.getLogger(__name__)


@extend_schema_view(
    list=extend_schema(
        summary="Список заявок",
        description="Получить список заявок. Администратор и менеджер видят все заявки, оператор - только назначенные ему.",
        tags=["Orders"],
    ),
    retrieve=extend_schema(
        summary="Детали заявки",
        description="Получить детальную информацию о заявке",
        tags=["Orders"],
    ),
    create=extend_schema(
        summary="Создать заявку",
        description="Создать новую заявку. Требуется роль Manager или Admin.",
        tags=["Orders"],
    ),
    update=extend_schema(
        summary="Обновить заявку",
        description="Полное обновление заявки",
        tags=["Orders"],
    ),
    partial_update=extend_schema(
        summary="Частичное обновление заявки",
        description="Частичное обновление заявки",
        tags=["Orders"],
    ),
    destroy=extend_schema(
        summary="Удалить заявку",
        description="Удалить заявку. Требуется роль Admin.",
        tags=["Orders"],
    ),
)
class OrderViewSet(viewsets.ModelViewSet):
    queryset = Order.objects.select_related("client", "manager", "operator").prefetch_related("items", "status_logs")
    serializer_class = OrderSerializer
    permission_classes = [IsOwnerOrManager]
    
    def perform_update(self, serializer: OrderSerializer) -> None:
        """Обработка обновления заявки с логированием ошибок"""
        try:
            instance = serializer.instance
            old_status = instance.status if instance else None
            
            # Сохраняем изменения
            order = serializer.save()
            
            # Логируем изменение статуса, если оно произошло
            if old_status and order.status != old_status:
                log_action(
                    actor=self.request.user,
                    action=AuditAction.STATUS_CHANGE,
                    entity_type="Order",
                    entity_id=str(order.id),
                    payload={
                        "from_status": old_status,
                        "to_status": order.status,
                    },
                    ip_address=self._get_client_ip(),
                    user_agent=self.request.META.get("HTTP_USER_AGENT", ""),
                    request_id=getattr(self.request, "request_id", None),
                )
        except Exception as e:
            logger.error(f"Error updating order: {e}", exc_info=True)
            logger.error(f"Request data: {self.request.data}")
            logger.error(f"User: {self.request.user}")
            logger.error(f"Instance: {serializer.instance}")
            raise

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user

        # Фильтрация по ролям
        if user.is_authenticated:
            if user.role == "admin" or user.is_superuser:
                # Админ видит всё
                pass
            elif user.role == "manager":
                # Менеджер видит все заявки (как администратор)
                pass
            elif user.role == "operator":
                # Оператор видит только назначенные ему заявки (из operators или старый operator)
                from django.db.models import Q
                qs = qs.filter(Q(operators=user) | Q(operator=user)).distinct()
            else:
                # Остальные не видят ничего
                qs = qs.none()

        # Исключаем удаленные заявки для не-админов
        if user.role not in ["admin", "manager"] and not user.is_superuser:
            qs = qs.exclude(status=OrderStatus.DELETED)
        
        status_param = self.request.query_params.get("status")
        if status_param:
            qs = qs.filter(status=status_param)
        return qs

    def perform_create(self, serializer: OrderSerializer) -> None:
        try:
            order = serializer.save()
            # Логирование создания заказа
            log_action(
                actor=self.request.user,
                action=AuditAction.CREATE,
                entity_type="Order",
                entity_id=str(order.id),
                payload={"number": order.number, "status": order.status, "total_amount": str(order.total_amount)},
                ip_address=self._get_client_ip(),
                user_agent=self.request.META.get("HTTP_USER_AGENT", ""),
                request_id=getattr(self.request, "request_id", None),
            )
            # Уведомление о создании заказа
            notify_order_created.delay(str(order.id))
        except Exception as e:
            logger.error(f"Error creating order: {e}", exc_info=True)
            logger.error(f"Request data: {self.request.data}")
            logger.error(f"User: {self.request.user}")
            raise

    @extend_schema(
        summary="Изменить статус заявки",
        description="Изменить статус заявки с логированием в OrderStatusLog. Требуется роль Manager/Operator.",
        request=OrderStatusSerializer,
        responses={
            200: OrderStatusSerializer,
            400: {"description": "Недопустимый переход статуса"},
            403: {"description": "Недостаточно прав"},
        },
        tags=["Orders"],
    )
    @action(detail=True, methods=["patch"], url_path="status")
    def change_status(self, request, pk=None):
        order = self.get_object()
        serializer = OrderStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        target_status = serializer.validated_data["status"]
        try:
            self._validate_status_transition(order.status, target_status)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        OrderStatusLog.objects.create(
            order=order,
            from_status=order.status,
            to_status=target_status,
            actor=request.user,
            comment=serializer.validated_data.get("comment", ""),
            attachment_url=serializer.validated_data.get("attachment_url", ""),
        )
        old_status = order.status
        order.status = target_status
        # end_dt устанавливается только при завершении через /complete/
        order.save(update_fields=["status"])
        
        # Финансовые записи создаются только при завершении через /complete/
        
        # Логирование изменения статуса
        log_action(
            actor=request.user,
            action=AuditAction.STATUS_CHANGE,
            entity_type="Order",
            entity_id=str(order.id),
            payload={
                "from_status": old_status,
                "to_status": target_status,
                "comment": serializer.validated_data.get("comment", ""),
            },
            ip_address=self._get_client_ip(),
            user_agent=request.META.get("HTTP_USER_AGENT", ""),
            request_id=getattr(request, "request_id", None),
        )
        # Уведомление об изменении статуса
        notify_order_status_changed.delay(
            str(order.id),
            target_status,
            serializer.validated_data.get("comment", ""),
        )
        return Response(
            {
                "status": order.status,
                "logs": OrderStatusLogSerializer(order.status_logs.all(), many=True).data,
            }
        )

    @extend_schema(
        summary="Загрузить вложение",
        description="Получить presigned URL для загрузки файла в S3. Требуется роль Operator/Manager.",
        request=OrderAttachmentSerializer,
        responses={
            200: {"description": "Presigned POST URL для загрузки"},
            500: {"description": "Ошибка генерации URL"},
        },
        tags=["Orders"],
    )
    @action(detail=True, methods=["post"], url_path="attachments")
    def upload_attachment(self, request, pk=None):
        serializer = OrderAttachmentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        order = self.get_object()
        signed = self._generate_presigned_post(
            serializer.validated_data["file_name"],
            serializer.validated_data["content_type"],
        )
        if not signed:
            return Response({"detail": "Unable to generate upload URL"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        key = signed["fields"]["key"]
        order.attachments.append({"key": key, "uploaded_by": request.user.id})
        order.save(update_fields=["attachments"])
        # Логирование загрузки файла
        log_action(
            actor=request.user,
            action=AuditAction.FILE_UPLOAD,
            entity_type="Order",
            entity_id=str(order.id),
            payload={"file_name": serializer.validated_data["file_name"], "s3_key": key},
            ip_address=self._get_client_ip(),
            user_agent=request.META.get("HTTP_USER_AGENT", ""),
            request_id=getattr(request, "request_id", None),
        )
        return Response(signed)

    @extend_schema(
        summary="Предпросмотр расчёта стоимости",
        description="Рассчитать стоимость заявки без сохранения. Возвращает snapshot с детализацией.",
        request=OrderPricePreviewSerializer,
        responses={
            200: {"description": "Snapshot расчёта стоимости"},
        },
        tags=["Orders"],
    )
    @action(detail=True, methods=["post"], url_path="calculate/preview")
    def calculate_preview(self, request, pk=None):
        order = self.get_object()
        serializer = OrderPricePreviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        snapshot = serializer.create_snapshot()
        return Response(snapshot)

    @extend_schema(
        summary="Сгенерировать счёт",
        description="Создать счёт и запустить Celery задачу для генерации PDF. Требуется роль Manager/Admin.",
        responses={
            200: {"description": "ID счёта и task_id для отслеживания генерации"},
        },
        tags=["Orders", "Finance"],
    )
    @extend_schema(
        summary="Завершить заявку",
        description="Завершить заявку с добавлением элементов номенклатуры, расходов и зарплаты. Требуется роль Operator/Manager.",
        request=OrderCompleteSerializer,
        responses={
            200: OrderSerializer,
            400: {"description": "Ошибка валидации"},
            403: {"description": "Недостаточно прав"},
        },
        tags=["Orders"],
    )
    @action(detail=True, methods=["post"], url_path="complete")
    def complete_order(self, request, pk=None):
        """Завершает заявку с добавлением элементов номенклатуры и расчетом стоимости."""
        order = self.get_object()
        
        # Проверяем, что заявка в статусе IN_PROGRESS
        if order.status != OrderStatus.IN_PROGRESS:
            return Response(
                {"detail": f"Заявка должна быть в статусе 'В работе' для завершения. Текущий статус: {order.status}"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Логируем входящие данные для отладки
        logger.info(f"Complete order request data: {request.data}")
        logger.info(f"Items in request: {request.data.get('items', [])}")
        
        serializer = OrderCompleteSerializer(data=request.data)
        if not serializer.is_valid():
            # Логируем ошибки валидации для отладки
            logger.error(f"Validation errors: {serializer.errors}")
            logger.error(f"Request data: {request.data}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            with transaction.atomic():
                # Устанавливаем дату окончания
                order.end_dt = serializer.validated_data["end_dt"]
                
                # Удаляем старые items, если есть
                order.items.all().delete()
                
                # Добавляем новые items из формы завершения
                items_data = serializer.validated_data["items"]
                for item_data in items_data:
                    try:
                        # Нормализуем item_type для сравнения (может быть строкой или enum)
                        item_type = item_data.get("item_type")
                        if isinstance(item_type, OrderItem.ItemType):
                            item_type_str = item_type.value
                        elif hasattr(item_type, 'value'):
                            item_type_str = item_type.value
                        else:
                            item_type_str = str(item_type).lower()
                        
                        # Для техники получаем данные из Equipment и используем введенные пользователем смены/часы
                        if item_type_str == "equipment":
                            try:
                                equipment = Equipment.objects.get(id=item_data["ref_id"])
                                
                                # Получаем смены и часы из metadata (введенные пользователем)
                                metadata = item_data.get("metadata", {})
                                if not isinstance(metadata, dict):
                                    metadata = {}
                                shifts = Decimal(str(metadata.get("shifts", 0) or 0))
                                hours = Decimal(str(metadata.get("hours", 0) or 0))
                                
                                # Сохраняем информацию о сменах и часах в metadata
                                item_data["metadata"] = {
                                    **metadata,
                                    "shifts": float(shifts),
                                    "hours": float(hours),
                                    "daily_rate": float(equipment.daily_rate or 0),
                                }
                                
                                # Устанавливаем обязательные поля с правильными типами
                                # ВАЖНО: quantity для техники НЕ преобразуем смены в часы!
                                # Используем сумму смен и часов только для визуального представления
                                # Реальные расчеты выполняются через metadata (shifts, hours, daily_rate)
                                # и line_total из сериализатора
                                quantity_for_display = shifts + hours  # Просто сумма, не преобразование!
                                
                                # Получаем расходы на топливо для данной техники
                                fuel_expense = item_data.get("fuel_expense")
                                fuel_expense_decimal = None
                                if fuel_expense is not None:
                                    fuel_expense_decimal = Decimal(str(fuel_expense))
                                
                                # Получаем расходы на ремонт техники
                                repair_expense = item_data.get("repair_expense")
                                repair_expense_decimal = None
                                if repair_expense is not None:
                                    repair_expense_decimal = Decimal(str(repair_expense))
                                
                                OrderItem.objects.create(
                                    order=order,
                                    item_type=OrderItem.ItemType.EQUIPMENT,
                                    ref_id=item_data["ref_id"],
                                    name_snapshot=equipment.name,
                                    quantity=Decimal(str(quantity_for_display)),
                                    unit="hour",  # Единица для совместимости, но не используется для расчетов
                                    unit_price=Decimal(str(equipment.hourly_rate or 0)),
                                    tax_rate=Decimal(str(item_data.get("tax_rate", 0.0))),
                                    discount=Decimal(str(item_data.get("discount", 0.0))),
                                    fuel_expense=fuel_expense_decimal,
                                    repair_expense=repair_expense_decimal,
                                    metadata=item_data["metadata"],
                                )
                            except Equipment.DoesNotExist:
                                logger.warning(f"Equipment with id {item_data.get('ref_id')} not found, skipping item")
                                continue
                            except Exception as e:
                                logger.error(f"Error creating equipment item: {e}", exc_info=True)
                                raise
                        # Для материалов (грунт, инструменты, навески) получаем данные из MaterialItem
                        elif item_type_str == "material":
                            try:
                                from catalog.models import MaterialItem
                                material = MaterialItem.objects.get(id=item_data["ref_id"])
                                
                                # Сохраняем категорию материала в metadata для правильного отображения
                                metadata = item_data.get("metadata", {})
                                if not isinstance(metadata, dict):
                                    metadata = {}
                                metadata["material_category"] = material.category
                                
                                # Устанавливаем обязательные поля с правильными типами
                                OrderItem.objects.create(
                                    order=order,
                                    item_type=OrderItem.ItemType.MATERIAL,
                                    ref_id=item_data["ref_id"],
                                    name_snapshot=material.name,
                                    quantity=Decimal(str(item_data.get("quantity", 1.0))),
                                    unit=material.unit,
                                    unit_price=Decimal(str(material.price)),
                                    tax_rate=Decimal(str(item_data.get("tax_rate", 0.0))),
                                    discount=Decimal(str(item_data.get("discount", 0.0))),
                                    metadata=metadata,
                                )
                            except MaterialItem.DoesNotExist:
                                logger.warning(f"MaterialItem with id {item_data.get('ref_id')} not found, skipping item")
                                continue
                            except Exception as e:
                                logger.error(f"Error creating material item: {e}", exc_info=True)
                                raise
                        else:
                            # Для других типов (если есть) просто создаем как есть
                            item_type_enum = OrderItem.ItemType.EQUIPMENT  # По умолчанию
                            if isinstance(item_data.get("item_type"), str):
                                try:
                                    item_type_enum = OrderItem.ItemType(item_data["item_type"])
                                except (ValueError, KeyError):
                                    logger.warning(f"Unknown item_type: {item_data.get('item_type')}, using EQUIPMENT")
                            
                            # Устанавливаем значения по умолчанию для обязательных полей
                            OrderItem.objects.create(
                                order=order,
                                item_type=item_type_enum,
                                ref_id=item_data.get("ref_id"),
                                name_snapshot=item_data.get("name_snapshot", "Не указано"),
                                quantity=Decimal(str(item_data.get("quantity", 1.0))),
                                unit=item_data.get("unit", "pcs"),
                                unit_price=Decimal(str(item_data.get("unit_price", 0.0))),
                                tax_rate=Decimal(str(item_data.get("tax_rate", 0.0))),
                                discount=Decimal(str(item_data.get("discount", 0.0))),
                                metadata=item_data.get("metadata", {}),
                            )
                    except Exception as e:
                        logger.error(f"Error processing item: {item_data}, error: {e}", exc_info=True)
                        # Продолжаем обработку других items, но логируем ошибку
                        continue
                
                # Пересчитываем общую стоимость
                order.total_amount = calculate_order_total(order)
                
                # Обновляем статус
                old_status = order.status
                order.status = OrderStatus.COMPLETED
                order.save(update_fields=["end_dt", "status", "total_amount"])
                
                # Логируем изменение статуса
                OrderStatusLog.objects.create(
                    order=order,
                    from_status=old_status,
                    to_status=OrderStatus.COMPLETED,
                    actor=request.user,
                    comment=serializer.validated_data.get("comment", ""),
                )
                
                # Создаем финансовые записи
                self._create_financial_records(order, serializer.validated_data, request.user)
                
                # Логирование в аудит
                log_action(
                    actor=request.user,
                    action=AuditAction.STATUS_CHANGE,
                    entity_type="Order",
                    entity_id=str(order.id),
                    payload={
                        "from_status": old_status,
                        "to_status": OrderStatus.COMPLETED,
                        "comment": serializer.validated_data.get("comment", ""),
                        "total_amount": str(order.total_amount),
                    },
                    ip_address=self._get_client_ip(),
                    user_agent=request.META.get("HTTP_USER_AGENT", ""),
                    request_id=getattr(request, "request_id", None),
                )
                
                # Уведомление о завершении заявки
                notify_order_status_changed.delay(str(order.id), old_status, OrderStatus.COMPLETED)
                
                # Очищаем кэш отчетов для обновления данных на главном экране
                from finance.api import clear_reports_cache
                clear_reports_cache()
        except Exception as e:
            logger.error(f"Error completing order {order.id}: {e}", exc_info=True)
            return Response(
                {"detail": f"Ошибка при завершении заявки: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        # Возвращаем обновленную заявку
        try:
            response_serializer = OrderSerializer(order)
            return Response(response_serializer.data)
        except Exception as e:
            logger.error(f"Error serializing order {order.id}: {e}", exc_info=True)
            return Response(
                {"detail": f"Ошибка при сериализации заявки: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @extend_schema(
        summary="Получить чек",
        description="Генерирует PDF чек для завершенной заявки. Требуется роль Manager/Admin.",
        responses={
            200: {"description": "PDF файл чека"},
            400: {"description": "Заявка не завершена"},
        },
        tags=["Orders", "Finance"],
    )
    @action(detail=True, methods=["get"], url_path="receipt")
    def get_receipt(self, request, pk=None):
        """Генерирует PDF чек для завершенной заявки."""
        from django.http import HttpResponse
        from finance.exporters import generate_order_receipt_pdf
        
        # Получаем заказ (get_object() использует queryset с оптимизацией)
        order = self.get_object()
        
        if order.status != OrderStatus.COMPLETED:
            return Response(
                {"detail": "Чек можно получить только для завершенных заявок"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Генерируем PDF
            pdf_content = generate_order_receipt_pdf(order)
            
            if not pdf_content or len(pdf_content) == 0:
                logger.error(f"Generated PDF is empty for order {order.id}")
                return Response(
                    {"detail": "Сгенерированный PDF пуст"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            # Для бинарных данных (PDF) используем HttpResponse из Django
            # Response из DRF не может напрямую работать с bytes
            filename = f"receipt_{order.number}.pdf"
            # Экранируем имя файла для безопасной передачи в заголовке
            import urllib.parse
            encoded_filename = urllib.parse.quote(filename.encode('utf-8'))
            
            response = HttpResponse(
                pdf_content,
                content_type="application/pdf"
            )
            response["Content-Disposition"] = f'attachment; filename="{filename}"; filename*=UTF-8\'\'{encoded_filename}'
            response["Content-Length"] = str(len(pdf_content))
            return response
        except ValueError as e:
            # ValueError - это наши кастомные ошибки с понятными сообщениями
            logger.error(f"Error generating receipt for order {order.id}: {e}", exc_info=True)
            return Response(
                {"detail": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        except Exception as e:
            logger.error(f"Unexpected error generating receipt for order {order.id}: {e}", exc_info=True)
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return Response(
                {"detail": f"Ошибка при генерации чека: {str(e)}. Проверьте логи сервера для деталей."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=True, methods=["post"], url_path="generate_invoice")
    def generate_invoice(self, request, pk=None):
        order = self.get_object()
        invoice, _ = Invoice.objects.get_or_create(order=order, defaults={"amount": order.total_amount})
        task = generate_invoice_pdf.delay(invoice.id)
        return Response({"invoice_id": invoice.id, "task_id": task.id})
    
    @extend_schema(
        summary="Удалить заявку",
        description="Перевести заявку в статус 'Удалён'. Требуется роль Admin/Manager.",
        responses={
            200: OrderSerializer,
            400: {"description": "Недопустимый переход статуса"},
            403: {"description": "Недостаточно прав"},
        },
        tags=["Orders"],
    )
    @action(detail=True, methods=["post"], url_path="delete")
    def delete_order(self, request, pk=None):
        """Переводит заявку в статус DELETED."""
        order = self.get_object()
        
        # Проверяем права: только админ или менеджер могут удалять заявки
        user = request.user
        if user.role not in ["admin", "manager"] and not user.is_superuser:
            return Response(
                {"detail": "Недостаточно прав для удаления заявки"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Проверяем, что заявка еще не удалена
        if order.status == OrderStatus.DELETED:
            return Response(
                {"detail": "Заявка уже удалена"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Валидируем переход статуса
            self._validate_status_transition(order.status, OrderStatus.DELETED)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        
        # Логируем изменение статуса
        old_status = order.status
        OrderStatusLog.objects.create(
            order=order,
            from_status=old_status,
            to_status=OrderStatus.DELETED,
            actor=request.user,
            comment=f"Заявка удалена пользователем {request.user.get_full_name()}",
        )
        
        # Меняем статус
        order.status = OrderStatus.DELETED
        order.save(update_fields=["status"])
        
        # Логирование в аудит
        log_action(
            actor=request.user,
            action=AuditAction.STATUS_CHANGE,
            entity_type="Order",
            entity_id=str(order.id),
            payload={
                "from_status": old_status,
                "to_status": OrderStatus.DELETED,
                "comment": "Заявка удалена",
            },
            ip_address=self._get_client_ip(),
            user_agent=request.META.get("HTTP_USER_AGENT", ""),
            request_id=getattr(request, "request_id", None),
        )
        
        # Уведомление об изменении статуса
        notify_order_status_changed.delay(
            str(order.id),
            old_status,
            OrderStatus.DELETED,
        )
        
        # Очищаем кэш отчетов для обновления данных
        from finance.api import clear_reports_cache
        clear_reports_cache()
        
        serializer = OrderSerializer(order)
        return Response(serializer.data)

    def _get_client_ip(self) -> str | None:
        """Получение IP адреса клиента"""
        x_forwarded_for = self.request.META.get("HTTP_X_FORWARDED_FOR")
        if x_forwarded_for:
            return x_forwarded_for.split(",")[0].strip()
        return self.request.META.get("REMOTE_ADDR")

    def _create_financial_records(self, order: Order, validated_data: dict[str, Any], user) -> None:
        """Создает финансовые записи (расходы и зарплату) при завершении заявки"""
        from decimal import Decimal
        from django.db import transaction
        from users.models import User
        
        with transaction.atomic():
            # Вычисляем часы работы
            hours_worked = Decimal("0")
            if order.start_dt and order.end_dt:
                delta = order.end_dt - order.start_dt
                hours_worked = Decimal(str(delta.total_seconds() / 3600))
            
            # Создаем записи зарплаты для каждого оператора из operator_salaries
            operator_salaries = validated_data.get("operator_salaries", [])
            if operator_salaries:
                for op_salary_data in operator_salaries:
                    operator_id = op_salary_data.get("operator_id")
                    salary_amount = Decimal(str(op_salary_data.get("salary", 0)))
                    
                    if operator_id and salary_amount > 0:
                        try:
                            operator = User.objects.get(id=operator_id)
                            SalaryRecord.objects.get_or_create(
                                order=order,
                                user=operator,
                                defaults={
                                    "rate_type": SalaryRecord.RateType.FIXED,
                                    "rate_value": salary_amount,
                                    "amount": salary_amount,
                                    "hours_worked": hours_worked,
                                    "status": SalaryRecord.SalaryStatus.PENDING,
                                    "notes": f"Зарплата за заказ {order.number}",
                                },
                            )
                        except User.DoesNotExist:
                            logger.warning(f"Operator with id {operator_id} not found for salary record")
                            continue
            
            # Для обратной совместимости: если указан operator_salary (старое поле)
            operator_salary = validated_data.get("operator_salary")
            if operator_salary:
                # Используем первого оператора из operators или старый operator
                operator = None
                if order.operators.exists():
                    operator = order.operators.first()
                elif order.operator:
                    operator = order.operator
                
                if operator:
                    SalaryRecord.objects.get_or_create(
                        order=order,
                        user=operator,
                        defaults={
                            "rate_type": SalaryRecord.RateType.FIXED,
                            "rate_value": Decimal(str(operator_salary)),
                            "amount": Decimal(str(operator_salary)),
                            "hours_worked": hours_worked,
                            "status": SalaryRecord.SalaryStatus.PENDING,
                            "notes": f"Зарплата за заказ {order.number}",
                        },
                    )
            
            # Создаем расходы на топливо и ремонт для каждой техники отдельно
            # Проходим по всем позициям техники и создаем расходы для каждой
            equipment_items = order.items.filter(item_type=OrderItem.ItemType.EQUIPMENT)
            for item in equipment_items:
                if not item.ref_id:
                    continue
                try:
                    equipment = Equipment.objects.get(id=item.ref_id)
                    # Создаем расходы на топливо
                    if item.fuel_expense and item.fuel_expense > 0:
                        Expense.objects.create(
                            order=order,
                            equipment=equipment,
                            category="fuel",
                            amount=item.fuel_expense,
                            date=timezone.now().date(),
                            comment=f"Расходы на топливо для техники {equipment.name} (заказ {order.number})",
                            reported_by=user,
                        )
                    # Создаем расходы на ремонт
                    if item.repair_expense and item.repair_expense > 0:
                        Expense.objects.create(
                            order=order,
                            equipment=equipment,
                            category="repair",
                            amount=item.repair_expense,
                            date=timezone.now().date(),
                            comment=f"Расходы на ремонт техники {equipment.name} (заказ {order.number})",
                            reported_by=user,
                        )
                except Equipment.DoesNotExist:
                    logger.warning(f"Equipment with id {item.ref_id} not found for expense")
                    continue

    def _validate_status_transition(self, current: str, new: str) -> None:
        """Валидация перехода статуса. Завершение (COMPLETED) должно происходить через endpoint /complete/"""
        allowed = {
            OrderStatus.CREATED: {OrderStatus.APPROVED, OrderStatus.CANCELLED, OrderStatus.DELETED},
            OrderStatus.APPROVED: {OrderStatus.IN_PROGRESS, OrderStatus.CANCELLED, OrderStatus.DELETED},
            OrderStatus.IN_PROGRESS: {OrderStatus.CANCELLED, OrderStatus.DELETED},  # COMPLETED только через /complete/
            OrderStatus.COMPLETED: {OrderStatus.DELETED},  # Удаление возможно даже после завершения
            OrderStatus.CANCELLED: {OrderStatus.DELETED},
            OrderStatus.DELETED: set(),  # Из удаленного нельзя перейти в другой статус
        }
        # Для обратной совместимости: если статус DRAFT, разрешаем переход в CREATED, CANCELLED или DELETED
        if current == OrderStatus.DRAFT:
            allowed[OrderStatus.DRAFT] = {OrderStatus.CREATED, OrderStatus.CANCELLED, OrderStatus.DELETED}
        if new not in allowed.get(current, set()):
            if new == OrderStatus.COMPLETED and current == OrderStatus.IN_PROGRESS:
                raise ValueError("Для завершения заявки используйте endpoint /complete/ с указанием элементов номенклатуры")
            raise ValueError(f"Cannot transition from {current} to {new}")

    def _generate_presigned_post(self, filename: str, content_type: str) -> dict[str, Any] | None:
        bucket = os.getenv("AWS_BUCKET")
        if not bucket:
            return {
                "upload_type": "direct",
                "fields": {},
                "url": "http://localhost/upload-stub",
            }
        s3 = boto3.client(
            "s3",
            endpoint_url=os.getenv("AWS_S3_ENDPOINT_URL"),
            region_name=os.getenv("AWS_S3_REGION_NAME"),
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
        )
        key = f"orders/{timezone.now().date()}/{filename}"
        try:
            return s3.generate_presigned_post(
                Bucket=bucket,
                Key=key,
                Fields={"Content-Type": content_type},
                Conditions=[{"Content-Type": content_type}],
                ExpiresIn=3600,
            )
        except (BotoCoreError, NoCredentialsError) as exc:
            logger.exception("Failed to generate presigned URL: %s", exc)
            return None


