from __future__ import annotations

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import viewsets
from rest_framework.filters import SearchFilter

from .models import Client
from .serializers import ClientSerializer


class ClientViewSet(viewsets.ModelViewSet):
    # Оптимизация: используем select_related/prefetch_related для уменьшения количества запросов
    queryset = Client.objects.all().select_related().prefetch_related()
    serializer_class = ClientSerializer
    filter_backends = (DjangoFilterBackend, SearchFilter)
    filterset_fields = ("is_active", "city")
    search_fields = ("name", "contact_person", "phone", "email")

