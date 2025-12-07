from __future__ import annotations

from rest_framework import serializers

from .models import Client


class ClientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Client
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at")

