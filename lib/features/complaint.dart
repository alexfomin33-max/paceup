import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_bar.dart';
import '../core/widgets/interactive_back_swipe.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ЭКРАН ЖАЛОБЫ
/// Страница для подачи жалобы на контент
/// ─────────────────────────────────────────────────────────────────────────────
class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  /// Выбранный пункт жалобы (null если ничего не выбрано)
  String? _selectedReason;

  /// Контроллер для текстового поля "Другое"
  late final TextEditingController _otherReasonController;

  /// Список доступных причин жалобы
  static const List<String> _reasons = [
    'Спам',
    'Откровенное изображение',
    'Насилие и вражда',
    'Мошенничество',
    'Незаконные товары и услуги',
    'Другое',
  ];

  @override
  void initState() {
    super.initState();
    _otherReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: GestureDetector(
        onTap: () {
          // Убираем фокус при клике вне поля
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: AppColors.getSurfaceColor(context),
          appBar: const PaceAppBar(title: 'Жалоба'),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                // ──────────────────────────────────────────────────────────────
                // ПРОКРУЧИВАЕМЫЙ КОНТЕНТ
                // ──────────────────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ──────────────────────────────────────────────────────────────
                          // ЗАГОЛОВОК
                          // ──────────────────────────────────────────────────────────────
                          Text(
                            'Что именно вам кажется недопустимым?',
                            style: AppTextStyles.h17w6.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ──────────────────────────────────────────────────────────────
                          // СПИСОК ПРИЧИН ЖАЛОБЫ
                          // ──────────────────────────────────────────────────────────────
                          ...List.generate(_reasons.length, (index) {
                            final reason = _reasons[index];
                            final isSelected = _selectedReason == reason;

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _selectedReason = reason;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    // Радио-кнопка
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.brandPrimary
                                              : AppColors.getOutlineColor(
                                                  context,
                                                ),
                                          width: 2,
                                        ),
                                        color: isSelected
                                            ? AppColors.brandPrimary
                                            : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? const Center(
                                              child: Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    // Текст причины
                                    Expanded(
                                      child: Text(
                                        reason,
                                        style: AppTextStyles.h15w4.copyWith(
                                          color: AppColors.getTextPrimaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          // ──────────────────────────────────────────────────────────────
                          // ТЕКСТОВОЕ ПОЛЕ ДЛЯ ПУНКТА "ДРУГОЕ"
                          // ──────────────────────────────────────────────────────────────
                          if (_selectedReason == 'Другое') ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _otherReasonController,
                              onChanged: (_) => setState(() {}),
                              style: AppTextStyles.h15w4.copyWith(
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                              minLines: 5,
                              maxLines: 10,
                              textInputAction: TextInputAction.newline,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                hintText: 'Опишите причину жалобы...',
                                hintStyle: AppTextStyles.h14w4Place.copyWith(
                                  color: AppColors.getTextPlaceholderColor(
                                    context,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.getBorderColor(context),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.getBorderColor(context),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.brandPrimary,
                                    width: 1,
                                  ),
                                ),
                                filled: true,
                                fillColor: AppColors.getBackgroundColor(
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // ──────────────────────────────────────────────────────────────
                // КНОПКА "ПОЖАЛОВАТЬСЯ"
                // ──────────────────────────────────────────────────────────────
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      border: Border(
                        top: BorderSide(
                          width: 0.5,
                          color: AppColors.getBorderColor(context),
                        ),
                      ),
                    ),
                    child: Material(
                      color:
                          _selectedReason != null &&
                              (_selectedReason != 'Другое' ||
                                  _otherReasonController.text.trim().isNotEmpty)
                          ? AppColors.textPrimary
                          : AppColors.textPrimary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      elevation: 0,
                      child: InkWell(
                        onTap:
                            _selectedReason != null &&
                                (_selectedReason != 'Другое' ||
                                    _otherReasonController.text
                                        .trim()
                                        .isNotEmpty)
                            ? () {
                                // Функционал будет добавлен позже
                              }
                            : null,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                _selectedReason != null &&
                                    (_selectedReason != 'Другое' ||
                                        _otherReasonController.text
                                            .trim()
                                            .isNotEmpty)
                                ? AppColors.textPrimary
                                : AppColors.textPrimary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Center(
                            child: Text(
                              'Пожаловаться',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
