import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/auth_providers.dart';
import '../models/auth_models.dart';
import '../../../core/errors/app_exception.dart';

/// Экран регистрации
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isRegistering = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      
      // Вызываем метод регистрации
      await authService.register(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (mounted) {
        // После успешной регистрации автоматически логинимся
        await authService.login(
          LoginRequest(
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
          ),
        );

        // Обновляем состояние аутентификации
        await ref.read(authStateProvider.notifier).refreshUser();

        // Показываем сообщение об успехе
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Регистрация успешна! Вы вошли в систему.'),
            backgroundColor: Colors.green,
          ),
        );

        // Закрываем экран регистрации
        Navigator.of(context).pop();
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка регистрации: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 24),
            Text(
              'Создайте аккаунт',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Все зарегистрированные пользователи автоматически получают роль оператора',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Имя
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Имя *',
                hintText: 'Введите имя',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите имя';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Фамилия
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Фамилия *',
                hintText: 'Введите фамилию',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите фамилию';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Телефон
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Номер телефона *',
                hintText: '+79991234567',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-()\s]')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите номер телефона';
                }
                // Простая валидация телефона
                final phone = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
                if (phone.length < 10) {
                  return 'Номер телефона слишком короткий';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Пароль
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Пароль *',
                hintText: 'Введите пароль',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isPasswordVisible,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите пароль';
                }
                if (value.length < 6) {
                  return 'Пароль должен содержать минимум 6 символов';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Подтверждение пароля
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Подтвердите пароль *',
                hintText: 'Повторите пароль',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isConfirmPasswordVisible,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Подтвердите пароль';
                }
                if (value != _passwordController.text) {
                  return 'Пароли не совпадают';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Кнопка регистрации
            ElevatedButton(
              onPressed: _isRegistering ? null : _register,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isRegistering
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Зарегистрироваться'),
            ),
            const SizedBox(height: 16),

            // Ссылка на вход
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Уже есть аккаунт? Войти'),
            ),
          ],
        ),
      ),
    );
  }
}

