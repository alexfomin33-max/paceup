// lib/screens/profile_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;

  final List<String> _tabs = const [
    'Основное',
    'Фото',
    'Статистика',
    'Тренировки',
    'Соревнования',
    'Снаряжение',
    'Клубы',
    'Награды',
    'Навыки',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Тонкая линия под AppBar (как в iOS)
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 0.5,
              child: ColoredBox(color: Color(0xFFEAEAEA)),
            ),
          ),

          // Профиль (аватар, имя, город, подписки)
          const SliverToBoxAdapter(child: _HeaderCard()),

          // Табы (как на макете)
          SliverToBoxAdapter(
            child: _TabsBar(
              value: _tab,
              items: const [
                'Основное',
                'Фото',
                'Статистика',
                'Тренировки',
                'Соревнования',
                'Снаряжение',
                'Клубы',
                'Награды',
                'Навыки',
              ],
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),

          // Контент активной вкладки
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _tab == 0
                  ? const _MainTab()
                  : _ComingSoon(
                      label: [
                        'Фото',
                        'Статистика',
                        'Тренировки',
                        'Соревнования',
                        'Снаряжение',
                        'Клубы',
                        'Награды',
                        'Навыки',
                      ][_tab - 1],
                    ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 8,
      title: Row(
        children: [
          const Icon(CupertinoIcons.sparkles, size: 18, color: AppColors.text),
          const SizedBox(width: 8),
          const Text(
            'AI тренер',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Pro',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
      actions: const [
        _AppIcon(CupertinoIcons.square_list),
        _AppIcon(CupertinoIcons.square_arrow_up),
        _AppIcon(CupertinoIcons.bell),
        _AppIcon(CupertinoIcons.gear),
        SizedBox(width: 6),
      ],
    );
  }
}

class _AppIcon extends StatelessWidget {
  final IconData icon;
  const _AppIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.text, size: 20),
      onPressed: () {},
      splashRadius: 18,
    );
  }
}

/// ───────────────────── Header
class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // “прилипает” к краям
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Аватар
          ClipOval(
            child: Image.asset(
              'assets/avatar.png', // <-- твой ассет
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),

          // Имя, возраст, город + подписки
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Имя + карандаш
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Константин Разумовский',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SmallIconBtn(icon: CupertinoIcons.pencil, onTap: () {}),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '38 лет, Санкт-Петербург',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.greytext,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    _FollowStat(label: 'Подписки', value: '736'),
                    SizedBox(width: 18),
                    _FollowStat(label: 'Подписчики', value: '659'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.text),
      ),
    );
  }
}

class _FollowStat extends StatelessWidget {
  final String label;
  final String value;
  const _FollowStat({required this.label, required this.value});

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
          const TextSpan(
            text: 'Подписки: ',
            style: TextStyle(color: AppColors.greytext),
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

/// ───────────────────── Tabs
class _TabsBar extends StatelessWidget {
  final int value;
  final List<String> items;
  final ValueChanged<int> onChanged;
  const _TabsBar({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (_, i) {
                final selected = i == value;
                return GestureDetector(
                  onTap: () => onChanged(i),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      items[i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? AppColors.text : AppColors.greytext,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: items.length,
            ),
          ),
          Container(height: 0.5, color: const Color(0xFFEAEAEA)),
        ],
      ),
    );
  }
}

/// ───────────────────── Tab “Основное”
class _MainTab extends StatelessWidget {
  const _MainTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 12),
        _SectionTitle('Активность'),
        SizedBox(height: 8),
        _ActivityScroller(),

        SizedBox(height: 16),
        _SectionTitle('Кроссовки'),
        SizedBox(height: 8),
        _GearCard(
          title: "Asics Jolt 3 Wide 'Dive Blue'",
          imageAsset:
              'assets/Asics.png', // иллюстрация, если нужна обувь — можно заменить
          stat1Label: 'Пробег:',
          stat1Value: '582 км',
          stat2Label: 'Темп:',
          stat2Value: '4:18 /км',
        ),

        SizedBox(height: 12),
        _SectionTitle('Велосипед'),
        SizedBox(height: 8),
        _GearCard(
          title: 'Pinarello Bolide TR Ultegra Di2',
          imageAsset: 'assets/bicycle.png', // <-- твой ассет
          stat1Label: 'Пробег:',
          stat1Value: '3475 км',
          stat2Label: 'Темп:',
          stat2Value: '35,7 км/ч',
        ),

        SizedBox(height: 16),
        _SectionTitle('Личные рекорды'),
        SizedBox(height: 8),
        _PRRow(),

        SizedBox(height: 16),
        _SectionTitle('Показатели'),
        SizedBox(height: 8),
        _MetricsCard(),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft, // <-- вместо center
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

/// Активность — горизонтальный скролл карточек
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
      height: 126, // запас по высоте, чтобы не было overflow
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
    return Container(
      width: 144,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 0.5),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.asset(
              item.asset,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.0,
              color: AppColors.greytext,
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка с инвентарём (кроссовки, велосипед)
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
            // Картинка
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                imageAsset,
                width: 84,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            // Текст
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
                      const SizedBox(width: 6),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: AppColors.greytext,
                      ),
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

/// Личные рекорды — ряд бэджей (с ассетами)
class _PRRow extends StatelessWidget {
  const _PRRow();

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[
      ('assets/5k.png', '5', '23:08'),
      ('assets/10k.png', '10', '44:26'),
      ('assets/21k.png', '21,1', '1:41:37'),
      ('assets/42k.png', '42,2', '2:51:48'),
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
              .map((e) => _PRBadge(asset: e.$1, time: e.$3))
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

/// Показатели — список с иконками
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
                          fontWeight: FontWeight.w600,
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

/// Заглушка для ещё не реализованных вкладок
class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Text(
        '$label — скоро ✨',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.greytext,
        ),
      ),
    );
  }
}
