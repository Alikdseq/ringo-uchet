from __future__ import annotations

import logging

from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import status, viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.filters import OrderingFilter, SearchFilter
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, AuthenticationFailed, APIException
from rest_framework_simplejwt.views import TokenObtainPairView
from .models import User, UserRole
from .permissions import RolePermission
from .serializers import (
    CustomTokenObtainPairSerializer,
    UserSerializer,
    ChangePasswordSerializer,
    RegisterSerializer,
)

logger = logging.getLogger(__name__)


class CustomTokenObtainPairView(TokenObtainPairView):
    """Кастомный view для получения JWT токенов с поддержкой phone/email"""

    serializer_class = CustomTokenObtainPairSerializer
    
    def post(self, request, *args, **kwargs):
        """Обработка POST запроса с обработкой ошибок"""
        try:
            return super().post(request, *args, **kwargs)
        except ValidationError as e:
            # ValidationError (неверные учетные данные) - возвращаем 401
            error_detail = e.detail if hasattr(e, 'detail') else {"detail": "Неверный телефон, email или пароль"}
            logger.warning(f"Invalid credentials: {error_detail}")
            return Response(
                error_detail,
                status=status.HTTP_401_UNAUTHORIZED
            )
        except AuthenticationFailed as e:
            # AuthenticationFailed (от SimpleJWT) - возвращаем 401
            error_detail = e.detail if hasattr(e, 'detail') else {"detail": "Неверный телефон, email или пароль"}
            logger.warning(f"Authentication failed: {error_detail}")
            return Response(
                error_detail,
                status=status.HTTP_401_UNAUTHORIZED
            )
        except APIException as e:
            # Другие API исключения - возвращаем их статус код
            error_detail = e.detail if hasattr(e, 'detail') else {"detail": str(e)}
            logger.warning(f"API exception in token obtain: {error_detail}")
            return Response(
                error_detail,
                status=e.status_code
            )
        except Exception as e:
            # Неожиданные ошибки - возвращаем 500 и логируем
            logger.error(f"Unexpected error in token obtain: {e}", exc_info=True)
            return Response(
                {"detail": "Ошибка при получении токена. Проверьте логи сервера."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def current_user_view(request):
    """Эндпоинт для получения информации о текущем пользователе"""
    serializer = UserSerializer(request.user)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def operators_list_view(request):
    """Эндпоинт для получения списка операторов (для выбора при создании заявки)"""
    from .models import User, UserRole
    
    # Получаем всех пользователей с ролью оператор
    operators = User.objects.filter(role=UserRole.OPERATOR, is_active=True).order_by('first_name', 'last_name')
    serializer = UserSerializer(operators, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def operator_salary_view(request):
    """Эндпоинт для получения информации о зарплатах оператора (для ЛК оператора)"""
    from .models import UserRole
    from finance.models import SalaryRecord
    from orders.models import Order
    
    user = request.user
    
    # Проверяем, что пользователь - оператор
    if user.role != UserRole.OPERATOR:
        return Response(
            {"detail": "Доступно только для операторов"},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Получаем все зарплаты оператора
    salary_records = SalaryRecord.objects.filter(user=user).select_related('order').order_by('-created_at')
    
    # Формируем список зарплат с информацией о заказах
    salaries_data = []
    total_amount = 0
    for record in salary_records:
        salaries_data.append({
            "id": record.id,
            "order_id": str(record.order.id) if record.order else None,
            "order_number": record.order.number if record.order else None,
            "amount": str(record.amount),
            "hours_worked": str(record.hours_worked),
            "status": record.status,
            "rate_type": record.rate_type,
            "notes": record.notes,
            "created_at": record.created_at.isoformat(),
            "paid_at": record.paid_at.isoformat() if record.paid_at else None,
        })
        total_amount += record.amount
    
    # Получаем список заказов оператора с информацией о зарплате
    orders = Order.objects.filter(operator=user).select_related('client').prefetch_related('salary_records').order_by('-created_at')
    orders_data = []
    for order in orders:
        order_salary = order.salary_records.filter(user=user).first()
        orders_data.append({
            "id": str(order.id),
            "number": order.number,
            "client_name": order.client.name if order.client else None,
            "status": order.status,
            "total_amount": str(order.total_amount),
            "salary": {
                "amount": str(order_salary.amount) if order_salary else None,
                "status": order_salary.status if order_salary else None,
                "created_at": order_salary.created_at.isoformat() if order_salary else None,
            } if order_salary else None,
            "start_dt": order.start_dt.isoformat() if order.start_dt else None,
            "end_dt": order.end_dt.isoformat() if order.end_dt else None,
        })
    
    return Response({
        "total_salary": str(total_amount),
        "salary_records": salaries_data,
        "orders": orders_data,
    }, status=status.HTTP_200_OK)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def change_password_view(request):
    """
    Эндпоинт для смены пароля текущего пользователя.

    Принимает JSON:
    {
      "old_password": "...",
      "new_password": "...",
      "confirm_password": "..."
    }
    """
    serializer = ChangePasswordSerializer(
        data=request.data,
        context={"request": request},
    )
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(
        {"detail": "Пароль успешно изменён"},
        status=status.HTTP_200_OK,
    )


@api_view(["POST"])
@permission_classes([AllowAny])  # Публичный эндпоинт, не требует аутентификации
def register_view(request):
    """
    Эндпоинт для регистрации нового пользователя.
    Все зарегистрированные пользователи автоматически получают роль operator.
    
    Принимает JSON:
    {
      "phone": "+79991234567",
      "password": "...",
      "first_name": "Иван",
      "last_name": "Иванов"
    }
    """
    try:
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # Возвращаем информацию о созданном пользователе
        user_serializer = UserSerializer(user)
        return Response(
            {
                "detail": "Пользователь успешно зарегистрирован",
                "user": user_serializer.data,
            },
            status=status.HTTP_201_CREATED,
        )
    except Exception as e:
        logger.error(f"Error in register_view: {e}", exc_info=True)
        return Response(
            {
                "detail": f"Ошибка при регистрации: {str(e)}",
                "error": str(e),
            },
            status=status.HTTP_400_BAD_REQUEST,
        )


@extend_schema_view(
    list=extend_schema(
        summary="Список пользователей",
        description="Получить список пользователей (только для админа)",
        tags=["Users"],
    ),
    retrieve=extend_schema(
        summary="Детали пользователя",
        description="Получить детальную информацию о пользователе (только для админа)",
        tags=["Users"],
    ),
    create=extend_schema(
        summary="Создать пользователя",
        description="Создать нового пользователя (только для админа)",
        tags=["Users"],
    ),
    update=extend_schema(
        summary="Обновить пользователя",
        description="Обновить информацию о пользователе (только для админа)",
        tags=["Users"],
    ),
    partial_update=extend_schema(
        summary="Частично обновить пользователя",
        description="Частично обновить информацию о пользователе (только для админа)",
        tags=["Users"],
    ),
    destroy=extend_schema(
        summary="Удалить пользователя",
        description="Удалить пользователя (только для админа)",
        tags=["Users"],
    ),
)
class UserViewSet(viewsets.ModelViewSet):
    """ViewSet для управления пользователями (только для админа)"""
    
    queryset = User.objects.all().order_by("first_name", "last_name", "username")
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated, RolePermission]
    allowed_roles = [UserRole.ADMIN]
    filter_backends = (DjangoFilterBackend, SearchFilter, OrderingFilter)
    filterset_fields = ("role", "is_active")
    search_fields = ("first_name", "last_name", "username", "email", "phone")
    ordering_fields = ("first_name", "last_name", "username", "date_joined", "role")
    
    def get_queryset(self):
        """Фильтруем по роли оператора, если указан параметр role=operator"""
        queryset = super().get_queryset()
        role_filter = self.request.query_params.get("role")
        if role_filter == "operator":
            queryset = queryset.filter(role=UserRole.OPERATOR)
        return queryset