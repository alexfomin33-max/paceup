import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

/// «Мои» — заголовок/дата снаружи + табличная карточка во всю ширину:
/// [превью] │ [дистанция] │ [время] │ [темп]
List<Widget> buildMyRacesSlivers() {
  final items = <_RaceItem>[
    _RaceItem(
      'СберПрайм Казанский марафон 2025',
      DateTime(2025, 5, 3),
      42.2,
      '3:38:37',
      '4:15 /км',
      'assets/race_kazan.png',
    ),
    _RaceItem(
      'Московский полумарафон 2025',
      DateTime(2025, 4, 27),
      21.1,
      '1:42:50',
      '4:25 /км',
      'assets/race_moscow.png',
    ),
    _RaceItem(
      'Полумарафон «Красная нить»',
      DateTime(2024, 7, 5),
      21.1,
      '1:48:24',
      '4:31 /км',
      'assets/race_ivanovo.png',
    ),
    _RaceItem(
      'Марафон «Алые Паруса»',
      DateTime(2024, 6, 21),
      42.2,
      '3:58:16',
      '5:28 /км',
      'assets/race_spb.png',
    ),
  ];

  return [
    SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) => _RaceBlock(item: items[i]),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 12)),
  ];
}

class _RaceItem {
  final String title;
  final DateTime date;
  final double km;
  final String time;
  final String pace;
  final String asset;
  _RaceItem(this.title, this.date, this.km, this.time, this.pace, this.asset);
}

class _RaceBlock extends StatelessWidget {
  final _RaceItem item;
  const _RaceBlock({required this.item});

  // static const double _previewCellWidth = 90; // фикс. ширина левой ячейки

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Заголовок и дата — с горизонтальным полем 12
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h14w5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt(item.date),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Табличная карточка — во всю ширину экрана
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ЯЧЕЙКА 1: превью с паддингом 4 по всем сторонам
                SizedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      child: Image.asset(item.asset, width: 80, height: 53),
                    ),
                  ),
                ),

                // │ разделитель (½ высоты строки)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: FractionallySizedBox(
                    heightFactor: 0.5,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 0.5,
                      color: AppColors.divider,
                    ),
                  ),
                ),

                // ЯЧЕЙКА 2: дистанция
                Expanded(
                  child: Center(
                    child: _metric(
                      Icons.directions_run,
                      '${item.km.toStringAsFixed(1)} км',
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: FractionallySizedBox(
                    heightFactor: 0.5,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 0.5,
                      color: AppColors.divider,
                    ),
                  ),
                ),

                // ЯЧЕЙКА 3: время
                Expanded(
                  child: Center(child: _metric(Icons.access_time, item.time)),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: FractionallySizedBox(
                    heightFactor: 0.5,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 0.5,
                      color: AppColors.divider,
                    ),
                  ),
                ),

                // ЯЧЕЙКА 4: темп
                Expanded(child: Center(child: _metric(Icons.speed, item.pace))),
              ],
            ),
          ),
        ),

        // Отступ до следующего заголовка
        const SizedBox(height: 20),
      ],
    );
  }

  static Widget _metric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.brandPrimary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400, // мягче, как в «Друзьях»
            ),
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
