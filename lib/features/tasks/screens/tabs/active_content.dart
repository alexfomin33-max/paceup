// lib/screens/tabs/active_content.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../description/run_200k_screen.dart';
import '../description/suzdal_screen.dart';
import '../../../../core/widgets/transparent_route.dart';

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
              title: '10 дней активности',
              progressText: '6 / 10 дней',
              percent: 0.60,
              image: _RectImage(provider: AssetImage('assets/activity10.png')),
            ),
            const SizedBox(height: 12),

            TaskCard(
              title: '200 км бега',
              progressText: '145,8 / 200 км',
              percent: 0.729,
              image: const _RectImage(
                provider: AssetImage('assets/card200run.jpg'),
              ),
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  TransparentPageRoute(builder: (_) => const Run200kScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            const TaskCard(
              title: '1000 метров набора высоты',
              progressText: '537 / 1000 м',
              percent: 0.537,
              image: _RectImage(provider: AssetImage('assets/height1000.jpg')),
            ),
            const SizedBox(height: 12),

            const TaskCard(
              title: '1000 минут активности',
              progressText: '618 / 1000 мин',
              percent: 0.618,
              image: _RectImage(
                provider: AssetImage('assets/activity1000.png'),
              ),
            ),
            const SizedBox(height: 20),

            const _SectionLabel('Экспедиции'),
            const SizedBox(height: 8),

            ExpeditionCard(
              title: 'Суздаль',
              progressText: '21 784 / 110 033 шагов',
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
              progressText: '3 521 / 4 810 метров',
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
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : null,
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
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : null,
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Color? colorTint;
  final IconData? icon;
  final String? badgeText;
  final String title;
  final String progressText;
  final double percent;
  final VoidCallback? onTap;
  final Widget? image;

  const TaskCard({
    super.key,
    this.colorTint,
    this.icon,
    this.badgeText,
    required this.title,
    required this.progressText,
    required this.percent,
    this.onTap,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border.all(color: AppColors.getBorderColor(context)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Row(
        children: [
          // Отображаем изображение, если оно передано, иначе иконку с бейджем
          image ??
              (icon != null && colorTint != null && badgeText != null
                  ? _IconBadge(bg: colorTint!, icon: icon!, text: badgeText!)
                  : const SizedBox.shrink()),
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
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.getTextPrimaryColor(context),
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
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border.all(color: AppColors.getBorderColor(context)),
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
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextPrimaryColor(context),
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
                decoration: BoxDecoration(
                  color: AppColors.getBackgroundColor(context),
                  borderRadius: const BorderRadius.only(
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
          Icon(icon, size: 28, color: AppColors.getIconPrimaryColor(context)),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                border: Border.all(color: AppColors.getBorderColor(context)),
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
            ? Icon(
                CupertinoIcons.photo,
                size: 22,
                color: AppColors.getIconSecondaryColor(context),
              )
            : null,
      ),
    );
  }
}

/// Прямоугольное изображение для карточек задач
class _RectImage extends StatelessWidget {
  final ImageProvider? provider;
  const _RectImage({this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider == null) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.skeletonBase,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Icon(
          CupertinoIcons.photo,
          size: 22,
          color: AppColors.getIconSecondaryColor(context),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: 64,
        height: 64,
        child: Image(
          image: provider!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.skeletonBase,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              child: Icon(
                CupertinoIcons.photo,
                size: 22,
                color: AppColors.getIconSecondaryColor(context),
              ),
            );
          },
        ),
      ),
    );
  }
}
