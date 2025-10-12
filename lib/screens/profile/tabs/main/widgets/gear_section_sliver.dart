// =============== widgets/gear_section_sliver.dart ===============
// Sliver-секция "Снаряжение": заголовок + отступ + список карточек.
// Вставляется НАПРЯМУЮ в CustomScrollView.slivers (никаких SliverToBoxAdapter вокруг).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../models/main_tab_data.dart';

class GearSectionSliver extends StatelessWidget {
  final String title; // Заголовок секции ("Кроссовки"/"Велосипед")
  final List<GearItem> items; // Список элементов снаряжения
  final bool isBike; // Управляет подписью второй метрики: "Скорость" или "Темп"

  const GearSectionSliver({
    super.key,
    required this.title,
    required this.items,
    required this.isBike,
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

        // Остальные индексы — это карточки снаряжения
        final i = index - 2;
        if (i < 0 || i >= items.length) return const SizedBox.shrink();

        final g = items[i];
        final isLast = i == items.length - 1;

        return Padding(
          // Нижний отступ секции: у велосипедов он чуть больше, как было у тебя
          padding: EdgeInsets.only(bottom: isLast ? (isBike ? 16 : 12) : 12),
          child: _GearCard(
            title: g.title,
            imageAsset: g.imageAsset,
            stat1Label: 'Пробег:',
            stat1Value: g.mileage,
            stat2Label: isBike ? 'Скорость:' : 'Темп:',
            stat2Value: g.paceOrSpeed,
          ),
        );
      }, childCount: childCount),
    );
  }
}

/// Локальный заголовок секции (копия по стилю с экрана)
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Row(
          children: [
            // Превью изображения (лого/фото)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                  // Заголовок карточки + маленькая иконка "карандаш" справа
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        CupertinoIcons.pencil,
                        size: 16,
                        color: AppColors.greytext,
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
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.text,
        ),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: AppColors.greytext),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
