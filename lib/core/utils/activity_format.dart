/// 12.07.2025, 18:50
String formatDate(DateTime? dt) {
  if (dt == null) return '';
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$dd.$mm.${dt.year}, $hh:$min';
}

/// 1:05:12 или 05:12 (если часов 0)
String formatDuration(num? seconds) {
  if (seconds == null) return '';
  final total = seconds.toInt();
  final h = total ~/ 3600;
  final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// avgPace (мин/км): 5.3 → 5:18
String formatPace(double paceMinPerKm) {
  final minutes = paceMinPerKm.floor();
  final seconds = ((paceMinPerKm - minutes) * 60).round().toString().padLeft(
    2,
    '0',
  );
  return '$minutes:$seconds';
}

/// ────────────────────────────────────────────────────────────────
/// 🖼️ Дефолтное фото при отсутствии маршрута и фотографий тренировки
/// (добавление вручную без фото, импорт без маршрута).
/// 1) Бег — nogps.jpg  2) Велосипед — nogsp_bike.jpg
/// 3) Плавание — nogps_swim.jpg  4) Лыжи — nogps_ski.jpg
/// ────────────────────────────────────────────────────────────────
String getDefaultNoRouteImagePath(String activityType) {
  final t = activityType.toLowerCase();
  if (t == 'swim' || t == 'swimming') return 'assets/nogps_swim.jpg';
  if (t == 'bike' || t == 'bicycle' || t == 'cycling') {
    return 'assets/nogsp_bike.jpg';
  }
  if (t == 'ski') return 'assets/nogps_ski.jpg';
  return 'assets/nogps.jpg'; // run, running, прочее
}
