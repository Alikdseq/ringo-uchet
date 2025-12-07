from __future__ import annotations

from django.contrib import admin
from django.contrib.admin.apps import AdminConfig


class RingoAdminConfig(AdminConfig):
    default_site = "ringo_backend.admin.RingoAdminSite"


class RingoAdminSite(admin.AdminSite):
    site_header = "Ringo Uchet Administration"
    site_title = "Ringo Uchet Admin"
    index_title = "Welcome to Ringo Uchet Administration"

