// lib/screens/walking_skill_tab.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/interactive_back_swipe.dart';

class WalkingSkillScreen extends StatelessWidget {
  const WalkingSkillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // ─────────── Неподвижный верхний блок
              _FixedHeader(onBack: () => Navigator.of(context).pop()),
              // ─────────── Контент скроллится отдельно
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 25), // требуемые 20px
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionTitle('Навык друзей'),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(color: AppColors.border, width: 0.5),
                          bottom: BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        children: List.generate(_rows.length, (i) {
                          final r = _rows[i];
                          final isMe = r.rank == 3; // подсветка как в макете
                          return _FriendRow(
                            rank: r.rank,
                            name: r.name,
                            value: r.value,
                            avatar: r.avatar,
                            highlight: isMe,
                            isLast: i == _rows.length - 1,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────── Верхний неподвижный блок
class _FixedHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _FixedHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        color: AppColors.surface,
        child: Column(
          children: [
            // Стрелка и большая иконка — в одной строке
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    splashRadius: 22,
                    icon: const Icon(
                      CupertinoIcons.back,
                      color: AppColors.iconPrimary,
                    ),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Center(
                      child: ClipOval(
                        child: Image.asset(
                          'assets/skill_2.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // симметрия под кнопку «назад»
                ],
              ),
            ),

            // Заголовок
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Пешеход', style: AppTextStyles.h17w6),
            ),
            const SizedBox(height: 10),

            // «10-й уровень»  |  «5 / 10» — строго в ширину 240
            const Center(
              child: SizedBox(
                width: 240,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '10-й уровень',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '5 / 10',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 1-й прогресс-бар (240 px)
            const Center(
              child: SizedBox(width: 240, child: _MiniProgress(percent: 0.5)),
            ),
            const SizedBox(height: 16),

            // Описание
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Пройдите необходимое количество шагов\nза день для развития навыка.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2-й прогресс-бар (240 px) + подпись без фона
            const Center(
              child: SizedBox(width: 240, child: _MiniProgress(percent: 0.0)),
            ),
            const SizedBox(height: 8),
            const Text(
              '0 / 7 000 шагов',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
          ],
        ),
      ),
    );
  }
}

/// ───── Вспомогательные

class _MiniProgress extends StatelessWidget {
  final double percent;
  const _MiniProgress({required this.percent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (percent.clamp(0.0, 1.0)) * c.maxWidth;
        return Row(
          children: [
            Container(
              width: w,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xs),
                  bottomLeft: Radius.circular(AppRadius.xs),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.xs)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final int rank;
  final String name;
  final String value; // число уровней
  final AssetImage avatar;
  final bool highlight;
  final bool isLast;

  const _FriendRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.avatar,
    required this.highlight,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(left: 12, right: 16, top: 8, bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: highlight ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: Image(
              image: avatar,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: highlight ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        row,
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 80,
            endIndent: 10,
            color: AppColors.divider,
          ),
      ],
    );
  }
}

// Демо-данные
class _RowData {
  final int rank;
  final String name;
  final String value; // строка "число"
  final AssetImage avatar;
  const _RowData(this.rank, this.name, this.value, this.avatar);
}

const _rows = <_RowData>[
  _RowData(1, 'Алексей Лукашин', '17', AssetImage('assets/avatar_1.png')),
  _RowData(2, 'Татьяна Свиридова', '12', AssetImage('assets/avatar_3.png')),
  _RowData(3, 'Евгений Бойко', '10', AssetImage('assets/avatar_0.png')),
  _RowData(4, 'Юрий Селиванов', '8', AssetImage('assets/avatar_5.png')),
  _RowData(5, 'Екатерина Виноградова', '8', AssetImage('assets/avatar_4.png')),
  _RowData(6, 'Борис Жарких', '6', AssetImage('assets/avatar_2.png')),
];
