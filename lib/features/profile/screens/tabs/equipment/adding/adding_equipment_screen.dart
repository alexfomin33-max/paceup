// lib/screens/.../adding_equipment_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import 'tabs/sneakers_step1_screen.dart';
import 'tabs/bike_step1_screen.dart';

/// Экран «Добавить снаряжение»
class AddingEquipmentScreen extends ConsumerStatefulWidget {
  const AddingEquipmentScreen({super.key});

  @override
  ConsumerState<AddingEquipmentScreen> createState() =>
      _AddingEquipmentScreenState();
}

class _AddingEquipmentScreenState
    extends ConsumerState<AddingEquipmentScreen> {
  // ── Выбранный тип снаряжения: 0 = кроссовки, 1 = велосипед, null = не выбрано
  int? _selectedType;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);
    final isButtonEnabled = _selectedType != null;
    // ── Размер картинки: 75% от ширины экрана, квадратная
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth * 0.5;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceColor(context),
      appBar: AppBar(
        
        elevation: 0,
        backgroundColor: AppColors.getSurfaceColor(context),
        centerTitle: true,
        title: const Text(
          'Выбор снаряжения',
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
            // ── Описание под AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Выберите тип снаряжения, которое хотите\n добавить',
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextSecondaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // ── Отступ сверху
            const Spacer(flex: 1),

            // ── Картинка кроссовок (кликабельная)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = _selectedType == 0 ? null : 0;
                });
              },
              child: Opacity(
                opacity: _selectedType == 0 ? 1.0 : 0.4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xll),
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: Image.asset(
                      'assets/choose_sneakers.png',
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox(
                          width: imageSize,
                          height: imageSize,
                          child: Icon(
                            CupertinoIcons.sportscourt,
                            size: imageSize * 0.36,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ── Картинка велосипеда (кликабельная)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = _selectedType == 1 ? null : 1;
                });
              },
              child: Opacity(
                opacity: _selectedType == 1 ? 1.0 : 0.4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xll),
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: Image.asset(
                      'assets/choose_bike.png',
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox(
                          width: imageSize,
                          height: imageSize,
                          child: Icon(
                            CupertinoIcons.circle,
                            size: imageSize * 0.36,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ── Отступ между картинками и кнопкой
            const Spacer(flex: 2),

            // ── Название выбранного типа снаряжения над кнопкой (или прозрачный плейсхолдер)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: _selectedType != null ? 1.0 : 0.0,
                child: Text(
                  _selectedType == 0
                      ? 'Кроссовки'
                      : _selectedType == 1
                          ? 'Велосипед'
                          : 'Плейсхолдер',
                  style: AppTextStyles.h14w5.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
            ),

            // ── Кнопка "Продолжить" внизу (в стиле add_activity_screen.dart)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Opacity(
                opacity: isButtonEnabled ? 1.0 : 0.4,
                child: ElevatedButton(
                  onPressed: isButtonEnabled
                      ? () {
                          if (_selectedType == 0) {
                            // ── Переход на экран выбора бренда кроссовок
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                builder: (_) => const SneakersStep1Screen(),
                              ),
                            );
                          } else if (_selectedType == 1) {
                            // ── Переход на экран выбора бренда велосипеда
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                builder: (_) => const BikeStep1Screen(),
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
