import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CombiningScreen extends StatelessWidget {
  const CombiningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Объединение тренировки',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          splashRadius: 22,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.iconPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ——— Инфо-текст
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _InfoText(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ——— Две тренировки, которые можно объединить
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList.list(
              children: const [
                _TrainingCard(
                  dateText: '7 июня 2025, в 16:40',
                  distance: '16,08 км',
                  pace: '5:24 /км',
                  time: '1:26:34',
                  hr: '148',
                ),
                SizedBox(height: 12),
                _TrainingCard(
                  dateText: '7 июня 2025, в 18:24',
                  distance: '5,12 км',
                  pace: '5:47 /км',
                  time: '45:18',
                  hr: '154',
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ——— Заголовок "После объединения"
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'После объединения',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ——— Итоговая карточка
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList.list(
              children: const [
                _TrainingCard(
                  dateText: '7 июня 2025, в 16:40',
                  distance: '21,20 км',
                  pace: '5:32 /км',
                  time: '2:11:52',
                  hr: '150',
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 18)),

          // ——— Кнопка "Объединить"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Объединить',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// ——— Инфо-блок над карточками
class _InfoText extends StatelessWidget {
  const _InfoText();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text:
                'Объединить возможно только тренировки, выполненные в один день.\n\n',
          ),
          TextSpan(
            text:
                'Финиш одной и старт другой тренировки должны быть с минимальным расстоянием по геолокации.\n\n',
          ),
          TextSpan(
            text: 'Показаны те тренировки, которые возможно объединить.',
          ),
        ],
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          height: 1.30,
          color: AppColors.textSecondary,
        ),
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// ——— Карточка одной тренировки (карта + метрики)
class _TrainingCard extends StatelessWidget {
  final String dateText;
  final String distance;
  final String pace;
  final String time;
  final String hr;

  const _TrainingCard({
    required this.dateText,
    required this.distance,
    required this.pace,
    required this.time,
    required this.hr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Дата
          Row(
            children: [
              const Icon(
                CupertinoIcons.calendar,
                size: 16,
                color: AppColors.iconPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                dateText,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Карта + метрики
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/training_map.png',
                  width: 140,
                  height: 85,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // две колонки метрик
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricColumn(
                        topTitle: 'Расстояние',
                        topValue: distance,
                        bottomTitle: 'Темп',
                        bottomValue: pace,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _MetricColumn(
                        topTitle: 'Время',
                        topValue: time,
                        bottomTitle: 'Ср. пульс',
                        bottomValue: hr,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String topTitle;
  final String topValue;
  final String bottomTitle;
  final String bottomValue;
  const _MetricColumn({
    required this.topTitle,
    required this.topValue,
    required this.bottomTitle,
    required this.bottomValue,
  });

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11,
      color: AppColors.textSecondary,
    );
    const value = TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(topTitle, style: label),
        const SizedBox(height: 1),
        Text(topValue, style: value),
        const SizedBox(height: 10),
        Text(bottomTitle, style: label),
        const SizedBox(height: 1),
        Text(bottomValue, style: value),
      ],
    );
  }
}
