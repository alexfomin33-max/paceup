// lib/screens/tabs/active_content.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../description/run_200k_screen.dart';
import '../description/suzdal_screen.dart';
import '../../../widgets/transparent_route.dart';

class ActiveContent extends StatelessWidget {
  const ActiveContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Вертикальный скролл + горизонтальные поля внутри контента
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MonthLabel('Июнь 2025'),
            const SizedBox(height: 8),

            const TaskCard(
              colorTint: AppColors.backgroundGreen,
              icon: CupertinoIcons.star,
              badgeText: '10 дней',
              title: '10 дней активности',
              progressText: '6 из 10 дней',
              percent: 0.60,
            ),
            const SizedBox(height: 12),

            TaskCard(
              colorTint: AppColors.backgroundYellow,
              icon: Icons.directions_run,
              badgeText: '200 км',
              title: '200 км бега',
              progressText: '145,8 из 200 км',
              percent: 0.729,
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  TransparentPageRoute(builder: (_) => const Run200kScreen()),
                );
              },
            ),
            const SizedBox(height: 12), 

            const TaskCard(
              colorTint: AppColors.backgroundBlue,
              icon: CupertinoIcons.arrow_up,
              badgeText: '1000 м',
              title: '1000 метров набора высоты',
              progressText: '537 из 1000 м',
              percent: 0.537,
            ),
            const SizedBox(height: 12),

            const TaskCard(
              colorTint: AppColors.backgroundPurple,
              icon: CupertinoIcons.stopwatch,
              badgeText: '1000 мин',
              title: '1000 минут активности',
              progressText: '618 из 1000 мин',
              percent: 0.618,
            ),
            const SizedBox(height: 20),

            const _SectionLabel('Экспедиции'),
            const SizedBox(height: 8),

            ExpeditionCard(
              title: 'Суздаль',
              progressText: '21 784 из 110 033 шагов',
              percent: 0.198,
              image: const _RoundImage(
                provider: AssetImage('assets/Suzdal.png'),
              ),
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  TransparentPageRoute(builder: (_) => const SuzdalScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            const ExpeditionCard(
              title: 'Монблан',
              progressText: '3 521 из 4 810 метров',
              percent: 0.732,
              image: _RoundImage(provider: AssetImage('assets/Monblan.png')),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// ===== Локальные виджеты «Активных» =====

class _MonthLabel extends StatelessWidget {
  final String text;
  const _MonthLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Color colorTint;
  final IconData icon;
  final String badgeText;
  final String title;
  final String progressText;
  final double percent;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.colorTint,
    required this.icon,
    required this.badgeText,
    required this.title,
    required this.progressText,
    required this.percent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _IconBadge(bg: colorTint, icon: icon, text: badgeText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _ProgressBar(percent: percent),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progressText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: onTap,
              child: card,
            ),
          );
  }
}

class ExpeditionCard extends StatelessWidget {
  final String title;
  final String progressText;
  final double percent;
  final Widget image;
  final VoidCallback? onTap;

  const ExpeditionCard({
    super.key,
    required this.title,
    required this.progressText,
    required this.percent,
    required this.image,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          image,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _ProgressBar(percent: percent),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progressText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: onTap,
              child: card,
            ),
          );
  }
}

class _ProgressBar extends StatelessWidget {
  final double percent;
  const _ProgressBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final currentWidth = (percent.clamp(0, 1)) * totalWidth;

        return Row(
          children: [
            Container(
              width: currentWidth,
              height: 6,
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
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(AppRadius.xs),
                    bottomRight: Radius.circular(AppRadius.xs),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IconBadge extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final String text;
  const _IconBadge({required this.bg, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 28, color: AppColors.iconPrimary),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSoft,
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundImage extends StatelessWidget {
  final ImageProvider? provider;
  const _RoundImage({this.provider});
  const _RoundImage.placeholder() : provider = null;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.skeletonBase,
          image: provider != null
              ? DecorationImage(image: provider!, fit: BoxFit.cover)
              : null,
        ),
        child: provider == null
            ? const Icon(
                CupertinoIcons.photo,
                size: 22,
                color: AppColors.iconSecondary,
              )
            : null,
      ),
    );
  }
}
