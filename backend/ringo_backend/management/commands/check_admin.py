"""
Команда для проверки доступности админки Django.
Использование: python manage.py check_admin
"""
from django.core.management.base import BaseCommand
from django.urls import reverse
from django.conf import settings
from django.contrib import admin


class Command(BaseCommand):
    help = "Проверка доступности Django admin"

    def handle(self, *args, **options):
        self.stdout.write("=" * 60)
        self.stdout.write(self.style.SUCCESS("Проверка Django Admin"))
        self.stdout.write("=" * 60)

        # Проверка настроек
        self.stdout.write("\n1. Настройки:")
        self.stdout.write(f"   DEBUG: {settings.DEBUG}")
        self.stdout.write(f"   ALLOWED_HOSTS: {settings.ALLOWED_HOSTS}")
        
        # Проверка ADMIN_ALLOWED_IPS
        admin_allowed_ips = getattr(settings, "ADMIN_ALLOWED_IPS", [])
        self.stdout.write(f"   ADMIN_ALLOWED_IPS: {admin_allowed_ips}")
        if not admin_allowed_ips:
            self.stdout.write(self.style.WARNING("   ⚠️  IP allowlist отключен (разрешен доступ всем)"))
        else:
            self.stdout.write(self.style.SUCCESS(f"   ✓ IP allowlist активен: {len(admin_allowed_ips)} IP(s)"))

        # Проверка middleware
        self.stdout.write("\n2. Middleware:")
        middleware_list = getattr(settings, "MIDDLEWARE", [])
        security_middleware = [m for m in middleware_list if "security" in m.lower()]
        if security_middleware:
            self.stdout.write(f"   Security middleware: {len(security_middleware)}")
            for mw in security_middleware:
                self.stdout.write(f"     - {mw}")
        else:
            self.stdout.write(self.style.WARNING("   ⚠️  Security middleware не найден"))

        # Проверка URL patterns
        self.stdout.write("\n3. URL Patterns:")
        try:
            from django.urls import get_resolver
            resolver = get_resolver()
            admin_urls = [p for p in resolver.url_patterns if 'admin' in str(p.pattern)]
            self.stdout.write(f"   Admin URL patterns найдено: {len(admin_urls)}")
            for url_pattern in admin_urls:
                self.stdout.write(f"     - {url_pattern.pattern}")
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"   ✗ Ошибка при проверке URL: {e}"))

        # Проверка admin site
        self.stdout.write("\n4. Admin Site:")
        try:
            admin_url = reverse("admin:index")
            self.stdout.write(self.style.SUCCESS(f"   ✓ Admin URL: {admin_url}"))
            self.stdout.write(f"   Site header: {admin.site.site_header}")
            self.stdout.write(f"   Site title: {admin.site.site_title}")
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"   ✗ Ошибка: {e}"))

        # Проверка зарегистрированных моделей
        self.stdout.write("\n5. Зарегистрированные модели:")
        registered_models = admin.site._registry.keys()
        self.stdout.write(f"   Моделей в админке: {len(registered_models)}")
        for model in list(registered_models)[:10]:  # Показываем первые 10
            self.stdout.write(f"     - {model._meta.app_label}.{model._meta.model_name}")

        # Рекомендации
        self.stdout.write("\n" + "=" * 60)
        self.stdout.write("Рекомендации:")
        self.stdout.write("=" * 60)
        
        if not admin_allowed_ips:
            self.stdout.write("✓ IP allowlist отключен - админка доступна всем (OK для разработки)")
        else:
            self.stdout.write("⚠️  IP allowlist активен - убедитесь, что ваш IP в списке разрешенных")
            self.stdout.write(f"   Разрешенные IP: {', '.join(admin_allowed_ips)}")
        
        self.stdout.write("\nДля доступа к админке:")
        self.stdout.write("  - Локально: http://localhost:8001/admin/")
        self.stdout.write("  - Через nginx: http://localhost/admin/")
        self.stdout.write("\n")

