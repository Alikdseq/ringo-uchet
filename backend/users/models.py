from __future__ import annotations

from django.contrib.auth.models import AbstractUser, UserManager as DjangoUserManager
from django.db import models


class UserRole(models.TextChoices):
    ADMIN = "admin", "Администратор"
    MANAGER = "manager", "Менеджер"
    OPERATOR = "operator", "Оператор"


class UserManager(DjangoUserManager):
    """createsuperuser сразу получает role=admin."""

    def _create_user(self, username, email=None, password=None, **extra_fields):
        return super()._create_user(username, email, password, **extra_fields)

    def create_superuser(self, username, email=None, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", UserRole.ADMIN)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        # Гарантируем роль admin даже если передали другое значение
        extra_fields["role"] = UserRole.ADMIN
        return self._create_user(username, email, password, **extra_fields)


class User(AbstractUser):
    role = models.CharField(
        max_length=32,
        choices=UserRole.choices,
        default=UserRole.MANAGER,
        verbose_name="Роль",
        help_text="Роль пользователя в системе",
    )
    phone = models.CharField(
        max_length=32,
        unique=True,
        null=True,
        blank=True,
        verbose_name="Телефон",
        help_text="Номер телефона пользователя",
    )
    avatar = models.URLField(blank=True, verbose_name="Аватар", help_text="URL аватара пользователя")
    locale = models.CharField(
        max_length=8, default="ru", verbose_name="Язык", help_text="Предпочитаемый язык интерфейса"
    )
    position = models.CharField(
        max_length=120, blank=True, verbose_name="Должность", help_text="Должность сотрудника"
    )
    permissions_snapshot = models.JSONField(
        default=dict, blank=True, verbose_name="Снимок прав", help_text="JSON снимок прав доступа"
    )

    objects = UserManager()

    class Meta:
        verbose_name = "Пользователь"
        verbose_name_plural = "Пользователи"

    def __str__(self) -> str:
        return self.get_full_name() or self.username or self.email or str(self.pk)

    def save(self, *args, **kwargs):
        # Django superuser / staff-admin всегда имеют роль admin в приложении
        if self.is_superuser and self.role != UserRole.ADMIN:
            self.role = UserRole.ADMIN
        super().save(*args, **kwargs)

    @property
    def display_role(self) -> str:
        return self.get_role_display()

    def has_role(self, *roles: str) -> bool:
        return self.role in roles
