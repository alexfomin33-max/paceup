class EquipmentItem {
  final int id;
  final String type;      // shoes | bike | watch | other ...
  final String name;      // удобное «бренд + модель» или просто имя
  final String? brand;
  final String? model;
  final String? photo;    // полный URL
  final double? distanceKm;
  final bool? primary;

  const EquipmentItem({
    required this.id,
    required this.type,
    required this.name,
    this.brand,
    this.model,
    this.photo,
    this.distanceKm,
    this.primary,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> j) {
    double? _toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().trim().replaceAll(',', '.');
      return double.tryParse(s);
    }

    return EquipmentItem(
      id: (j['id'] is int) ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      type: (j['type'] ?? 'other').toString(),
      name: (j['name'] ?? '').toString(),
      brand: (j['brand']?.toString().trim().isEmpty ?? true) ? null : j['brand'].toString(),
      model: (j['model']?.toString().trim().isEmpty ?? true) ? null : j['model'].toString(),
      photo: (j['photo']?.toString().trim().isEmpty ?? true) ? null : j['photo'].toString(),
      distanceKm: _toD(j['distance_km']),
      primary: j['primary'] == true || j['primary'] == 1 || j['primary'] == '1',
    );
  }
}

class MainTabData {
  final Map<String, dynamic> metrics;   // любые метрики: power_w, hr_rest, vo2max, height_cm, ...
  final List<EquipmentItem> equipment;  // список ВСЕГО снаряжения

  const MainTabData({required this.metrics, required this.equipment});

  factory MainTabData.fromJson(Map<String, dynamic> j) {
    final m = (j['metrics'] is Map) ? Map<String, dynamic>.from(j['metrics'] as Map) : <String, dynamic>{};
    final list = <EquipmentItem>[];
    final raw = j['equipment'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) list.add(EquipmentItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return MainTabData(metrics: m, equipment: list);
  }
}
