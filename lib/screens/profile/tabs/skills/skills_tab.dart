import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'walking_skill_tab.dart';
import '../../../../core/widgets/transparent_route.dart';

class SkillsTab extends StatefulWidget {
  const SkillsTab({super.key});
  @override
  State<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends State<SkillsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Главный агрегирующий навык
        const SliverToBoxAdapter(
          child: SkillCard(
            imageAsset: 'assets/skill_1.png',
            title: 'Уровень спортсмена',
            levelText: '24-й уровень',
            current: 9,
            max: 10,
          ),
        ),

        // Пояснение
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(
          child: _InfoNote(
            text:
                'Уровень спортсмена повышается при повышении уровней остальных навыков,\nа также за получение определённых наград',
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Остальные навыки
        SliverToBoxAdapter(
          child: Column(
            children: [
              SkillCard(
                imageAsset: 'assets/skill_2.png',
                title: 'Пешеход',
                levelText: '10-й уровень',
                current: 5,
                max: 10,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    TransparentPageRoute(
                      builder: (_) => const WalkingSkillScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const SkillCard(
                imageAsset: 'assets/skill_3.png',
                title: 'Бегун',
                levelText: '7-й уровень',
                current: 8,
                max: 10,
              ),
              const SizedBox(height: 12),
              const SkillCard(
                imageAsset: 'assets/skill_4.png',
                title: 'Велосипедист',
                levelText: '1-й уровень',
                current: 0,
                max: 10,
              ),
              const SizedBox(height: 12),
              const SkillCard(
                imageAsset: 'assets/skill_5.png',
                title: 'Пловец',
                levelText: '1-й уровень',
                current: 0,
                max: 10,
              ),
              const SizedBox(height: 12),
              const SkillCard(
                imageAsset: 'assets/skill_6.png',
                title: 'Покоритель вершин',
                levelText: '1-й уровень',
                current: 0,
                max: 10,
              ),
              const SizedBox(height: 12),
              const SkillCard(
                imageAsset: 'assets/skill_7.png',
                title: 'Член клуба PacePro',
                levelText: '3-й уровень',
                current: 0,
                max: 1,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// ───────────────────── Карточка навыка (как на Tasks)
class SkillCard extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String levelText; // «N-й уровень»
  final int current; // текущее значение
  final int max; // целевое значение (для прогресса)
  final VoidCallback? onTap;

  const SkillCard({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.levelText,
    required this.current,
    required this.max,
    this.onTap,
  });

  double get percent => max <= 0 ? 0 : (current / max).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.5, // тонкая рамка
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const SizedBox(width: 2),
          _SkillImage(asset: imageAsset),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                // Прогресс-бар
                _SkillProgressBar(percent: percent),
                const SizedBox(height: 6),
                // Уровень слева + счётчик справа
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        levelText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$current / $max',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
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

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Круглая картинка навыка 64×64 без цветной подложки
class _SkillImage extends StatelessWidget {
  final String asset;
  const _SkillImage({required this.asset});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(asset, width: 64, height: 64, fit: BoxFit.cover),
    );
  }
}

/// Полоска прогресса как в Tasks
class _SkillProgressBar extends StatelessWidget {
  final double percent;
  const _SkillProgressBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final cur = (percent.clamp(0, 1)) * w;
        return Row(
          children: [
            Container(
              width: cur,
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
                  borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xs)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Серый инфотекст
class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.getTextSecondaryColor(context),
          height: 1.5,
        ),
      ),
    );
  }
}
