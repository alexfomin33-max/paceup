import 'package:flutter/cupertino.dart';
import '../../../../../theme/app_theme.dart';
import '../models/main_tab_data.dart';

class GearSectionSliver extends StatelessWidget {
  final String title; // Заголовок секции ("Кроссовки"/"Велосипед")
  final List<GearItem> items; // Список элементов снаряжения
  final bool isBike; // Управляет подписью второй метрики: "Скорость" или "Темп"
  final VoidCallback? onItemTap; // 👈 колбэк на тап по карточке

  const GearSectionSliver({
    super.key,
    required this.title,
    required this.items,
    required this.isBike,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    // childCount = 2 (заголовок + отступ) + количество карточек
    final childCount = items.length + 2;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // 0: заголовок секции
        if (index == 0) {
          return _SectionTitle(title);
        }
        // 1: отступ после заголовка
        if (index == 1) {
          return const SizedBox(height: 8);
        }

        // Остальные индексы — карточки
        final i = index - 2;
        if (i < 0 || i >= items.length) return const SizedBox.shrink();

        final g = items[i];
        final isLast = i == items.length - 1;

        return Padding(
          // Нижний отступ секции: у велосипедов он чуть больше, как у тебя было
          padding: EdgeInsets.only(bottom: isLast ? (isBike ? 16 : 12) : 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onItemTap, // 👈 дергаем внешний колбэк
            child: _GearCard(
              title: g.title,
              imageAsset: g.imageAsset,
              stat1Label: 'Пробег:',
              stat1Value: g.mileage,
              stat2Label: isBike ? 'Скорость:' : 'Темп:',
              stat2Value: g.paceOrSpeed,
            ),
          ),
        );
      }, childCount: childCount),
    );
  }
}

/// Локальный заголовок секции
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: AppTextStyles.h15w6),
      ),
    );
  }
}

/// Карточка снаряжения: картинка + заголовок + две краткие метрики
class _GearCard extends StatelessWidget {
  final String title;
  final String imageAsset;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;

  const _GearCard({
    required this.title,
    required this.imageAsset,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Row(
          children: [
            // Превью изображения
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.asset(
                imageAsset,
                width: 72,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            // Текстовая часть с заголовком и метриками
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок карточки + "карандаш" справа
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h14w5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        CupertinoIcons.pencil,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Две метрики в одну строку
                  Row(
                    children: [
                      _InlineStat(label: stat1Label, value: stat1Value),
                      const SizedBox(width: 16),
                      _InlineStat(label: stat2Label, value: stat2Value),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Небольшой текстовый компонент "метка + значение"
class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  const _InlineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
