import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Каркас bottom sheet для вкладки «Тренеры» — 1:1 как в events_bottom_sheet.dart
class CoachesBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFraction;

  const CoachesBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.maxHeightFraction = 0.5, // не выше 50% экрана
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final maxH = h * maxHeightFraction;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // «ручка»
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10, top: 6),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),

              // заголовок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(title, style: AppTextStyles.h17w6)),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 6),

              // контент
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: child,
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Заглушка (если контента нет)
class CoachesSheetPlaceholder extends StatelessWidget {
  const CoachesSheetPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Text('Здесь будет контент…', style: TextStyle(fontSize: 14)),
    );
  }
}

/// Простой текст (аналог EventsSheetText/ClubsSheetText)
class CoachesSheetText extends StatelessWidget {
  final String text;
  const CoachesSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 14));
  }
}

/// Пригодится позже: пример списка тренеров с превью 90×60 (как в «Событиях»)
/// Пока НЕ используем, чтобы не требовать ассеты. Когда будут картинки,
/// просто подставишь CoachesListVladimir() в маркер.
class CoachesListVladimir extends StatelessWidget {
  const CoachesListVladimir({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      // нижний отступ как в events/clubs
      padding: EdgeInsets.fromLTRB(0, 0, 0, 50),
      child: Column(
        children: [
          // Примеры: замени asset/тексты на реальные, когда появятся
          _CoachRow(
            asset: 'assets/coach_example_1.png',
            title: 'Тренер на «Золотые ворота»',
            subtitle: '10 км · 21 июля 2025 · 1 тренер',
          ),
          _CoachesDivider(),
          _CoachRow(
            asset: 'assets/coach_example_2.png',
            title: 'Тренер на трейл «Клязьма»',
            subtitle: '30 км · 3 августа 2025 · 2 тренера',
          ),
        ],
      ),
    );
  }
}

class _CoachesDivider extends StatelessWidget {
  const _CoachesDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
    );
  }
}

/// Ряд тренера — превью строго 90×60, стили как в events/clubs
class _CoachRow extends StatelessWidget {
  final String asset;
  final String title;
  final String subtitle;

  const _CoachRow({
    required this.asset,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(asset, width: 90, height: 60, fit: BoxFit.cover),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // заголовок
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              // подпись
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );

    return row;
  }
}

