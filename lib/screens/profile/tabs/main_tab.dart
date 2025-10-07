import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../theme/app_theme.dart';
import '../state/gear_prefs.dart';

class MainTab extends StatefulWidget {
  final int userId;
  const MainTab({super.key, required this.userId});

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> with AutomaticKeepAliveClientMixin {
  // ⇩⇩⇩ Поменяй на свой реальный URL
  static const _apiEndpoint = 'http://api.paceup.ru/user_profile_maintab.php';

  Future<_MainTabData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant MainTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _future = _load();
    }
  }

  Future<_MainTabData> _load() async {
    final uri = Uri.parse(_apiEndpoint);

    final res = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: json.encode({'userId': widget.userId}),
    );

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    // Чистим возможный BOM и лишние пробелы
    final raw = utf8.decode(res.bodyBytes).replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    final jsonMap = json.decode(raw) as Map<String, dynamic>;

    if (jsonMap['ok'] == false) {
      throw Exception(jsonMap['error'] ?? 'API error');
    }

    return _MainTabData.fromJson(jsonMap);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prefs = GearPrefsScope.of(context);

    return FutureBuilder<_MainTabData>(
      future: _future ??= _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverFillRemainingCentered(child: CupertinoActivityIndicator());
        }
        if (snap.hasError) {
          return SliverFillRemainingCentered(
            child: Text(
              'Не удалось загрузить данные\n${snap.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.text),
            ),
          );
        }

        final data = snap.data!;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: _SectionTitle('Активность')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _ActivityScroller(items: data.activity)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // КРОССОВКИ — секция с единым заголовком
              if (prefs.showShoes && data.shoes.isNotEmpty) ..._buildGearSection(
                title: 'Кроссовки',
                items: data.shoes,
                isBike: false,
              ),

              // ВЕЛОСИПЕДЫ — секция с единым заголовком
              if (prefs.showBikes && data.bikes.isNotEmpty) ..._buildGearSection(
                title: 'Велосипед',
                items: data.bikes,
                isBike: true,
              ),


            const SliverToBoxAdapter(child: _SectionTitle('Личные рекорды')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _PRRow(items: data.prs)),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: _SectionTitle('Показатели')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _MetricsCard(data: data.metrics)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

// Фиксированные ассеты для активности (тип → локальный asset)
const Map<String, String> _kActivityAssetByType = {
  'walking':  'assets/walking.png',
  'running':  'assets/running.png',
  'cycling':  'assets/cycling.png',
  'swimming': 'assets/swimming.png',
};

// Фиксированные ассеты для PR (код дистанции → локальный asset)
const Map<String, String> _kPrAssetByCode = {
  '5k':  'assets/5k.png',
  '10k': 'assets/10k.png',
  '21k': 'assets/21k.png',
  '42k': 'assets/42k.png',
};

List<Widget> _buildGearSection({
  required String title,
  required List<_GearItem> items,
  required bool isBike,
}) {
  return [
    SliverToBoxAdapter(child: _SectionTitle(title)),
    const SliverToBoxAdapter(child: SizedBox(height: 8)),
    SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final g = items[i];
        final isLast = i == items.length - 1;

        return Padding(
          padding: EdgeInsets.only(
            bottom: isLast ? (isBike ? 16 : 12) : 12, // как у тебя было
          ),
          child: _GearCard(
            title: g.title,
            imageAsset: g.imageAsset,
            stat1Label: 'Пробег:',
            stat1Value: g.mileage,
            stat2Label: 'Темп:',
            stat2Value: g.paceOrSpeed, // для велика это «скорость»
          ),
        );
      },
    ),
  ];
}

/// ───────────────────── СЛУЖЕБНЫЕ МОДЕЛИ ДАННЫХ

class _MainTabData {
  final List<_ActItem> activity;
  final List<_GearItem> shoes;
  final List<_GearItem> bikes;
  final List<(_PRAsset asset, String time)> prs;
  final _MetricsData metrics;

  _MainTabData({
    required this.activity,
    required this.shoes,
    required this.bikes,
    required this.prs,
    required this.metrics,
  });

