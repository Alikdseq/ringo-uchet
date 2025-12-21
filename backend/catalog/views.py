from __future__ import annotations

from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import viewsets
from rest_framework.filters import OrderingFilter, SearchFilter

from .models import Attachment, Equipment, MaterialItem, ServiceItem
from .serializers import (
    AttachmentSerializer,
    EquipmentSerializer,
    MaterialItemSerializer,
    ServiceItemSerializer,
)


@extend_schema_view(
    list=extend_schema(
        summary="Список техники",
        description="Получить список техники с фильтрацией по статусу",
        tags=["Catalog"],
    ),
    retrieve=extend_schema(
        summary="Детали техники",
        description="Получить детальную информацию о технике",
        tags=["Catalog"],
    ),
)
class EquipmentViewSet(viewsets.ModelViewSet):
    # Оптимизация: используем select_related/prefetch_related для уменьшения количества запросов
    queryset = Equipment.objects.all().select_related().prefetch_related()
    serializer_class = EquipmentSerializer
    filter_backends = (DjangoFilterBackend, SearchFilter, OrderingFilter)
    filterset_fields = ("status",)
    search_fields = ("code", "name", "description")
    ordering_fields = ("name", "code", "hourly_rate", "status")


@extend_schema_view(
    list=extend_schema(summary="Список услуг", description="Получить список услуг", tags=["Catalog"]),
    retrieve=extend_schema(summary="Детали услуги", description="Получить детальную информацию об услуге", tags=["Catalog"]),
)
class ServiceItemViewSet(viewsets.ModelViewSet):
    queryset = ServiceItem.objects.select_related("category").all()
    serializer_class = ServiceItemSerializer
    filter_backends = (DjangoFilterBackend, SearchFilter, OrderingFilter)
    filterset_fields = ("category", "is_active")
    search_fields = ("name", "category__name")
    ordering_fields = ("name", "price")


@extend_schema_view(
    list=extend_schema(summary="Список материалов", description="Получить список материалов", tags=["Catalog"]),
    retrieve=extend_schema(summary="Детали материала", description="Получить детальную информацию о материале", tags=["Catalog"]),
)
class MaterialItemViewSet(viewsets.ModelViewSet):
    # Оптимизация: используем select_related/prefetch_related для уменьшения количества запросов
    queryset = MaterialItem.objects.all().select_related().prefetch_related()
    serializer_class = MaterialItemSerializer
    filter_backends = (DjangoFilterBackend, SearchFilter, OrderingFilter)
    filterset_fields = ("is_active", "category")
    search_fields = ("name", "supplier")
    ordering_fields = ("name", "price")
    
    def get_queryset(self):
        """Переопределяем queryset для правильной фильтрации"""
        qs = MaterialItem.objects.all().select_related().prefetch_related()
        # По умолчанию показываем только активные, если не указано иное
        is_active_param = self.request.query_params.get("is_active")
        if is_active_param is None:
            # Если параметр is_active не указан, показываем только активные
            qs = qs.filter(is_active=True)
        return qs


@extend_schema_view(
    list=extend_schema(
        summary="Список навесок",
        description="Получить список навесок с фильтрацией по технике и статусу",
        tags=["Catalog"],
    ),
    retrieve=extend_schema(
        summary="Детали навески",
        description="Получить детальную информацию о навеске",
        tags=["Catalog"],
    ),
)
class AttachmentViewSet(viewsets.ModelViewSet):
    queryset = Attachment.objects.select_related("equipment").all()
    serializer_class = AttachmentSerializer
    filter_backends = (DjangoFilterBackend, SearchFilter, OrderingFilter)
    filterset_fields = ("status", "equipment")
    search_fields = ("name", "equipment__code", "equipment__name")
    ordering_fields = ("name", "equipment__code", "status")



