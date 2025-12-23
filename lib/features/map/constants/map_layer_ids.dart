/// ──────────── Константы идентификаторов слоёв и источников ────────────
/// Вынесены в отдельный файл, чтобы исключить опечатки и упростить поддержку.
class MapLayerIds {
  MapLayerIds._();

  static const String geoJsonSourceId = 'markers-source';
  static const String clusterLayerId = 'clusters';
  static const String clusterTextLayerId = 'cluster-count';
  static const String unclusteredLayerId = 'unclustered-point';
  static const String unclusteredCircleLayerId = 'unclustered-point-circle';
  static const String officialCircleLayerId = 'official-point-circle';
}

