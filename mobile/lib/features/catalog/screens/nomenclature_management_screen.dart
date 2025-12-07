import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/catalog_models.dart';
import '../services/catalog_service.dart';

/// Экран управления номенклатурой для админа
class NomenclatureManagementScreen extends ConsumerStatefulWidget {
  final String type; // 'equipment', 'services', 'materials'

  const NomenclatureManagementScreen({
    super.key,
    required this.type,
  });

  @override
  ConsumerState<NomenclatureManagementScreen> createState() => _NomenclatureManagementScreenState();
}

class _NomenclatureManagementScreenState extends ConsumerState<NomenclatureManagementScreen> {
  List<dynamic> _items = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final catalogService = ref.read(catalogServiceProvider);
      List<dynamic> items = [];

      switch (widget.type) {
        case 'equipment':
          items = await catalogService.getEquipment();
          break;
        case 'services':
          items = await catalogService.getServices();
          break;
        case 'materials':
          items = await catalogService.getMaterials();
          break;
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(dynamic item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы уверены, что хотите удалить "${_getItemName(item)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final catalogService = ref.read(catalogServiceProvider);
      
      switch (widget.type) {
        case 'equipment':
          if (item is Equipment) {
            await catalogService.deleteEquipment(item.id);
          }
          break;
        case 'services':
          if (item is ServiceItem) {
            await catalogService.deleteService(item.id);
          }
          break;
        case 'materials':
          if (item is MaterialItem) {
            await catalogService.deleteMaterial(item.id);
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Удалено успешно')),
        );
        _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: ${e.toString()}')),
        );
      }
    }
  }

  void _editItem(dynamic item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NomenclatureEditScreen(
          type: widget.type,
          item: item,
        ),
      ),
    ).then((_) => _loadItems());
  }

  void _addItem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NomenclatureEditScreen(
          type: widget.type,
        ),
      ),
    ).then((_) => _loadItems());
  }

  String _getItemName(dynamic item) {
    if (item is Equipment) return item.name;
    if (item is ServiceItem) return item.name;
    if (item is MaterialItem) return item.name;
    return 'Неизвестно';
  }

  String _getTitle() {
    switch (widget.type) {
      case 'equipment':
        return 'Управление техникой';
      case 'services':
        return 'Управление услугами';
      case 'materials':
        return 'Управление материалами';
      default:
        return 'Номенклатура';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addItem,
            tooltip: 'Добавить',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ошибка: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadItems,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Номенклатура пуста',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить первый элемент'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadItems,
                      child: ListView.builder(
                        itemCount: _items.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text(_getItemName(item)),
                              subtitle: _buildItemSubtitle(item),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editItem(item),
                                    tooltip: 'Редактировать',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteItem(item),
                                    tooltip: 'Удалить',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildItemSubtitle(dynamic item) {
    if (item is Equipment) {
      return Text('${item.code} | ${item.hourlyRate.toStringAsFixed(2)} ₽/час');
    }
    if (item is ServiceItem) {
      return Text('${item.price?.toStringAsFixed(2) ?? "Цена не указана"} ₽');
    }
    if (item is MaterialItem) {
      return Text('${item.price.toStringAsFixed(2)} ₽/${item.unit}');
    }
    return const SizedBox.shrink();
  }
}

/// Экран редактирования/создания элемента номенклатуры
class NomenclatureEditScreen extends ConsumerStatefulWidget {
  final String type;
  final dynamic item; // null для создания

  const NomenclatureEditScreen({
    super.key,
    required this.type,
    this.item,
  });

  @override
  ConsumerState<NomenclatureEditScreen> createState() => _NomenclatureEditScreenState();
}

class _NomenclatureEditScreenState extends ConsumerState<NomenclatureEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Контроллеры для Equipment
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _dailyRateController = TextEditingController();

  // Контроллеры для ServiceItem
  final _serviceNameController = TextEditingController();
  final _servicePriceController = TextEditingController();

  // Контроллеры для MaterialItem
  final _materialNameController = TextEditingController();
  final _materialPriceController = TextEditingController();
  final _materialUnitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _loadItemData();
    } else {
      _materialUnitController.text = 'шт';
    }
  }

  void _loadItemData() {
    if (widget.item is Equipment) {
      final eq = widget.item as Equipment;
      _codeController.text = eq.code;
      _nameController.text = eq.name;
      _descriptionController.text = eq.description.isNotEmpty ? eq.description : '';
      _hourlyRateController.text = eq.hourlyRate.toString();
      _dailyRateController.text = eq.dailyRate?.toString() ?? '';
    } else if (widget.item is ServiceItem) {
      final svc = widget.item as ServiceItem;
      _serviceNameController.text = svc.name;
      _servicePriceController.text = svc.price?.toString() ?? '';
    } else if (widget.item is MaterialItem) {
      final mat = widget.item as MaterialItem;
      _materialNameController.text = mat.name;
      _materialPriceController.text = mat.price.toString();
      _materialUnitController.text = mat.unit;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _hourlyRateController.dispose();
    _dailyRateController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _materialNameController.dispose();
    _materialPriceController.dispose();
    _materialUnitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final catalogService = ref.read(catalogServiceProvider);

      switch (widget.type) {
        case 'equipment':
          if (widget.item != null && widget.item is Equipment) {
            await catalogService.updateEquipment(
              (widget.item! as Equipment).id,
              code: _codeController.text.trim(),
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              hourlyRate: double.tryParse(_hourlyRateController.text) ?? 0,
              dailyRate: double.tryParse(_dailyRateController.text),
            );
          } else {
            await catalogService.createEquipment(
              code: _codeController.text.trim(),
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              hourlyRate: double.tryParse(_hourlyRateController.text) ?? 0,
              dailyRate: double.tryParse(_dailyRateController.text),
            );
          }
          break;
        case 'services':
          // TODO: Реализовать создание/обновление услуг
          break;
        case 'materials':
          // TODO: Реализовать создание/обновление материалов
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.item != null ? 'Обновлено' : 'Создано')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item != null ? 'Редактирование' : 'Создание'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.type == 'equipment') ..._buildEquipmentFields(),
            if (widget.type == 'services') ..._buildServiceFields(),
            if (widget.type == 'materials') ..._buildMaterialFields(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
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
                  : Text(widget.item != null ? 'Сохранить' : 'Создать'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEquipmentFields() {
    return [
      TextFormField(
        controller: _codeController,
        decoration: const InputDecoration(
          labelText: 'Код *',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Название *',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _descriptionController,
        decoration: const InputDecoration(
          labelText: 'Описание',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _hourlyRateController,
        decoration: const InputDecoration(
          labelText: 'Почасовая ставка (₽) *',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          if (v?.isEmpty ?? true) return 'Обязательное поле';
          if (double.tryParse(v!) == null) return 'Неверное число';
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _dailyRateController,
        decoration: const InputDecoration(
          labelText: 'Дневная ставка (₽)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      ),
    ];
  }

  List<Widget> _buildServiceFields() {
    return [
      TextFormField(
        controller: _serviceNameController,
        decoration: const InputDecoration(
          labelText: 'Название услуги *',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _servicePriceController,
        decoration: const InputDecoration(
          labelText: 'Цена (₽)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      ),
    ];
  }

  List<Widget> _buildMaterialFields() {
    return [
      TextFormField(
        controller: _materialNameController,
        decoration: const InputDecoration(
          labelText: 'Название материала *',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _materialPriceController,
        decoration: const InputDecoration(
          labelText: 'Цена (₽) *',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          if (v?.isEmpty ?? true) return 'Обязательное поле';
          if (double.tryParse(v!) == null) return 'Неверное число';
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _materialUnitController,
        decoration: const InputDecoration(
          labelText: 'Единица измерения *',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
      ),
    ];
  }
}

