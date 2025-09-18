import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:paceup/theme/app_theme.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final markers = [
      {
        'point': LatLng(56.129057, 40.406635),
        'title': 'События во Владимире',
        'count': 2,
      },
      {
        'point': LatLng(55.755864, 37.617698),
        'title': 'События в Москве',
        'count': 5,
      },
      {
        'point': LatLng(56.326797, 44.006516),
        'title': 'События в Нижнем Новгороде',
        'count': 4,
      },
      {
        'point': LatLng(57.626559, 39.893813),
        'title': 'События в Ярославле',
        'count': 2,
      },
      {
        'point': LatLng(56.999799, 40.973014),
        'title': 'События в Иванове',
        'count': 1,
      },
    ];

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(56.129057, 40.406635),
        initialZoom: 6.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'paceup.ru',
        ),
        MarkerLayer(
          markers: markers.map((marker) {
            return Marker(
              point: marker['point'] as LatLng,
              width: 28,
              height: 28,
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: Navigator.of(context, rootNavigator: true).context,
                    isScrollControlled:
                        true, // чтобы при длинном контенте можно было скроллить
                    backgroundColor: Colors.transparent,
                    builder: (_) => Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.large),
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Wrap(
                        // 🔹 Контейнер подстраивается под высоту контента
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  marker['title'] as String,
                                  style: AppTextStyles.h1,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(height: 1, color: AppColors.border),
                              const SizedBox(height: 12),
                              // Таблица с событиями
                              Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Image.asset(
                                        'assets/Vlad_event_1.png',
                                        width: 90,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              "Субботний коферан",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "14 июня 2025  ·  Участников: 32",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: AppColors.text,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Image.asset(
                                        'assets/Vlad_event_2.png',
                                        width: 90,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              "Владимирский полумарафон «Золотые ворота»",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "31 августа 2025  ·  Участников: 1426",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: AppColors.text,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // 🔹 Пустое пространство снизу
                              const SizedBox(height: 50),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (marker['count'] as int).toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
