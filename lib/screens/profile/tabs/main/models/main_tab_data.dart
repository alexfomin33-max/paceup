/// Фиксированные ассеты для активности (тип → локальный asset)
const Map<String, String> kActivityAssetByType = {
  'walking': 'assets/walking.png',
  'running': 'assets/running.png',
  'cycling': 'assets/cycling.png',
  'swimming': 'assets/swimming.png',
};

/// Фиксированные ассеты для PR (код дистанции → локальный asset)
const Map<String, String> kPrAssetByCode = {
  '5k': 'assets/5k.png',
  '10k': 'assets/10k.png',
  '21k': 'assets/21k.png',
  '42k': 'assets/42k.png',
};

class ActItem {
  final String asset;
  final String value;
  final String label;
  const ActItem(this.asset, this.value, this.label);
}

class GearItem {
  final String title;
  final String imageAsset;
  final String mileage; // '582 км'
  final String paceOrSpeed; // бег: '4:18 /км', велик: '35,7 км/ч'
  const GearItem({
    required this.title,
    required this.imageAsset,
    required this.mileage,
    required this.paceOrSpeed,
  });
}

class MetricsData {
  final String avgWeekDistance;
  final String vo2max;
  final String avgPace;
  final String power;
  final String cadence;
  const MetricsData({
    required this.avgWeekDistance,
    required this.vo2max,
    required this.avgPace,
    required this.power,
    required this.cadence,
  });
}

class PRAsset {
  final String path;
  const PRAsset(this.path);
}

class MainTabData {
  final List<ActItem> activity;
  final List<GearItem> shoes;
  final List<GearItem> bikes;
  final List<(PRAsset asset, String time)> prs;
  final MetricsData metrics;

  const MainTabData({
    required this.activity,
    required this.shoes,
    required this.bikes,
    required this.prs,
    required this.metrics,
  });

  factory MainTabData.fromJson(Map<String, dynamic> j) {
    // activity
    final act = <ActItem>[];
    for (final e in (j['activity'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final type = (m['type'] as String?)?.toLowerCase() ?? 'walking';
      final asset =
          kActivityAssetByType[type] ?? kActivityAssetByType['walking']!;
      act.add(
        ActItem(
          asset,
          m['value'] as String? ?? '0',
          m['label'] as String? ?? '',
        ),
      );
    }

    // shoes
    final shoes = <GearItem>[];
    for (final e in (j['shoes'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final stats = (m['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
      shoes.add(
        GearItem(
          title: m['title'] as String? ?? '',
          imageAsset: m['image'] as String? ?? 'assets/Asics.png',
          mileage: (stats['mileage'] as String?) ?? '0 км',
          paceOrSpeed:
              (stats['pace'] as String?) ?? (stats['speed'] as String?) ?? '-',
        ),
      );
    }

    // bikes
    final bikes = <GearItem>[];
    for (final e in (j['bikes'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final stats = (m['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
      bikes.add(
        GearItem(
          title: m['title'] as String? ?? '',
          imageAsset: m['image'] as String? ?? 'assets/bicycle.png',
          mileage: (stats['mileage'] as String?) ?? '0 км',
          paceOrSpeed:
              (stats['speed'] as String?) ?? (stats['pace'] as String?) ?? '-',
        ),
      );
    }

    // PRs
    final prs = <(PRAsset, String)>[];
    for (final e in (j['prs'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final code =
          ((m['code'] ?? m['distance']) as String?)?.toLowerCase() ?? '5k';
      final assetPath = kPrAssetByCode[code] ?? kPrAssetByCode['5k']!;
      prs.add((PRAsset(assetPath), m['time'] as String? ?? '-'));
    }

    // metrics
    final mm = (j['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
    final metrics = MetricsData(
      avgWeekDistance: mm['avg_week_distance'] as String? ?? '0 км',
      vo2max: mm['vo2max'] as String? ?? '-',
      avgPace: mm['avg_pace'] as String? ?? '-',
      power: mm['power'] as String? ?? '-',
      cadence: mm['cadence'] as String? ?? '-',
    );

    return MainTabData(
      activity: act,
      shoes: shoes,
      bikes: bikes,
      prs: prs,
      metrics: metrics,
    );
  }
}
