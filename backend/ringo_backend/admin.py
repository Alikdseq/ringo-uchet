from __future__ import annotations

from django.contrib import admin
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken

# Отключаем регистрацию токенов в админке по требованию
try:
    admin.site.unregister(OutstandingToken)
except admin.sites.NotRegistered:
    pass

try:
    admin.site.unregister(BlacklistedToken)
except admin.sites.NotRegistered:
    pass

