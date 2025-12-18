import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import '../widgets/nomenclature_selection_dialog.dart';
import '../../catalog/services/client_service.dart';
import '../../auth/services/user_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../shared/models/user.dart';

/// Экран создания заявки
class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Контроллеры для полей клиента
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Данные формы
  DateTime? _startDt;
  bool _isSaving = false;
  UserInfo? _selectedOperator;  // Для обратной совместимости
  int? _manualOperatorId; // Для ручного ввода ID оператора
  List<UserInfo> _operators = [];
  Set<int> _selectedOperatorIds = {};  // Множественный выбор операторов
  bool _isLoadingOperators = false;
  
  // Номенклатура
  final List<OrderItem> _selectedItems = [];
  final TextEditingController _totalAmountController = TextEditingController();
  bool _approveOnCreate = false;  // Флаг для одобрения при создании
  
  // Черновик
  String? _draftOrderId;  // ID текущего черновика
  bool _isSavingDraft = false;  // Флаг для отслеживания сохранения черновика
  bool _hasUnsavedChanges = false;  // Флаг для отслеживания несохраненных изменений

  @override
  void initState() {
    super.initState();
    _loadOperators();
    _checkForDraft();
    // КРИТИЧНО: НЕ добавляем слушатели для автосохранения
    // Сохранение происходит только при выходе или создании заявки
    // Это предотвращает мерцание и перезагрузки во время редактирования
  }
  
  /// Метод для пометки изменений БЕЗ автосохранения
  /// Изменения сохраняются только при выходе или создании заявки
  void _markAsChanged() {
    if (!mounted) return;
    // Просто помечаем что есть несохраненные изменения
    // БЕЗ автосохранения - это предотвращает мерцание
    _hasUnsavedChanges = true;
  }
  
  /// Проверка наличия черновика для текущего пользователя
  Future<void> _checkForDraft() async {
    try {
      final authState = ref.read(authStateProvider);
      final user = authState.user;
      
      // Черновики только для админов
      if (user?.role != 'admin') return;
      
      final orderService = ref.read(orderServiceProvider);
      // Получаем список заявок со статусом DRAFT
      final draftOrders = await orderService.getOrders(status: OrderStatus.draft, useCache: false);
      
      // Берем самую последнюю черновик (последняя созданная)
      if (draftOrders.isNotEmpty) {
        final draft = draftOrders.first; // Первая в списке (сортировка по -created_at)
        // Проверяем что это черновик текущего пользователя (created_by)
        if (draft.createdBy?.id == user?.id) {
          // Загружаем данные черновика в форму
          _loadDraftIntoForm(draft);
          setState(() {
            _draftOrderId = draft.id;
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка при проверке черновика: $e');
      // Игнорируем ошибки при проверке черновика
    }
  }
  
  /// Загрузка данных черновика в форму
  void _loadDraftIntoForm(Order draft) {
    if (draft.client != null) {
      _clientNameController.text = draft.client!.name;
      _clientPhoneController.text = draft.client!.phone;
    }
    _addressController.text = draft.address;
    _descriptionController.text = draft.description;
    _startDt = draft.startDt;
    if (draft.totalAmount > 0) {
      _totalAmountController.text = draft.totalAmount.toStringAsFixed(2);
    }
    if (draft.operatorIds != null && draft.operatorIds!.isNotEmpty) {
      _selectedOperatorIds = draft.operatorIds!.toSet();
    }
    if (draft.items != null && draft.items!.isNotEmpty) {
      _selectedItems.clear();
      _selectedItems.addAll(draft.items!);
    }
    _hasUnsavedChanges = false; // Данные загружены, изменений нет
  }
  
  /// Автосохранение черновика
  Future<void> _saveDraft() async {
    if (!mounted || _isSavingDraft || !_hasUnsavedChanges) return;
    
    // Проверяем что есть хотя бы минимальные данные для сохранения
    if (_clientNameController.text.trim().isEmpty && 
        _clientPhoneController.text.trim().isEmpty &&
        _addressController.text.trim().isEmpty) {
      return; // Не сохраняем пустой черновик
    }
    
    // Черновики только для админов
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    if (user == null || user.role != 'admin') return;
    
    // Устанавливаем флаг без setState (автосохранение происходит в фоне, без визуальной индикации)
    _isSavingDraft = true;
    
    try {
      final orderService = ref.read(orderServiceProvider);
      
      // Если нет даты начала, используем текущую дату
      final startDt = _startDt ?? DateTime.now();
      
      // Формируем запрос для черновика
      final request = OrderRequest(
        address: _addressController.text.trim().isNotEmpty 
            ? _addressController.text.trim() 
            : 'Временный адрес', // Минимальный адрес для черновика
        startDt: startDt,
        description: _descriptionController.text.trim(),
        status: OrderStatus.draft, // Сохраняем как черновик
        operatorIds: _selectedOperatorIds.isNotEmpty ? _selectedOperatorIds.toList() : null,
        items: _selectedItems.isNotEmpty ? _selectedItems : null,
        totalAmount: _totalAmountController.text.isNotEmpty 
            ? double.tryParse(_totalAmountController.text.trim()) 
            : null,
      );
      
      Order savedOrder;
      if (_draftOrderId != null) {
        // Обновляем существующий черновик
        savedOrder = await orderService.updateOrder(_draftOrderId!, request);
      } else {
        // Создаем новый черновик (но без клиента, если его еще нет)
        // Для черновика можно создать временного клиента или сохранить без него
        // Но в модели Order client_id может быть null, так что создаем заявку без клиента
        // Нужно создать временного клиента для черновика
        try {
          final clientService = ref.read(clientServiceProvider);
          final clientData = await clientService.createClient(
            name: _clientNameController.text.trim().isNotEmpty 
                ? _clientNameController.text.trim() 
                : 'Временный клиент',
            phone: _clientPhoneController.text.trim().isNotEmpty 
                ? _clientPhoneController.text.trim() 
                : '+79999999999',
            address: _addressController.text.trim().isNotEmpty 
                ? _addressController.text.trim() 
                : 'Временный адрес',
          );
          
          final clientId = clientData['id'];
          if (clientId != null) {
            final requestWithClient = OrderRequest(
              clientId: clientId is int ? clientId : int.parse(clientId.toString()),
              address: _addressController.text.trim().isNotEmpty 
                  ? _addressController.text.trim() 
                  : 'Временный адрес',
              startDt: startDt,
              description: _descriptionController.text.trim(),
              status: OrderStatus.draft,
              operatorIds: _selectedOperatorIds.isNotEmpty ? _selectedOperatorIds.toList() : null,
              items: _selectedItems.isNotEmpty ? _selectedItems : null,
              totalAmount: _totalAmountController.text.isNotEmpty 
                  ? double.tryParse(_totalAmountController.text.trim()) 
                  : null,
            );
            savedOrder = await orderService.createOrder(requestWithClient);
          } else {
            return; // Не удалось создать клиента, пропускаем сохранение
          }
        } catch (e) {
          debugPrint('Ошибка при создании клиента для черновика: $e');
          return; // Пропускаем сохранение если не удалось создать клиента
        }
      }
      
      // Обновляем данные без setState (не требует перерисовки UI)
      _draftOrderId = savedOrder.id;
      _hasUnsavedChanges = false;
      
      debugPrint('Черновик сохранен: ${savedOrder.id}');
    } catch (e) {
      debugPrint('Ошибка при сохранении черновика: $e');
      // Не показываем ошибку пользователю, просто логируем
    } finally {
      // Сбрасываем флаг без setState
      _isSavingDraft = false;
    }
  }

  @override
  void dispose() {
    // КРИТИЧНО: Сохранение черновика происходит в WillPopScope при выходе
    // НЕ сохраняем автоматически при dispose - это предотвращает лишние запросы
    
    _scrollController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadOperators() async {
    setState(() {
      _isLoadingOperators = true;
    });

    try {
      final userService = ref.read(userServiceProvider);
      final operators = await userService.getOperators();
      setState(() {
        _operators = operators;
        _isLoadingOperators = false;
      });
    } catch (e) {
      setState(() {
        _operators = []; // Устанавливаем пустой список при ошибке
        _isLoadingOperators = false;
      });
      // Не показываем ошибку пользователю, просто оставляем список пустым
      // Приложение должно работать даже без списка операторов
      if (mounted) {
        debugPrint('Эндпоинт для загрузки операторов недоступен. Список операторов будет пустым.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // КРИТИЧНО: Сохраняем черновик при выходе если есть несохраненные изменения
        // Это единственное место где происходит сохранение (кроме создания заявки)
        if (_hasUnsavedChanges && !_isSavingDraft) {
          await _saveDraft();
        }
        return true; // Разрешаем выход
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Создание заявки'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // КРИТИЧНО: Сохраняем черновик при выходе если есть несохраненные изменения
              // Это единственное место где происходит сохранение (кроме создания заявки)
              if (_hasUnsavedChanges && !_isSavingDraft) {
                await _saveDraft();
              }
              // Возвращаемся на главный экран
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Раздел: Данные клиента
            _buildSectionHeader('Данные клиента'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                labelText: 'ФИО клиента *',
                hintText: 'Введите ФИО клиента',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Обязательное поле';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientPhoneController,
              decoration: const InputDecoration(
                labelText: 'Номер телефона *',
                hintText: '+7 (999) 123-45-67',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Обязательное поле';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Адрес *',
                hintText: 'Введите адрес',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Обязательное поле';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Раздел: Описание заявки
            _buildSectionHeader('Описание заявки'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                hintText: 'Введите описание заявки',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),

            const SizedBox(height: 24),

            // Раздел: Операторы (множественный выбор)
            _buildSectionHeader('Операторы'),
            const SizedBox(height: 8),
            if (_isLoadingOperators)
              const Center(child: CircularProgressIndicator())
            else if (_operators.isNotEmpty)
              // Множественный выбор операторов через чекбоксы
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Выберите операторов (можно несколько)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ..._operators.map((operator) {
                      final isSelected = _selectedOperatorIds.contains(operator.id);
                      return CheckboxListTile(
                        title: Text(operator.fullName),
                        subtitle: operator.phone != null ? Text(operator.phone!) : null,
                        value: isSelected,
                        onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedOperatorIds.add(operator.id);
                              } else {
                                _selectedOperatorIds.remove(operator.id);
                              }
                              // Для обратной совместимости устанавливаем первого выбранного
                              if (_selectedOperatorIds.isNotEmpty) {
                                _selectedOperator = _operators.firstWhere(
                                  (op) => op.id == _selectedOperatorIds.first,
                                );
                              } else {
                                _selectedOperator = null;
                              }
                              _manualOperatorId = null;
                            });
                            // Пометка изменений после setState (без дополнительной перерисовки)
                            _markAsChanged();
                        },
                      );
                    }).toList(),
                    if (_selectedOperatorIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Операторы не выбраны (необязательно)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ),
                  ],
                ),
              )
            else
              // Если список операторов пустой, показываем поле для ввода ID
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ID операторов через запятую (необязательно)',
                      hintText: '1, 2, 3',
                      border: OutlineInputBorder(),
                      helperText: 'Если список операторов недоступен, укажите ID операторов через запятую',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        // Парсим ID операторов из строки
                        final ids = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).map((e) => int.tryParse(e)).whereType<int>().toList();
                        _selectedOperatorIds = ids.toSet();
                        _manualOperatorId = ids.isNotEmpty ? ids.first : null;
                        _selectedOperator = null;
                      });
                      // Пометка изменений после setState (без дополнительной перерисовки)
                      _markAsChanged();
                    },
                  ),
                  if (_operators.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Список операторов недоступен. Используйте ID операторов из системы.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade700,
                            ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),

            // Раздел: Номенклатура (необязательно)
            Row(
              children: [
                _buildSectionHeader('Номенклатура'),
                const SizedBox(width: 8),
                Text(
                  '(необязательно)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildNomenclatureSelection(),
            const SizedBox(height: 24),

            // Раздел: Примерная стоимость (необязательно)
            Row(
              children: [
                _buildSectionHeader('Примерная стоимость'),
                const SizedBox(width: 8),
                Text(
                  '(необязательно)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _totalAmountController,
              decoration: const InputDecoration(
                labelText: 'Примерная стоимость (₽)',
                hintText: 'Введите примерную стоимость (можно оставить пустым)',
                border: OutlineInputBorder(),
                helperText: 'Можно создать заявку только с примерной стоимостью или только с номенклатурой',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            ),
            const SizedBox(height: 24),

            // Кнопка "Одобрить при создании"
            CheckboxListTile(
              title: const Text('Одобрить заявку при создании'),
              value: _approveOnCreate,
              onChanged: (value) {
                setState(() {
                  _approveOnCreate = value ?? false;
                });
                // Пометка изменений после setState (без дополнительной перерисовки)
                _markAsChanged();
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),

            // Раздел: Дата начала
            _buildSectionHeader('Дата начала'),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Дата начала *'),
              subtitle: Text(_startDt != null
                  ? '${_startDt!.day}.${_startDt!.month}.${_startDt!.year} ${_startDt!.hour}:${_startDt!.minute.toString().padLeft(2, '0')}'
                  : 'Не выбрана'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _startDt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                    // Пометка изменений после setState (без дополнительной перерисовки)
                    _markAsChanged();
                  }
                }
              },
            ),

            const SizedBox(height: 32),

            // Кнопка создания
            ElevatedButton(
              onPressed: _isSaving ? null : _createOrder,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Создать заявку'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildNomenclatureSelection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Выбранная номенклатура',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton.icon(
                  onPressed: _showNomenclatureDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
          ),
          if (_selectedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Номенклатура не выбрана (необязательно)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            )
          else
            ..._selectedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return ListTile(
                title: Text(item.nameSnapshot),
                subtitle: Text(
                  '${item.quantity} ${item.unit} × ${item.unitPrice.toStringAsFixed(2)} ₽ = ${((item.quantity * item.unitPrice) * (1 - item.discount / 100)).toStringAsFixed(2)} ₽',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                      setState(() {
                        _selectedItems.removeAt(index);
                      });
                      // Пометка изменений после setState (без дополнительной перерисовки)
                      _markAsChanged();
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
  
  Future<void> _showNomenclatureDialog() async {
    final result = await showDialog<List<OrderItem>>(
      context: context,
      builder: (context) => const NomenclatureSelectionDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _selectedItems.addAll(result);
      });
      // Пометка изменений после setState (без дополнительной перерисовки)
      _markAsChanged();
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату начала')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final orderService = ref.read(orderServiceProvider);
      
      // Если есть черновик - обновляем его, иначе создаем новую заявку
      if (_draftOrderId != null) {
        // Обновляем существующий черновик, меняя статус на CREATED или APPROVED
        // Сначала обновляем клиента если нужно
        final clientService = ref.read(clientServiceProvider);
        
        // Получаем текущий черновик чтобы узнать ID клиента
        final currentDraft = await orderService.getOrder(_draftOrderId!);
        int? clientId = currentDraft.clientId;
        
        // Если данных клиента нет или они изменились, обновляем клиента
        if (clientId == null || 
            currentDraft.client?.name != _clientNameController.text.trim() ||
            currentDraft.client?.phone != _clientPhoneController.text.trim()) {
          // Создаем/обновляем клиента
          final clientData = await clientService.createClient(
            name: _clientNameController.text.trim(),
            phone: _clientPhoneController.text.trim(),
            address: _addressController.text.trim(),
          );
          clientId = clientData['id'] is int ? clientData['id'] : int.parse(clientData['id'].toString());
        }

        // Определяем ID оператора: из выбранного списка или из ручного ввода
        final operatorIds = _selectedOperatorIds.isNotEmpty
            ? _selectedOperatorIds.toList()
            : (_selectedOperator != null
                ? [_selectedOperator!.id]
                : (_manualOperatorId != null
                    ? [_manualOperatorId!]
                    : null));

        // Определяем статус: одобрен если выбрано, иначе создан
        final orderStatus = _approveOnCreate ? OrderStatus.approved : OrderStatus.created;
        
        // Получаем примерную стоимость если указана
        double? totalAmount;
        if (_totalAmountController.text.isNotEmpty) {
          totalAmount = double.tryParse(_totalAmountController.text.trim());
        }
        
        final request = OrderRequest(
          clientId: clientId,
          address: _addressController.text.trim(),
          startDt: _startDt!,
          endDt: null,
          description: _descriptionController.text.trim().isEmpty 
              ? '' 
              : _descriptionController.text.trim(),
          status: orderStatus, // Меняем статус с DRAFT на CREATED или APPROVED
          operatorId: operatorIds?.isNotEmpty == true ? operatorIds!.first : null,
          operatorIds: operatorIds,
          items: _selectedItems.isNotEmpty ? _selectedItems : null,
          totalAmount: totalAmount,
        );

        final updatedOrder = await orderService.updateOrder(_draftOrderId!, request);

        if (mounted) {
          // Возвращаем обновленную заявку для немедленного обновления списка
          Navigator.pop(context, updatedOrder);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заявка создана')),
          );
        }
      } else {
        // Создаем новую заявку (как раньше)
        // Сначала создаем клиента
        final clientService = ref.read(clientServiceProvider);
        final clientData = await clientService.createClient(
          name: _clientNameController.text.trim(),
          phone: _clientPhoneController.text.trim(),
          address: _addressController.text.trim(),
        );

        final clientId = clientData['id'];
        if (clientId == null) {
          throw Exception('Не удалось получить ID созданного клиента');
        }

        // Определяем ID оператора: из выбранного списка или из ручного ввода
        final operatorIds = _selectedOperatorIds.isNotEmpty
            ? _selectedOperatorIds.toList()
            : (_selectedOperator != null
                ? [_selectedOperator!.id]
                : (_manualOperatorId != null
                    ? [_manualOperatorId!]
                    : null));

        // Определяем статус: одобрен если выбрано, иначе создан
        final orderStatus = _approveOnCreate ? OrderStatus.approved : OrderStatus.created;
        
        // Получаем примерную стоимость если указана
        double? totalAmount;
        if (_totalAmountController.text.isNotEmpty) {
          totalAmount = double.tryParse(_totalAmountController.text.trim());
        }
        
        final request = OrderRequest(
          clientId: clientId is int ? clientId : int.parse(clientId.toString()),
          address: _addressController.text.trim(),
          startDt: _startDt!,
          endDt: null,
          description: _descriptionController.text.trim().isEmpty 
              ? '' 
              : _descriptionController.text.trim(),
          status: orderStatus,
          operatorId: operatorIds?.isNotEmpty == true ? operatorIds!.first : null,
          operatorIds: operatorIds,
          items: _selectedItems.isNotEmpty ? _selectedItems : null,
          totalAmount: totalAmount,
        );

        final createdOrder = await orderService.createOrder(request);

        if (mounted) {
          Navigator.pop(context, createdOrder);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заявка создана')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Ошибка при создании заявки';
        if (e.toString().contains('400')) {
          errorMessage = 'Ошибка валидации данных. Проверьте заполненные поля.';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Требуется авторизация. Войдите в систему заново.';
        } else if (e.toString().contains('403')) {
          errorMessage = 'Недостаточно прав для создания заявки.';
        } else {
          errorMessage = 'Ошибка: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

