import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../providers/auth_providers.dart';
import '../models/auth_models.dart';
import 'register_screen.dart';

/// Экран логина
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите телефон или email')),
      );
      return;
    }

    final request = LoginRequest(
      phone: phone.isNotEmpty ? phone : null,
      email: email.isNotEmpty ? email : null,
      password: password,
    );

    final authNotifier = ref.read(authStateProvider.notifier);
    await authNotifier.login(request);

    // Проверяем mounted перед использованием ref
    if (!mounted) return;
    
    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      // Навигация будет обработана в app.dart
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else if (authState.error != null) {
      if (mounted) {
        _showErrorDialog(authState.error!, authState.exception);
      }
    }
  }


  void _showErrorDialog(String message, AppException? exception) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка входа'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _validatePhone(String phone) {
    // Простая валидация: начинается с + и содержит цифры
    final phoneRegex = RegExp(r'^\+?[1-9]\d{10,14}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Неверный формат email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Логотип или заголовок
                Icon(
                  Icons.account_circle,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Вход в систему',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Введите данные для входа',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Поле телефона
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+7 (999) 123-45-67',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value != null && value.isNotEmpty && !_validatePhone(value)) {
                      return 'Неверный формат телефона';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Поле email (опционально)
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (опционально)',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                // Поле пароля
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
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
                  textInputAction: TextInputAction.done,
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
                const SizedBox(height: 24),

                // Кнопка входа
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Войти'),
                ),

                const SizedBox(height: 16),

                // Кнопка регистрации
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('Нет аккаунта? Зарегистрироваться'),
                ),

                // Обработка ошибок
                if (authState.error != null && !authState.isLoading) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authState.error!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            ref.read(authStateProvider.notifier).clearError();
                          },
                          color: Colors.red[700],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

