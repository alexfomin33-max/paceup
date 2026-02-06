// lib/features/profile/screens/tabs/equipment/adding/tabs/bike_step2_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../providers/services/api_provider.dart';
import 'bike_step3_screen.dart';

const String _equipImagesBase =
    'https://uploads.paceup.ru/images/equip';

class _EquipModel {
  const _EquipModel({
    required this.id,
    required this.name,
    this.imageExt,
  });
  final int id;
  final String name;
  final String? imageExt;

  String? imageUrl(String folder) {
    if (imageExt == null || imageExt!.isEmpty) return null;
    return '$_equipImagesBase/$folder/$id.$imageExt';
  }
}

/// Экран «Модель X» — второй шаг добавления велосипеда. Модели из API (bike).
class BikeStep2Screen extends ConsumerStatefulWidget {
  final String brand;

  const BikeStep2Screen({
    super.key,
    required this.brand,
  });

  @override
  ConsumerState<BikeStep2Screen> createState() => _BikeStep2ScreenState();
}

class _BikeStep2ScreenState extends ConsumerState<BikeStep2Screen> {
  final TextEditingController _searchController = TextEditingController();
  _EquipModel? _selectedModel;
  List<_EquipModel> _allModels = [];
  List<_EquipModel> _filteredModels = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadModels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/search_equipment_models.php',
        body: {'brand': widget.brand, 'type': 'bike'},
      );
      if (!mounted) return;
      final list = (data['models'] as List<dynamic>?) ?? [];
      final models = list.map((e) {
        final map = e as Map<String, dynamic>;
        return _EquipModel(
          id: (map['id'] as num).toInt(),
          name: (map['name'] as String?) ?? '',
          imageExt: map['image_ext'] as String?,
        );
      }).toList();
      models.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _allModels = models;
        _loading = false;
        _loadError = null;
        _applySearchFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
        _allModels = [];
        _filteredModels = [];
      });
    }
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredModels = List.from(_allModels);
    } else {
      _filteredModels = _allModels
          .where((m) => m.name.toLowerCase().contains(query))
          .toList();
    }
    if (_selectedModel != null &&
        !_filteredModels.any((m) => m.id == _selectedModel!.id)) {
      _selectedModel = null;
    }
  }

  void _onSearchChanged() {
    setState(_applySearchFilter);
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
                      : _filteredModels.isEmpty
                          ? Center(
                              child: Text(
                                'Модели не найдены',
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _filteredModels.length,
                              itemBuilder: (context, index) {
                                final model = _filteredModels[index];
                                final isSelected =
                                    _selectedModel?.id == model.id;
                                return _ModelListItem(
                                  equipModel: model,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedModel =
                                          isSelected ? null : model;
                                    });
                                  },
                                );
                              },
                            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Opacity(
                opacity: isButtonEnabled ? 1.0 : 0.4,
                child: ElevatedButton(
                  onPressed: isButtonEnabled && _selectedModel != null
                      ? () {
                          final m = _selectedModel!;
                          Navigator.of(context, rootNavigator: true).push(
                            CupertinoPageRoute(
                              builder: (_) => BikeStep3Screen(
                                brand: widget.brand,
                                model: m.name,
                                equipBaseId: m.id,
                                imageExt: m.imageExt,
                              ),
                            ),
                          );
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

class _ModelListItem extends StatelessWidget {
  const _ModelListItem({
    required this.equipModel,
    required this.isSelected,
    required this.onTap,
  });

  final _EquipModel equipModel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = equipModel.imageUrl('bike');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 50,
                height: 50,
                child: url != null
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => _placeholder(context),
                      )
                    : _placeholder(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                equipModel.name,
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

  Widget _placeholder(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(
        CupertinoIcons.circle,
        size: 24,
        color: AppColors.getIconSecondaryColor(context),
      ),
    );
  }
}
