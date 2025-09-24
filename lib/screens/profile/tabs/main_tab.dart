import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../state/gear_prefs.dart';

class MainTab extends StatefulWidget {
  const MainTab({super.key});
  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prefs = GearPrefsScope.of(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(child: _SectionTitle('Активность')),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: _ActivityScroller()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // КРОССОВКИ — только если включены в GearTab
        if (prefs.showShoes) ...[
          const SliverToBoxAdapter(child: _SectionTitle('Кроссовки')),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverToBoxAdapter(
            child: _GearCard(
              title: "Asics Jolt 3 Wide 'Dive Blue'",
              imageAsset: 'assets/Asics.png',
              stat1Label: 'Пробег:',
              stat1Value: '582 км',
              stat2Label: 'Темп:',
              stat2Value: '4:18 /км',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],

        // ВЕЛОСИПЕД — только если включены в GearTab
        if (prefs.showBikes) ...[
          const SliverToBoxAdapter(child: _SectionTitle('Велосипед')),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverToBoxAdapter(
            child: _GearCard(
              title: 'Pinarello Bolide TR Ultegra Di2',
              imageAsset: 'assets/bicycle.png',
              stat1Label: 'Пробег:',
              stat1Value: '3475 км',
              stat2Label: 'Темп:',
              stat2Value: '35,7 км/ч',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],

        // Остальные секции
        const SliverToBoxAdapter(child: _SectionTitle('Личные рекорды')),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: _PRRow()),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        const SliverToBoxAdapter(child: _SectionTitle('Показатели')),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: _MetricsCard()),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ───────────────────── Разделители/заголовки
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

// ───────────────────── Активность — горизонтальный скролл карточек
class _ActivityScroller extends StatelessWidget {
  const _ActivityScroller();

  @override
  Widget build(BuildContext context) {
    final items = <_ActItem>[
      _ActItem('assets/walking.png', '347,21', 'км, ходьба'),
      _ActItem('assets/running.png', '793,85', 'км, бег'),
      _ActItem('assets/cycling.png', '416,30', 'км, велосипед'),
      _ActItem('assets/swimming.png', '23,45', 'км, плавание'),
    ];
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, i) => _ActivityCard(items[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

class _ActItem {
  final String asset;
  final String value;
  final String label;
  _ActItem(this.asset, this.value, this.label);
}

class _ActivityCard extends StatelessWidget {
  final _ActItem item;
  const _ActivityCard(this.item);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                item.asset,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.0,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── Карточка с инвентарём
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
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ───────────────────── Личные рекорды
class _PRRow extends StatelessWidget {
  const _PRRow();

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('assets/5k.png', '23:08'),
      ('assets/10k.png', '44:26'),
      ('assets/21k.png', '1:41:37'),
      ('assets/42k.png', '2:51:48'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items
              .map((e) => _PRBadge(asset: e.$1, time: e.$2))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _PRBadge extends StatelessWidget {
  final String asset;
  final String time;
  const _PRBadge({required this.asset, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(asset, width: 72, height: 72, fit: BoxFit.contain),
        const SizedBox(height: 6),
        Text(
          time,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

// ───────────────────── Показатели
class _MetricsCard extends StatelessWidget {
  const _MetricsCard();

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (CupertinoIcons.arrow_right, 'Среднее расстояние в неделю', '62 км'),
      (CupertinoIcons.heart, 'МПК', '57'),
      (CupertinoIcons.speedometer, 'Средний темп', '5:13 / км'),
      (CupertinoIcons.bolt, 'Мощность', '213 ватт'),
      (CupertinoIcons.waveform, 'Каденс', '176'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
        ),
        child: Column(
          children: List.generate(rows.length, (i) {
            final r = rows[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(r.$1, size: 18, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.$2,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Text(
                        r.$3,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != rows.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFEAEAEA),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
