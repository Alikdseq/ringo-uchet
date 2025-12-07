import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Локализация приложения
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ru', 'RU'),
    Locale('en', 'US'),
  ];

  // Общие
  String get appName => _localizedValues[locale.languageCode]?['appName'] ?? 'Ringo Uchet';
  String get ok => _localizedValues[locale.languageCode]?['ok'] ?? 'OK';
  String get cancel => _localizedValues[locale.languageCode]?['cancel'] ?? 'Cancel';
  String get save => _localizedValues[locale.languageCode]?['save'] ?? 'Save';
  String get delete => _localizedValues[locale.languageCode]?['delete'] ?? 'Delete';
  String get edit => _localizedValues[locale.languageCode]?['edit'] ?? 'Edit';
  String get add => _localizedValues[locale.languageCode]?['add'] ?? 'Add';
  String get search => _localizedValues[locale.languageCode]?['search'] ?? 'Search';
  String get loading => _localizedValues[locale.languageCode]?['loading'] ?? 'Loading...';
  String get error => _localizedValues[locale.languageCode]?['error'] ?? 'Error';
  String get success => _localizedValues[locale.languageCode]?['success'] ?? 'Success';

  // Статусы заказов
  String get orderStatusDraft => _localizedValues[locale.languageCode]?['orderStatusDraft'] ?? 'Draft';
  String get orderStatusCreated => _localizedValues[locale.languageCode]?['orderStatusCreated'] ?? 'Created';
  String get orderStatusApproved => _localizedValues[locale.languageCode]?['orderStatusApproved'] ?? 'Approved';
  String get orderStatusInProgress => _localizedValues[locale.languageCode]?['orderStatusInProgress'] ?? 'In Progress';
  String get orderStatusCompleted => _localizedValues[locale.languageCode]?['orderStatusCompleted'] ?? 'Completed';
  String get orderStatusCancelled => _localizedValues[locale.languageCode]?['orderStatusCancelled'] ?? 'Cancelled';

  String getOrderStatus(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return orderStatusDraft;
      case 'CREATED':
        return orderStatusCreated;
      case 'APPROVED':
        return orderStatusApproved;
      case 'IN_PROGRESS':
        return orderStatusInProgress;
      case 'COMPLETED':
        return orderStatusCompleted;
      case 'CANCELLED':
        return orderStatusCancelled;
      default:
        return status;
    }
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'ru': {
      'appName': 'Ringo Uchet',
      'ok': 'ОК',
      'cancel': 'Отмена',
      'save': 'Сохранить',
      'delete': 'Удалить',
      'edit': 'Изменить',
      'add': 'Добавить',
      'search': 'Поиск',
      'loading': 'Загрузка...',
      'error': 'Ошибка',
      'success': 'Успешно',
      'orderStatusDraft': 'Черновик',
      'orderStatusCreated': 'Создан',
      'orderStatusApproved': 'Одобрен',
      'orderStatusInProgress': 'В работе',
      'orderStatusCompleted': 'Завершён',
      'orderStatusCancelled': 'Отменён',
    },
    'en': {
      'appName': 'Ringo Uchet',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'search': 'Search',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'orderStatusDraft': 'Draft',
      'orderStatusCreated': 'Created',
      'orderStatusApproved': 'Approved',
      'orderStatusInProgress': 'In Progress',
      'orderStatusCompleted': 'Completed',
      'orderStatusCancelled': 'Cancelled',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ru', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

