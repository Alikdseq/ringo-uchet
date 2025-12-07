"""
Команда для добавления начальных данных в базу данных:
- Техника с ценами
- Услуги
- Грунт и инструменты
- Операторы

Использование: python manage.py seed_data
"""
from django.core.management.base import BaseCommand
from django.db import transaction
from catalog.models import Equipment, ServiceCategory, ServiceItem, MaterialItem
from users.models import User, UserRole


class Command(BaseCommand):
    help = "Добавление начальных данных в базу данных"

    def handle(self, *args, **options):
        self.stdout.write("=" * 60)
        self.stdout.write(self.style.SUCCESS("Начало добавления данных в БД"))
        self.stdout.write("=" * 60)

        with transaction.atomic():
            # 1. Добавление техники
            self.stdout.write("\n1. Добавление техники...")
            equipment_data = [
                {
                    "code": "EXC-MST-644S",
                    "name": "Экскаватор-погрузчик MST 644 S",
                    "hourly_rate": 2450.00,
                    "daily_rate": 30000.00,
                },
                {
                    "code": "EXC-SANY-BHL95",
                    "name": "Экскаватор-погрузчик Sany BHL95",
                    "hourly_rate": 2450.00,
                    "daily_rate": 25000.00,
                },
                {
                    "code": "EXC-SUNY-SY35U",
                    "name": "Мини-экскаватор Suny SY35U",
                    "hourly_rate": 2450.00,
                    "daily_rate": 23000.00,
                },
                {
                    "code": "MAN-JAC-N120",
                    "name": "Манипулятор JAC N120",
                    "hourly_rate": 2450.00,
                    "daily_rate": 6000.00,
                },
                {
                    "code": "MAN-KAMAZ",
                    "name": "Манипулятор на базе Камаз",
                    "hourly_rate": 2450.00,
                    "daily_rate": 8000.00,
                },
                {
                    "code": "LOAD-SUNWARD",
                    "name": "Мини-погрузчик Sunward гусеничный",
                    "hourly_rate": 2450.00,
                    "daily_rate": 25000.00,
                },
                {
                    "code": "LOAD-ZOOMLION",
                    "name": "Мини-погрузчик Zoomlion",
                    "hourly_rate": 2450.00,
                    "daily_rate": 23000.00,
                },
                {
                    "code": "DUMP-SHACMAN-L3000",
                    "name": "Самосвал Shacman L3000",
                    "hourly_rate": 2450.00,
                    "daily_rate": 6000.00,
                },
                {
                    "code": "DUMP-SHACMAN-X3000",
                    "name": "Самосвал Shacman X3000",
                    "hourly_rate": 2450.00,
                    "daily_rate": 10000.00,
                },
                {
                    "code": "WRECK-FAW-3250",
                    "name": "Ломовоз FAW 3250",
                    "hourly_rate": 2450.00,
                    "daily_rate": 20000.00,
                },
                {
                    "code": "TOW-ISUZU",
                    "name": "Эвакуатор ISUZU",
                    "hourly_rate": 2450.00,
                    "daily_rate": 3000.00,
                },
                {
                    "code": "TRACTOR-MINI",
                    "name": "Мини-трактор",
                    "hourly_rate": 2450.00,
                    "daily_rate": 1000.00,
                },
            ]

            equipment_count = 0
            for eq_data in equipment_data:
                equipment, created = Equipment.objects.get_or_create(
                    code=eq_data["code"],
                    defaults={
                        "name": eq_data["name"],
                        "hourly_rate": eq_data["hourly_rate"],
                        "daily_rate": eq_data["daily_rate"],
                        "status": "available",
                    },
                )
                if created:
                    equipment_count += 1
                    self.stdout.write(f"   ✓ Добавлена техника: {equipment.name}")
                else:
                    # Обновляем существующую технику
                    equipment.hourly_rate = eq_data["hourly_rate"]
                    equipment.daily_rate = eq_data["daily_rate"]
                    equipment.name = eq_data["name"]
                    equipment.save()
                    self.stdout.write(f"   ↻ Обновлена техника: {equipment.name}")

            self.stdout.write(self.style.SUCCESS(f"   Всего техники: {equipment_count} добавлено, {len(equipment_data) - equipment_count} обновлено"))

            # 2. Добавление категорий услуг
            self.stdout.write("\n2. Добавление категорий услуг...")
            category_mapping = {
                "Благоустройство": ["Благоустройство дворов", "Планировка и очистка участка", "Покос травы мульчером"],
                "Копка": ["Копка траншей", "Копка котлована", "Копка под фундамент"],
                "Канализация": ["Канализация под ключ"],
                "Доставка": [
                    "Доставка и установка колец",
                    "Доставка и установка ФБС блоков",
                    "Доставка чернозема, балласта, щебенки, песка и т.д.",
                ],
                "Фундаменты": ["Обратная засыпка фундаментов", "Строительство фундаментов"],
                "Деревья": ["Сруб и вывоз деревьев"],
                "Бурение": ["Бурение свай до 2.5 метров"],
                "Вывоз": ["Вывоз строительного и любого мусора"],
                "Спецуслуги": ["Услуги гидромолота", "Резка бетона и асфальта"],
                "Строительство": ["Строительство заборов"],
                "Уборка": ["Расчистка или уборка снега"],
            }

            category_objects = {}
            for cat_name in category_mapping.keys():
                category, created = ServiceCategory.objects.get_or_create(name=cat_name)
                if created:
                    self.stdout.write(f"   ✓ Создана категория: {cat_name}")
                category_objects[cat_name] = category

            # 3. Добавление услуг
            self.stdout.write("\n3. Добавление услуг...")
            all_services = [
                "Благоустройство дворов",
                "Копка траншей",
                "Канализация под ключ",
                "Доставка и установка колец",
                "Доставка и установка ФБС блоков",
                "Обратная засыпка фундаментов",
                "Планировка и очистка участка",
                "Сруб и вывоз деревьев",
                "Бурение свай до 2.5 метров",
                "Вывоз строительного и любого мусора",
                "Доставка чернозема, балласта, щебенки, песка и т.д.",
                "Услуги гидромолота",
                "Копка котлована",
                "Копка под фундамент",
                "Резка бетона и асфальта",
                "Покос травы мульчером",
                "Строительство фундаментов",
                "Строительство заборов",
                "Расчистка или уборка снега",
            ]

            service_count = 0
            for service_name in all_services:
                # Находим категорию для услуги
                category = None
                for cat_name, services in category_mapping.items():
                    if service_name in services:
                        category = category_objects[cat_name]
                        break

                # Если категория не найдена, используем первую доступную
                if not category:
                    category = list(category_objects.values())[0]

                service, created = ServiceItem.objects.get_or_create(
                    name=service_name,
                    defaults={
                        "category": category,
                        "unit": "hour",
                        "is_active": True,
                    },
                )
                if created:
                    service_count += 1
                    self.stdout.write(f"   ✓ Добавлена услуга: {service_name}")
                else:
                    self.stdout.write(f"   ↻ Услуга уже существует: {service_name}")

            self.stdout.write(self.style.SUCCESS(f"   Всего услуг: {service_count} добавлено"))

            # 4. Добавление грунта
            self.stdout.write("\n4. Добавление грунта...")
            soil_data = [
                {"name": "Чернозем", "unit": "m3", "price": 1200.00},
                {"name": "Песок", "unit": "m3", "price": 800.00},
                {"name": "Щебень фракция 5-20", "unit": "m3", "price": 1500.00},
                {"name": "Щебень фракция 20-40", "unit": "m3", "price": 1400.00},
                {"name": "Балласт", "unit": "m3", "price": 900.00},
                {"name": "Гравий", "unit": "m3", "price": 1100.00},
                {"name": "ПГС (песчано-гравийная смесь)", "unit": "m3", "price": 1000.00},
                {"name": "Грунт планировочный", "unit": "m3", "price": 600.00},
            ]

            soil_count = 0
            for soil in soil_data:
                material, created = MaterialItem.objects.get_or_create(
                    name=soil["name"],
                    category=MaterialItem.MaterialCategory.SOIL,
                    defaults={
                        "unit": soil["unit"],
                        "price": soil["price"],
                        "is_active": True,
                    },
                )
                if created:
                    soil_count += 1
                    self.stdout.write(f"   ✓ Добавлен грунт: {material.name} - {material.price}₽/{material.unit}")
                else:
                    material.price = soil["price"]
                    material.unit = soil["unit"]
                    material.save()
                    self.stdout.write(f"   ↻ Обновлен грунт: {material.name}")

            self.stdout.write(self.style.SUCCESS(f"   Всего грунта: {soil_count} добавлено"))

            # 5. Добавление инструментов
            self.stdout.write("\n5. Добавление инструментов...")
            tool_data = [
                {"name": "Гидромолот", "unit": "hour", "price": 3000.00},
                {"name": "Бур", "unit": "hour", "price": 2000.00},
                {"name": "Ковш экскаваторный", "unit": "hour", "price": 1500.00},
                {"name": "Вилы для погрузчика", "unit": "hour", "price": 1800.00},
                {"name": "Мульчер", "unit": "hour", "price": 3500.00},
                {"name": "Рыхлитель", "unit": "hour", "price": 2000.00},
                {"name": "Отвал", "unit": "hour", "price": 1200.00},
                {"name": "Ковш для планировки", "unit": "hour", "price": 1600.00},
            ]

            tool_count = 0
            for tool in tool_data:
                material, created = MaterialItem.objects.get_or_create(
                    name=tool["name"],
                    category=MaterialItem.MaterialCategory.TOOL,
                    defaults={
                        "unit": tool["unit"],
                        "price": tool["price"],
                        "is_active": True,
                    },
                )
                if created:
                    tool_count += 1
                    self.stdout.write(f"   ✓ Добавлен инструмент: {material.name} - {material.price}₽/{material.unit}")
                else:
                    material.price = tool["price"]
                    material.unit = tool["unit"]
                    material.save()
                    self.stdout.write(f"   ↻ Обновлен инструмент: {material.name}")

            self.stdout.write(self.style.SUCCESS(f"   Всего инструментов: {tool_count} добавлено"))

            # 6. Добавление операторов
            self.stdout.write("\n6. Добавление операторов...")
            operators_data = [
                {
                    "phone": "79187773456",
                    "password": "sos123",
                    "first_name": "Сергей",
                    "last_name": "Осипов",
                },
                {
                    "phone": "79187774365",
                    "password": "amin123",
                    "first_name": "Алексей",
                    "last_name": "Минин",
                },
            ]

            operator_count = 0
            for op_data in operators_data:
                # Форматируем телефон в международный формат
                phone_formatted = f"+{op_data['phone']}"
                
                user, created = User.objects.get_or_create(
                    phone=phone_formatted,
                    defaults={
                        "username": phone_formatted,
                        "role": UserRole.OPERATOR,
                        "first_name": op_data["first_name"],
                        "last_name": op_data["last_name"],
                        "is_active": True,
                    },
                )
                if created:
                    user.set_password(op_data["password"])
                    user.save()
                    operator_count += 1
                    self.stdout.write(
                        self.style.SUCCESS(f"   ✓ Добавлен оператор: {user.get_full_name()} ({phone_formatted})")
                    )
                else:
                    user.set_password(op_data["password"])
                    user.role = UserRole.OPERATOR
                    user.first_name = op_data["first_name"]
                    user.last_name = op_data["last_name"]
                    user.is_active = True
                    user.save()
                    self.stdout.write(f"   ↻ Обновлен оператор: {user.get_full_name()} ({phone_formatted})")

            self.stdout.write(self.style.SUCCESS(f"   Всего операторов: {operator_count} добавлено"))

        self.stdout.write("\n" + "=" * 60)
        self.stdout.write(self.style.SUCCESS("✓ Все данные успешно добавлены в БД!"))
        self.stdout.write("=" * 60)

