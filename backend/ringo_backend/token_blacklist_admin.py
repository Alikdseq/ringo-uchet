from __future__ import annotations

from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken

# Переопределяем verbose_name для Token Blacklist моделей
# Модели уже зарегистрированы в админке через rest_framework_simplejwt.token_blacklist.admin

OutstandingToken._meta.verbose_name = "Активный токен"
OutstandingToken._meta.verbose_name_plural = "Активные токены"

BlacklistedToken._meta.verbose_name = "Токен в чёрном списке"
BlacklistedToken._meta.verbose_name_plural = "Токены в чёрном списке"

