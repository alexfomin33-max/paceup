import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';

class CombiningScreen extends StatelessWidget {
  const CombiningScreen({super.key});

  /// Кнопка объединения тренировок
  Widget _buildCombineButton(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);

    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.button,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        shape: const StadiumBorder(),
        minimumSize: const Size(double.infinity, 50),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
      child: Text(
        'Объединить',
        style: AppTextStyles.h15w5.copyWith(
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.getSurfaceColor(context),
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'Объединение тренировки',
            style: AppTextStyles.h17w6.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          leading: IconButton(
            splashRadius: 22,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              CupertinoIcons.back,
              size: 22,
              color: AppColors.getIconPrimaryColor(context),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.getBorderColor(context),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ——— Прокручиваемая область с контентом
              Expanded(
                child: CustomScrollView(
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
                            dateText: '7 июня, в 16:40',
                            distance: '16,08',
                            pace: '5:24',
                            time: '1:26:34',
                            hr: '148',
                          ),
                          SizedBox(height: 12),
                          _TrainingCard(
                            dateText: '7 июня, в 18:24',
                            distance: '5,12',
                            pace: '5:47',
                            time: '45:18',
                            hr: '154',
                          ),
                        ],
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 20)),

                    // ——— Заголовок "После объединения"
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'После объединения',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimaryColor(context),
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
                            dateText: '7 июня, в 16:40',
                            distance: '21,20',
                            pace: '5:32',
                            time: '2:11:52',
                            hr: '150',
                          ),
                        ],
                      ),
                    ),

                    // ——— Добавляем нижний отступ для контента перед зафиксированной кнопкой
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),

              // ——— Зафиксированная кнопка "Объединить" внизу экрана
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.getBackgroundColor(context),
                child: _buildCombineButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ——— Инфо-блок над карточками
class _InfoText extends StatelessWidget {
  const _InfoText();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text:
                'Объединить возможно только тренировки, выполненные в один день.\n\n',
          ),
          const TextSpan(
            text:
                'Финиш одной и старт другой тренировки должны быть с минимальным расстоянием по геолокации.\n\n',
          ),
          const TextSpan(
            text: 'Показаны те тренировки, которые возможно объединить.',
          ),
        ],
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          height: 1.30,
          color: AppColors.getTextSecondaryColor(context),
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
        color: AppColors.getSurfaceColor(context),
        border: Border.all(color: AppColors.twinchip, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          const BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 10,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Дата
          Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 16,
                color: AppColors.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 8),
              Text(
                dateText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Карта + метрики
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: Image.asset(
                  'assets/training_map.png',
                  width: 130,
                  height: 85,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // две колонки метрик
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: _MetricColumn(
                        topTitle: 'Расстояние, км',
                        topValue: distance,
                        bottomTitle: 'Темп, мин/км',
                        bottomValue: pace,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _MetricColumn(
                        topTitle: 'Время',
                        topValue: time,
                        bottomTitle: 'Пульс',
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
    final label = TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      color: AppColors.getTextSecondaryColor(context),
    );
    final value = TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.getTextPrimaryColor(context),
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
        // Для "Пульс" добавляем красное сердечко после числа
        bottomTitle == 'Пульс'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(bottomValue, style: value),
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.heart_fill,
                    size: 11,
                    color: AppColors.error,
                  ),
                ],
              )
            : Text(bottomValue, style: value),
      ],
    );
  }
}
