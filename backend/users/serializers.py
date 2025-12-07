from __future__ import annotations

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from django.contrib.auth import password_validation

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """Сериализатор для информации о пользователе"""

    role_display = serializers.CharField(source="get_role_display", read_only=True)
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "phone",
            "first_name",
            "last_name",
            "full_name",
            "role",
            "role_display",
            "avatar",
            "locale",
            "position",
            "is_active",
            "date_joined",
        ]
        read_only_fields = ["id", "date_joined", "is_active"]

    def get_full_name(self, obj):
        return obj.get_full_name() or obj.username or obj.email or str(obj.id)


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Кастомный сериализатор для JWT токенов, поддерживающий phone/email вместо username"""

    phone = serializers.CharField(required=False, allow_blank=True, write_only=True)
    email = serializers.EmailField(required=False, allow_blank=True, write_only=True)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Делаем username необязательным
        if "username" in self.fields:
            self.fields["username"].required = False
            self.fields["username"].allow_blank = True

    def validate(self, attrs):
        username = attrs.get("username")
        phone = attrs.get("phone", "").strip()
        email = attrs.get("email", "").strip()
        password = attrs.get("password")

        # Проверяем, что указан хотя бы один идентификатор
        if not username and not phone and not email:
            raise serializers.ValidationError(
                {"detail": "Необходимо указать username, phone или email"}
            )

        # Нормализуем телефон (убираем пробелы, скобки, дефисы, плюсы)
        if phone:
            import re
            phone = re.sub(r'[\s\-\(\)\+]', '', phone)
            # Если телефон начинается с 7 или 8, оставляем как есть, иначе добавляем 7
            if phone and not phone.startswith(('7', '8')):
                phone = '7' + phone

        # Ищем пользователя по phone, email или username
        user = None
        if phone:
            try:
                user = User.objects.get(phone=phone)
            except User.DoesNotExist:
                # Пробуем найти по нормализованному телефону
                try:
                    # Ищем по частичному совпадению (без +7 в начале)
                    normalized_phone = phone.lstrip('7').lstrip('8')
                    user = User.objects.filter(phone__endswith=normalized_phone).first()
                except Exception:
                    pass
        if not user and email:
            try:
                user = User.objects.get(email__iexact=email)
            except User.DoesNotExist:
                pass
        if not user and username:
            try:
                user = User.objects.get(username=username)
            except User.DoesNotExist:
                pass

        if user is None:
            raise serializers.ValidationError(
                {"detail": "Неверный телефон, email или пароль"}
            )

        # Проверяем пароль
        if not user.check_password(password):
            raise serializers.ValidationError(
                {"detail": "Неверный телефон, email или пароль"}
            )

        # Проверяем, что пользователь активен
        if not user.is_active:
            raise serializers.ValidationError({"detail": "Пользователь неактивен"})

        # Устанавливаем username для дальнейшей обработки
        attrs["username"] = user.username

        # Вызываем родительский метод для генерации токенов
        # Родительский метод уже возвращает словарь с "access" и "refresh" токенами
        data = super().validate(attrs)

        return data


class ChangePasswordSerializer(serializers.Serializer):
    """
    Сериализатор для смены пароля текущего пользователя.

    Ожидает:
    - old_password: текущий пароль
    - new_password: новый пароль
    - confirm_password: подтверждение нового пароля
    """

    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        request = self.context.get("request")
        user = getattr(request, "user", None)

        old_password = attrs.get("old_password")
        new_password = attrs.get("new_password")
        confirm_password = attrs.get("confirm_password")

        if user is None or not user.is_authenticated:
            raise serializers.ValidationError({"detail": "Пользователь не аутентифицирован"})

        if not user.check_password(old_password):
            raise serializers.ValidationError({"old_password": ["Текущий пароль указан неверно"]})

        if new_password != confirm_password:
            raise serializers.ValidationError({"confirm_password": ["Пароли не совпадают"]})

        # Проверяем новый пароль стандартными валидаторами Django
        try:
            password_validation.validate_password(new_password, user)
        except Exception as e:
            # e может быть ValidationError или другим исключением с списком сообщений
            messages = getattr(e, "messages", None) or [str(e)]
            raise serializers.ValidationError({"new_password": messages})

        return attrs

    def save(self, **kwargs):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        new_password = self.validated_data["new_password"]

        user.set_password(new_password)
        user.save(update_fields=["password"])

        return user


class RegisterSerializer(serializers.Serializer):
    """Сериализатор для регистрации нового пользователя"""
    
    phone = serializers.CharField(required=True, help_text="Номер телефона")
    password = serializers.CharField(write_only=True, required=True, help_text="Пароль")
    first_name = serializers.CharField(required=True, help_text="Имя")
    last_name = serializers.CharField(required=True, help_text="Фамилия")
    
    def validate_phone(self, value):
        """Валидация и нормализация телефона"""
        import re
        # Нормализуем телефон (убираем пробелы, скобки, дефисы, плюсы)
        phone = re.sub(r'[\s\-\(\)\+]', '', value)
        # Если телефон начинается с 7 или 8, оставляем как есть, иначе добавляем 7
        if phone and not phone.startswith(('7', '8')):
            phone = '7' + phone
        # Проверяем, что телефон уникален
        if User.objects.filter(phone=phone).exists():
            raise serializers.ValidationError("Пользователь с таким телефоном уже существует")
        return phone
    
    def validate_password(self, value):
        """Валидация пароля"""
        password_validation.validate_password(value)
        return value
    
    def create(self, validated_data):
        """Создание нового пользователя с ролью operator"""
        from users.models import UserRole
        import logging
        
        logger = logging.getLogger(__name__)
        
        phone = validated_data['phone']
        password = validated_data['password']
        first_name = validated_data['first_name']
        last_name = validated_data['last_name']
        
        try:
            # Создаем пользователя с ролью operator
            # Используем phone как username, так как username обязателен в Django
            user = User.objects.create_user(
                username=phone,  # Используем телефон как username
                phone=phone,
                password=password,
                first_name=first_name,
                last_name=last_name,
                role=UserRole.OPERATOR,  # Автоматически роль operator
                is_active=True,
            )
            logger.info(f"User created successfully: {user.id}, phone: {phone}")
            return user
        except Exception as e:
            logger.error(f"Error creating user: {e}", exc_info=True)
            raise