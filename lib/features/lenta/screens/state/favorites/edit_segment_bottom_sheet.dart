// ─────────────────────────────────────────────────────────────────────────────
// Окно редактирования участка: только переименование.
// Используется: Избранное → Участки.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../core/services/segments_service.dart';
import '../../../../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Показ нижнего листа редактирования названия участка.
// ─────────────────────────────────────────────────────────────────────────────
void showEditSegmentBottomSheet(
  BuildContext context, {
  required SegmentWithMyResult segment,
  required int userId,
  required void Function(String name) onSaved,
}) {
  // ── Открываем модальный лист с прозрачным фоном как в маршрутах
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (ctx) {
      return _SegmentEditSheetWrapper(
        initialName: segment.name,
        fallbackName: segment.name,
        onConfirm: (name) async {
          // ── Сохраняем новое название и обновляем список в родителе
          await SegmentsService().updateSegmentName(
            segmentId: segment.id,
            userId: userId,
            name: name,
          );
          if (context.mounted) {
            onSaved(name);
          }
        },
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Обёртка: отступ под клавиатуру, SafeArea и контейнер листа.
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentEditSheetWrapper extends StatelessWidget {
  const _SegmentEditSheetWrapper({
    required this.initialName,
    required this.fallbackName,
    required this.onConfirm,
  });

  final String initialName;
  final String fallbackName;
  final Future<void> Function(String name) onConfirm;

  @override
  Widget build(BuildContext context) {
    // ── Учитываем клавиатуру и формируем контейнер листа
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: EdgeInsets.all(
            AppSpacing.sm - (AppSpacing.xs / 2),
          ),
          child: GestureDetector(
            // ── Закрываем клавиатуру по тапу по пустому месту
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.opaque,
            child: _SegmentEditSheetContent(
              initialName: initialName,
              fallbackName: fallbackName,
              onConfirm: onConfirm,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Контент листа: ручка, заголовок, поле названия, кнопка сохранения.
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentEditSheetContent extends StatefulWidget {
  const _SegmentEditSheetContent({
    required this.initialName,
    required this.fallbackName,
    required this.onConfirm,
  });

  final String initialName;
  final String fallbackName;
  final Future<void> Function(String name) onConfirm;

  @override
  State<_SegmentEditSheetContent> createState() =>
      _SegmentEditSheetContentState();
}

class _SegmentEditSheetContentState extends State<_SegmentEditSheetContent> {
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // ── Инициализируем контроллер текущим названием
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    // ── Освобождаем контроллер, чтобы избежать утечки памяти
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Основной вертикальный контент листа
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHandle(context),
        _buildTitle(context),
        const SizedBox(height: AppSpacing.lg),
        SingleChildScrollView(
          // ── Скролл нужен на маленьких экранах с клавиатурой
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SectionTitle('Название участка'),
              const SizedBox(height: AppSpacing.sm),
              _buildNameField(context),
              if (_errorText != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildErrorText(_errorText!),
              ],
              const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
              _buildSaveButton(context),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI блоки листа
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHandle(BuildContext context) {
    // ── Ручка для визуального перетаскивания листа
    return Container(
      width: AppSpacing.lg,
      height: AppSpacing.xs,
      margin: const EdgeInsets.only(
        bottom: AppSpacing.sm,
        top: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.getBorderColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    // ── Заголовок листа
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Center(
        child: Text(
          'Сохранить участок',
          style: AppTextStyles.h17w6.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    // ── Поле ввода нового названия участка
    return TextField(
      controller: _nameController,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _handleSave(),
      style: AppTextStyles.h15w4.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
      decoration: InputDecoration(
        hintText: 'Введите название',
        hintStyle: AppTextStyles.h15w4.copyWith(
          color: AppColors.getTextSecondaryColor(context),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md - AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }

  Widget _buildErrorText(String text) {
    // ── Ошибка в виде SelectableText.rich по требованиям UX
    return SelectableText.rich(
      TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.error),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    // ── Кнопка сохранения с блокировкой во время запроса
    return ElevatedButton(
      onPressed: _isSaving ? null : _handleSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.getSurfaceColor(context),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: const StadiumBorder(),
        minimumSize: const Size(double.infinity, 50),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
      child: _isSaving
          ? const CupertinoActivityIndicator(
              radius: AppSpacing.sm,
              color: AppColors.surface,
            )
          : Text(
              'Сохранить',
              style: AppTextStyles.h15w5.copyWith(
                color: AppColors.getSurfaceColor(context),
                height: 1.0,
              ),
            ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Логика сохранения с обработкой ошибок.
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _handleSave() async {
    if (_isSaving) return;
    // ── Нормализуем название: пустое заменяем на fallback
    final rawName = _nameController.text.trim();
    final finalName = rawName.isEmpty
        ? widget.fallbackName
        : rawName;
    if (finalName.trim().isEmpty) {
      setState(() {
        _errorText = 'Название участка обязательно';
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      // ── Сохраняем на сервере и закрываем лист при успехе
      await widget.onConfirm(finalName);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      // ── Показываем ошибку текстом, без SnackBar
      setState(() {
        _errorText = 'Ошибка: ${e.toString()}';
        _isSaving = false;
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Заголовок секции (как в листе маршрутов).
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    // ── Единый стиль заголовков секций
    return Text(
      title,
      style: AppTextStyles.h14w6.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
    );
  }
}
