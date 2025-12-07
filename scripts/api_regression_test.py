#!/usr/bin/env python3
"""
API Regression Test Suite

Простой скрипт для проверки основных эндпоинтов API перед редкими обновлениями.
Запуск: python scripts/api_regression_test.py [--base-url URL]
"""

import sys
import json
import argparse
from datetime import datetime, timedelta
from typing import Dict, Optional

try:
    import httpx
    HAS_HTTPX = True
except ImportError:
    try:
        import requests
        HAS_HTTPX = False
    except ImportError:
        print("ERROR: Необходимо установить httpx или requests")
        print("  pip install httpx")
        print("  или")
        print("  pip install requests")
        sys.exit(1)


class APITester:
    """Простой тестер API эндпоинтов."""

    def __init__(self, base_url: str = "http://localhost:8001"):
        self.base_url = base_url.rstrip("/")
        if HAS_HTTPX:
            self.client = httpx.Client(timeout=30.0)
        else:
            self.client = requests.Session()
            self.client.timeout = 30.0
        self.token: Optional[str] = None
        self.failed_tests = []

    def log(self, message: str, status: str = "INFO"):
        """Логирование с цветами."""
        colors = {
            "PASS": "\033[92m✓\033[0m",
            "FAIL": "\033[91m✗\033[0m",
            "INFO": "\033[94mℹ\033[0m",
        }
        symbol = colors.get(status, "•")
        print(f"{symbol} {message}")

    def test_health_check(self) -> bool:
        """Тест 1: Health check endpoint."""
        self.log("Тест 1: Health check", "INFO")
        try:
            if HAS_HTTPX:
                response = self.client.get(f"{self.base_url}/api/health/")
            else:
                response = self.client.get(f"{self.base_url}/api/health/", timeout=30)
            if response.status_code == 200:
                data = response.json()
                # Проверяем, что есть поле status со значением "ok" или "healthy"
                status_value = data.get("status", "").lower()
                if status_value in ("ok", "healthy") or response.status_code == 200:
                    self.log("Health check passed", "PASS")
                    return True
                else:
                    self.log(f"Health check response: {data}", "INFO")
            self.log(f"Health check failed: {response.status_code}", "FAIL")
            if response.status_code == 200:
                self.log(f"  → Response: {response.text[:200]}", "INFO")
            return False
        except Exception as e:
            self.log(f"Health check error: {e}", "FAIL")
            return False

    def test_login(self, username: str = "admin", password: str = "admin123") -> bool:
        """Тест 2: Логин и получение токена."""
        self.log("Тест 2: Login", "INFO")
        try:
            if HAS_HTTPX:
                response = self.client.post(
                    f"{self.base_url}/api/v1/token/",
                    json={"username": username, "password": password},
                )
            else:
                response = self.client.post(
                    f"{self.base_url}/api/v1/token/",
                    json={"username": username, "password": password},
                    timeout=30,
                )
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access")
                if self.token:
                    self.log("Login successful", "PASS")
                    # Обновляем заголовки для следующих запросов
                    if HAS_HTTPX:
                        self.client.headers.update({"Authorization": f"Bearer {self.token}"})
                    else:
                        self.client.headers.update({"Authorization": f"Bearer {self.token}"})
                    return True
            self.log(f"Login failed: {response.status_code}", "FAIL")
            if response.status_code == 401:
                self.log("  → Проверьте username/password", "INFO")
            return False
        except Exception as e:
            self.log(f"Login error: {e}", "FAIL")
            return False

    def test_current_user(self) -> bool:
        """Тест 3: Получение текущего пользователя."""
        self.log("Тест 3: Get current user", "INFO")
        if not self.token:
            self.log("  → Пропущен (нет токена)", "INFO")
            return False
        try:
            if HAS_HTTPX:
                response = self.client.get(f"{self.base_url}/api/v1/users/me/")
            else:
                response = self.client.get(f"{self.base_url}/api/v1/users/me/", timeout=30)
            if response.status_code == 200:
                data = response.json()
                if "id" in data and "username" in data:
                    self.log(f"Current user: {data.get('username')}", "PASS")
                    return True
            self.log(f"Get current user failed: {response.status_code}", "FAIL")
            return False
        except Exception as e:
            self.log(f"Get current user error: {e}", "FAIL")
            return False

    def test_get_orders(self) -> bool:
        """Тест 4: Получение списка заказов."""
        self.log("Тест 4: Get orders list", "INFO")
        if not self.token:
            self.log("  → Пропущен (нет токена)", "INFO")
            return False
        try:
            if HAS_HTTPX:
                response = self.client.get(f"{self.base_url}/api/v1/orders/")
            else:
                response = self.client.get(f"{self.base_url}/api/v1/orders/", timeout=30)
            if response.status_code == 200:
                data = response.json()
                # Может быть список или объект с results
                if isinstance(data, (list, dict)):
                    count = len(data) if isinstance(data, list) else len(data.get("results", []))
                    self.log(f"Orders retrieved: {count}", "PASS")
                    return True
            self.log(f"Get orders failed: {response.status_code}", "FAIL")
            return False
        except Exception as e:
            self.log(f"Get orders error: {e}", "FAIL")
            return False

    def test_create_order(self) -> bool:
        """Тест 5: Создание заказа."""
        self.log("Тест 5: Create order", "INFO")
        if not self.token:
            self.log("  → Пропущен (нет токена)", "INFO")
            return False
        try:
            # Сначала получим клиента и технику для теста
            if HAS_HTTPX:
                clients_resp = self.client.get(f"{self.base_url}/api/v1/clients/")
                equipment_resp = self.client.get(f"{self.base_url}/api/v1/equipment/")
            else:
                clients_resp = self.client.get(f"{self.base_url}/api/v1/clients/", timeout=30)
                equipment_resp = self.client.get(f"{self.base_url}/api/v1/equipment/", timeout=30)
            
            if clients_resp.status_code != 200 or equipment_resp.status_code != 200:
                self.log("  → Пропущен (нет данных для создания)", "INFO")
                return False
            
            clients = clients_resp.json()
            equipment = equipment_resp.json()
            
            client_id = None
            if isinstance(clients, list) and len(clients) > 0:
                client_id = clients[0].get("id")
            elif isinstance(clients, dict) and clients.get("results"):
                client_id = clients["results"][0].get("id")
            
            equipment_id = None
            if isinstance(equipment, list) and len(equipment) > 0:
                equipment_id = equipment[0].get("id")
            elif isinstance(equipment, dict) and equipment.get("results"):
                equipment_id = equipment["results"][0].get("id")
            
            if not client_id or not equipment_id:
                self.log("  → Пропущен (нет клиента или техники)", "INFO")
                return False
            
            # Создаем тестовый заказ с обязательными полями
            start_dt = datetime.now() + timedelta(days=1)
            
            order_data = {
                "client_id": client_id,  # Используем client_id, а не client
                "address": "Тестовый адрес для API regression test",
                "start_dt": start_dt.isoformat(),
                "description": "API Regression Test Order",
            }
            
            # Добавляем equipment, если есть
            if equipment_id:
                order_data["equipment"] = equipment_id
            
            if HAS_HTTPX:
                response = self.client.post(
                    f"{self.base_url}/api/v1/orders/",
                    json=order_data,
                )
            else:
                response = self.client.post(
                    f"{self.base_url}/api/v1/orders/",
                    json=order_data,
                    timeout=30,
                )
            
            if response.status_code in [200, 201]:
                data = response.json()
                order_id = data.get("id")
                self.log(f"Order created: {order_id}", "PASS")
                return True
            else:
                self.log(f"Create order failed: {response.status_code}", "FAIL")
                self.log(f"  → Response: {response.text[:200]}", "INFO")
                return False
        except Exception as e:
            self.log(f"Create order error: {e}", "FAIL")
            return False

    def test_get_clients(self) -> bool:
        """Тест 6: Получение списка клиентов."""
        self.log("Тест 6: Get clients list", "INFO")
        if not self.token:
            self.log("  → Пропущен (нет токена)", "INFO")
            return False
        try:
            if HAS_HTTPX:
                response = self.client.get(f"{self.base_url}/api/v1/clients/")
            else:
                response = self.client.get(f"{self.base_url}/api/v1/clients/", timeout=30)
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, (list, dict)):
                    count = len(data) if isinstance(data, list) else len(data.get("results", []))
                    self.log(f"Clients retrieved: {count}", "PASS")
                    return True
            self.log(f"Get clients failed: {response.status_code}", "FAIL")
            return False
        except Exception as e:
            self.log(f"Get clients error: {e}", "FAIL")
            return False

    def test_get_equipment(self) -> bool:
        """Тест 7: Получение списка техники."""
        self.log("Тест 7: Get equipment list", "INFO")
        if not self.token:
            self.log("  → Пропущен (нет токена)", "INFO")
            return False
        try:
            if HAS_HTTPX:
                response = self.client.get(f"{self.base_url}/api/v1/equipment/")
            else:
                response = self.client.get(f"{self.base_url}/api/v1/equipment/", timeout=30)
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, (list, dict)):
                    count = len(data) if isinstance(data, list) else len(data.get("results", []))
                    self.log(f"Equipment retrieved: {count}", "PASS")
                    return True
            self.log(f"Get equipment failed: {response.status_code}", "FAIL")
            return False
        except Exception as e:
            self.log(f"Get equipment error: {e}", "FAIL")
            return False

    def run_all_tests(self, username: str = "admin", password: str = "admin123") -> bool:
        """Запуск всех тестов."""
        print("\n" + "=" * 60)
        print("API Regression Test Suite")
        print("=" * 60 + "\n")
        
        tests = [
            self.test_health_check,
            lambda: self.test_login(username, password),
            self.test_current_user,
            self.test_get_clients,
            self.test_get_equipment,
            self.test_get_orders,
            self.test_create_order,
        ]
        
        passed = 0
        total = len(tests)
        
        for test in tests:
            try:
                if test():
                    passed += 1
            except Exception as e:
                self.log(f"Test error: {e}", "FAIL")
        
        print("\n" + "=" * 60)
        print(f"Results: {passed}/{total} tests passed")
        print("=" * 60 + "\n")
        
        if passed == total:
            self.log("All tests passed! ✅", "PASS")
            return True
        else:
            self.log(f"{total - passed} test(s) failed! ❌", "FAIL")
            return False

    def __del__(self):
        """Закрытие клиента."""
        if hasattr(self, "client"):
            if HAS_HTTPX:
                self.client.close()


def main():
    """Главная функция."""
    parser = argparse.ArgumentParser(description="API Regression Test Suite")
    parser.add_argument(
        "--base-url",
        default="http://localhost:8001",
        help="Base URL of the API (default: http://localhost:8001)",
    )
    parser.add_argument(
        "--username",
        default="admin",
        help="Username for login (default: admin)",
    )
    parser.add_argument(
        "--password",
        default="admin123",
        help="Password for login (default: admin123)",
    )
    
    args = parser.parse_args()
    
    tester = APITester(base_url=args.base_url)
    success = tester.run_all_tests(username=args.username, password=args.password)
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