  factory _MainTabData.fromJson(Map<String, dynamic> j) {
    // activity (asset берём локально по type)
    final act = <_ActItem>[];
    for (final e in (j['activity'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final type = (m['type'] as String?)?.toLowerCase() ?? 'walking'; // walking|running|cycling|swimming
      final asset = _kActivityAssetByType[type] ?? _kActivityAssetByType['walking']!;
      act.add(_ActItem(
        asset,
        m['value'] as String? ?? '0',
        m['label'] as String? ?? '',
      ));
    }

    // shoes
    final shoes = <_GearItem>[];
    for (final e in (j['shoes'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final stats = (m['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
      shoes.add(_GearItem(
        title: m['title'] as String? ?? '',
        imageAsset: m['image'] as String? ?? 'assets/Asics.png',
        mileage: (stats['mileage'] as String?) ?? '0 км',
        paceOrSpeed: (stats['pace'] as String?) ?? (stats['speed'] as String?) ?? '-',
      ));
    }

    // bikes
    final bikes = <_GearItem>[];
    for (final e in (j['bikes'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final stats = (m['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
      bikes.add(_GearItem(
        title: m['title'] as String? ?? '',
        imageAsset: m['image'] as String? ?? 'assets/bicycle.png',
        mileage: (stats['mileage'] as String?) ?? '0 км',
        paceOrSpeed: (stats['speed'] as String?) ?? (stats['pace'] as String?) ?? '-',
      ));
    }

    // PRs (asset берём локально по коду дистанции)
    final prs = <(_PRAsset, String)>[];
    for (final e in (j['prs'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final code = ((m['code'] ?? m['distance']) as String?)?.toLowerCase() ?? '5k'; // '5k'|'10k'|'21k'|'42k'
      final assetPath = _kPrAssetByCode[code] ?? _kPrAssetByCode['5k']!;
      prs.add((_PRAsset(assetPath), m['time'] as String? ?? '-'));
    }

    // metrics
    final mm = (j['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
    final metrics = _MetricsData(
      avgWeekDistance: mm['avg_week_distance'] as String? ?? '0 км',
      vo2max: mm['vo2max'] as String? ?? '-',
      avgPace: mm['avg_pace'] as String? ?? '-',
      power: mm['power'] as String? ?? '-',
      cadence: mm['cadence'] as String? ?? '-',
    );

    return _MainTabData(
      activity: act,
      shoes: shoes,
      bikes: bikes,
      prs: prs,
      metrics: metrics,
    );
  }
}

class _GearItem {
  final String title;
  final String imageAsset;
  final String mileage;      // '582 км'
  final String paceOrSpeed;  // бег: '4:18 /км', велик: '35,7 км/ч'
  _GearItem({
    required this.title,
    required this.imageAsset,
    required this.mileage,
    required this.paceOrSpeed,
  });
}

class _MetricsData {
  final String avgWeekDistance;
  final String vo2max;
  final String avgPace;
  final String power;
  final String cadence;
  const _MetricsData({
    required this.avgWeekDistance,
    required this.vo2max,
    required this.avgPace,
    required this.power,
    required this.cadence,
  });
}

class _PRAsset {
  final String path;
  const _PRAsset(this.path);
}

/// ───────────────────── UI-компоненты (вёрстку не трогаем)

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {super.key});

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

class _ActivityScroller extends StatelessWidget {
  final List<_ActItem> items;
  const _ActivityScroller({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
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

class _GearCard extends StatelessWidget {
  final String title;
  final String imageAsset;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;

  const _GearCard({
    super.key,
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

class _PRRow extends StatelessWidget {
  final List<(_PRAsset, String)> items;
  const _PRRow({super.key, required this.items});

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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items
              .map((e) => _PRBadge(asset: e.$1.path, time: e.$2))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _PRBadge extends StatelessWidget {
  final String asset;
  final String time;
  const _PRBadge({super.key, required this.asset, required this.time});

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

class _MetricsCard extends StatelessWidget {
  final _MetricsData data;
  const _MetricsCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (CupertinoIcons.arrow_right, 'Среднее расстояние в неделю', data.avgWeekDistance),
      (CupertinoIcons.heart, 'МПК', data.vo2max),
      (CupertinoIcons.speedometer, 'Средний темп', data.avgPace),
      (CupertinoIcons.bolt, 'Мощность', data.power),
      (CupertinoIcons.waveform, 'Каденс', data.cadence),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  const Divider(height: 1, thickness: 0.5, color: Color(0xFFEAEAEA)),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Центрирование индикатора/текста во всю высоту списка sliver
class SliverFillRemainingCentered extends StatelessWidget {
  final Widget child;
  const SliverFillRemainingCentered({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: child),
        ),
      ],
    );
  }
}