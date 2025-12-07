import 'package:flutter/material.dart';

/// Обертка для экранов, которая извлекает body из Scaffold
/// Используется для экранов, которые имеют свой Scaffold,
/// но должны отображаться внутри общего Scaffold с навигацией
class ScreenWrapper extends StatelessWidget {
  final Widget Function(BuildContext) builder;

  const ScreenWrapper({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final screen = builder(context);
    
    // Если screen - это Scaffold, извлекаем его body
    if (screen is Scaffold) {
      return screen.body ?? const SizedBox.shrink();
    }
    return screen;
  }
}

