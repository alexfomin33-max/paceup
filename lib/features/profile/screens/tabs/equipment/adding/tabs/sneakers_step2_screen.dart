// lib/features/profile/screens/tabs/equipment/adding/tabs/sneakers_step2_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../../core/theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Список популярных моделей кроссовок по брендам
/// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<String>> _sneakerModelsByBrand = {
  'Adidas': [
    'Ultraboost 22',
    'Ultraboost 23',
    'Adizero Adios Pro 3',
    'Solarboost 4',
    'Supernova',
    'Pureboost',
  ],
  'Asics': [
    'Gel-Nimbus 25',
    'Gel-Kayano 30',
    'Gel-Cumulus 25',
    'GT-2000 12',
    'Gel-Contend 8',
    'Metaspeed Sky+',
  ],
  'Brooks': [
    'Ghost 15',
    'Glycerin 20',
    'Adrenaline GTS 23',
    'Launch 10',
    'Cascadia 17',
    'Hyperion Elite',
  ],
  'Hoka': [
    'Clifton 9',
    'Bondi 8',
    'Speedgoat 5',
    'Mach 5',
    'Rincon 3',
    'Carbon X 3',
  ],
  'Mizuno': [
    'Wave Rider 27',
    'Wave Inspire 20',
    'Wave Sky 7',
    'Wave Horizon 7',
    'Wave Creation 25',
    'Wave Rebellion',
  ],
  'New Balance': [
    '1080v13',
    '880v13',
    'FuelCell Rebel v3',
    '990v6',
    '860v13',
    'More v4',
  ],
  'Nike': [
    'Air Zoom Pegasus 40',
    'Air Zoom Vomero 17',
    'React Infinity Run 4',
    'Air Max 270',
    'ZoomX Vaporfly Next% 3',
    'Alphafly 3',
  ],
  'Puma': [
    'Velocity Nitro 3',
    'Deviate Nitro 2',
    'Magnify Nitro',
    'ForeverRun Nitro',
    'Fast-R Nitro Elite',
    'Liberate Nitro',
  ],
  'Reebok': [
    'Floatride Energy 5',
    'Nano X3',
    'Forever Floatride Energy',
    'Zig Kinetica 3',
    'Run Fast Pro',
    'Club C 85',
  ],
  'Salomon': [
    'Speedcross 6',
    'Sense Ride 5',
    'Pulsar Trail',
    'Ultra Glide 2',
    'XA Pro 3D V9',
    'S-Lab Genesis',
  ],
  'Saucony': [
    'Triumph 21',
    'Ride 17',
    'Kinvara 14',
    'Endorphin Speed 3',
    'Endorphin Pro 3',
    'Guide 17',
  ],
  'Under Armour': [
    'HOVR Machina 4',
    'HOVR Infinite 5',
    'Flow Velociti Wind 3',
    'Charged Assert 10',
    'HOVR Sonic 6',
    'Velociti Elite',
  ],
};

/// Экран «Модель X» — второй шаг добавления кроссовок
class SneakersStep2Screen extends ConsumerStatefulWidget {
  /// Выбранный бренд кроссовок
  final String brand;

  const SneakersStep2Screen({
    super.key,
    required this.brand,
  });

  @override
  ConsumerState<SneakersStep2Screen> createState() =>
      _SneakersStep2ScreenState();
}

class _SneakersStep2ScreenState extends ConsumerState<SneakersStep2Screen> {
  // ── Контроллер для поля поиска
  final TextEditingController _searchController = TextEditingController();
  // ── Выбранная модель (null = не выбрана)
  String? _selectedModel;
  // ── Список моделей для выбранного бренда
  late List<String> _models;
  // ── Отфильтрованный список моделей на основе поиска
  late List<String> _filteredModels;

  @override
  void initState() {
    super.initState();
    // ── Получаем список моделей для выбранного бренда
    _models = _sneakerModelsByBrand[widget.brand] ?? [];
    _filteredModels = _models;
    // ── Подписка на изменения в поле поиска для фильтрации списка
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Обработчик изменения текста в поле поиска
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredModels = _models;
      } else {
        _filteredModels = _models
            .where((model) => model.toLowerCase().contains(query))
            .toList();
      }
      // ── Сбрасываем выбор, если выбранная модель не попадает в фильтр
      if (_selectedModel != null &&
          !_filteredModels.contains(_selectedModel)) {
        _selectedModel = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);
    final isButtonEnabled = _selectedModel != null;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceColor(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.getSurfaceColor(context),
        centerTitle: true,
        title: Text(
          'Модель ${widget.brand}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leadingWidth: 52,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.getIconPrimaryColor(context),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Поле поиска под AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _SearchField(
                controller: _searchController,
                hintText: 'Поиск модели',
              ),
            ),

            // ── Вертикальный список моделей
            Expanded(
              child: _filteredModels.isEmpty
                  ? Center(
                      child: Text(
                        'Модели не найдены',
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredModels.length,
                      itemBuilder: (context, index) {
                        final model = _filteredModels[index];
                        final isSelected = _selectedModel == model;
                        return _ModelListItem(
                          model: model,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedModel = isSelected ? null : model;
                            });
                          },
                        );
                      },
                    ),
            ),

            // ── Кнопка "Продолжить" внизу
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Opacity(
                opacity: isButtonEnabled ? 1.0 : 0.4,
                child: ElevatedButton(
                  onPressed: isButtonEnabled
                      ? () {
                          // TODO: Переход на следующую страницу с выбранным брендом и моделью
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: textColor,
                    disabledBackgroundColor: AppColors.button,
                    disabledForegroundColor: textColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(double.infinity, 50),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.center,
                  ),
                  child: Text(
                    'Продолжить',
                    style: AppTextStyles.h15w5.copyWith(
                      color: textColor,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Виджет поля поиска с цветом twinBg
/// ─────────────────────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _SearchField({
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.twinchip,
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        cursorColor: AppColors.getTextSecondaryColor(context),
        textInputAction: TextInputAction.search,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.getIconSecondaryColor(context),
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.transparent,
          hintText: hintText,
          hintStyle: AppTextStyles.h14w4Place.copyWith(
            color: AppColors.getTextPlaceholderColor(context),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Элемент списка модели
/// ─────────────────────────────────────────────────────────────────────────────
class _ModelListItem extends StatelessWidget {
  final String model;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelListItem({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16,),
        child: Row(
          children: [
            // ── Миниатюра кроссовок слева
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.asset(
                'assets/add_boots.png',
                width: 50,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    decoration: BoxDecoration(
                      color: AppColors.getBackgroundColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      CupertinoIcons.sportscourt,
                      size: 24,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                model,
                style: AppTextStyles.h14w5.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            SizedBox(
              width: 22,
              height: 22,
              child: isSelected
                  ? Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.button,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.check_mark,
                        size: 14,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
