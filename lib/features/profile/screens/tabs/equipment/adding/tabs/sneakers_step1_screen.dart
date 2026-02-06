// lib/features/profile/screens/tabs/equipment/adding/tabs/sneakers_step1_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../providers/services/api_provider.dart';
import 'sneakers_step2_screen.dart';
import 'own_sneakers_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Экран «Бренд кроссовок» — первый шаг добавления кроссовок.
/// Бренды загружаются из API (equip_base, type=boots, status=1), без дублей,
/// по алфавиту. Поиск фильтрует список по введённому значению.
/// ─────────────────────────────────────────────────────────────────────────────

/// Экран «Бренд кроссовок» — первый шаг добавления кроссовок
class SneakersStep1Screen extends ConsumerStatefulWidget {
  const SneakersStep1Screen({super.key});

  @override
  ConsumerState<SneakersStep1Screen> createState() =>
      _SneakersStep1ScreenState();
}

class _SneakersStep1ScreenState extends ConsumerState<SneakersStep1Screen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedBrand;
  bool _isOwnSneakersSelected = false;
  List<String> _allBrands = [];
  List<String> _filteredBrands = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadBrands();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Загрузка брендов из API (type=boots, status=1, без дублей, по алфавиту)
  Future<void> _loadBrands() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/search_equipment_brands.php',
        body: {'type': 'boots'},
      );
      if (!mounted) return;
      final list = (data['brands'] as List<dynamic>?)?.cast<String>() ?? [];
      final sorted = List<String>.from(list)..sort((a, b) => a.compareTo(b));
      setState(() {
        _allBrands = sorted;
        _loading = false;
        _loadError = null;
        _applySearchFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
        _allBrands = [];
        _filteredBrands = [];
      });
    }
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredBrands = List.from(_allBrands);
    } else {
      _filteredBrands = _allBrands
          .where((b) => b.toLowerCase().contains(query))
          .toList();
    }
    if (_selectedBrand != null && !_filteredBrands.contains(_selectedBrand)) {
      _selectedBrand = null;
    }
    if (query.isNotEmpty) _isOwnSneakersSelected = false;
  }

  void _onSearchChanged() {
    setState(_applySearchFilter);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);
    final isButtonEnabled = _selectedBrand != null || _isOwnSneakersSelected;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceColor(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.getSurfaceColor(context),
        centerTitle: true,
        title: const Text(
          'Бренд кроссовок',
          style: TextStyle(
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
                hintText: 'Поиск бренда',
              ),
            ),

            // ── Вертикальный список брендов (загрузка / ошибка / пусто / список)
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: SelectableText.rich(
                              TextSpan(
                                text: 'Ошибка загрузки: $_loadError',
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : _filteredBrands.isEmpty &&
                              _searchController.text.trim().isNotEmpty
                          ? Center(
                              child: Text(
                                'Бренды не найдены',
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredBrands.length + 1,
                      itemBuilder: (context, index) {
                        // ── Последний элемент — специальный пункт "Добавить свои кроссовки"
                        if (index == _filteredBrands.length) {
                          return _OwnSneakersListItem(
                            isSelected: _isOwnSneakersSelected,
                            onTap: () {
                              setState(() {
                                _isOwnSneakersSelected = 
                                    !_isOwnSneakersSelected;
                                // ── Сбрасываем выбор бренда при выборе специального пункта
                                if (_isOwnSneakersSelected) {
                                  _selectedBrand = null;
                                }
                              });
                            },
                          );
                        }
                        final brand = _filteredBrands[index];
                        final isSelected = _selectedBrand == brand;
                        return _BrandListItem(
                          brand: brand,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedBrand =
                                  isSelected ? null : brand;
                              // ── Сбрасываем выбор специального пункта при выборе бренда
                              if (_selectedBrand != null) {
                                _isOwnSneakersSelected = false;
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            // ── Кнопка "Продолжить" внизу
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Opacity(
                opacity: isButtonEnabled ? 1.0 : 0.4,
                child: ElevatedButton(
                  onPressed: isButtonEnabled
                      ? () {
                          if (_isOwnSneakersSelected) {
                            // ── Переход на экран добавления своих кроссовок
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                builder: (_) => const OwnSneakersScreen(),
                              ),
                            );
                          } else if (_selectedBrand != null) {
                            // ── Переход на экран выбора модели кроссовок
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                builder: (_) => SneakersStep2Screen(
                                  brand: _selectedBrand!,
                                ),
                              ),
                            );
                          }
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
        // boxShadow: const [
        //   BoxShadow(
        //     color: AppColors.twinshadow,
        //     blurRadius: 10,
        //     offset: Offset(0, 1),
        //   ),
        // ],
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
/// Элемент списка бренда
/// ─────────────────────────────────────────────────────────────────────────────
class _BrandListItem extends StatelessWidget {
  final String brand;
  final bool isSelected;
  final VoidCallback onTap;

  const _BrandListItem({
    required this.brand,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                brand,
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

/// ─────────────────────────────────────────────────────────────────────────────
/// Элемент списка "Добавить свои кроссовки"
/// ─────────────────────────────────────────────────────────────────────────────
class _OwnSneakersListItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _OwnSneakersListItem({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Добавить свои кроссовки',
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
