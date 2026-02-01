// lib/features/lenta/screens/widgets/activity/actions/share_image_selector_dialog.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../domain/models/activity_lenta.dart' as al;
import 'package:latlong2/latlong.dart';
import '../../../../../../core/utils/static_map_url_builder.dart';

/// Тип изображения для репоста
enum ShareImageType {
  map, // Карта с треком 
  photo, // Фото из активности
}

/// Результат выбора изображения для репоста
class ShareImageSelection {
  final ShareImageType type;
  final String? photoUrl; // URL выбранного фото (если type == photo)
  final String? mapImageUrl; // URL изображения карты (если type == map)

  const ShareImageSelection({
    required this.type,
    this.photoUrl,
    this.mapImageUrl,
  });
}

/// Диалог выбора типа изображения для репоста активности со слайдером
class ShareImageSelectorDialog extends StatefulWidget {
  final List<String> photoUrls;
  final bool hasMap;
  final al.Activity? activity; // Для генерации карты

  const ShareImageSelectorDialog({
    super.key,
    required this.photoUrls,
    required this.hasMap,
    this.activity,
  });

  static Future<ShareImageSelection?> show({
    required BuildContext context,
    required List<String> photoUrls,
    required bool hasMap,
    al.Activity? activity,
  }) async {
    return showCupertinoModalPopup<ShareImageSelection>(
      context: context,
      builder: (context) => ShareImageSelectorDialog(
        photoUrls: photoUrls,
        hasMap: hasMap,
        activity: activity,
      ),
    );
  }

  @override
  State<ShareImageSelectorDialog> createState() =>
      _ShareImageSelectorDialogState();
}

class _ShareImageSelectorDialogState extends State<ShareImageSelectorDialog> {
  late PageController _pageController;
  int _currentIndex = 0;
  late List<_ShareOption> _items;
  String? _currentMapUrl; // Сохраняем URL текущей карты

  @override
  void initState() {
    super.initState();

    // Формируем список элементов: карта (если есть) + все фото
    _items = [];
    if (widget.hasMap && widget.activity != null) {
      _items.add(
        _ShareOption(type: ShareImageType.map, title: 'Карта', photoUrl: null),
      );
    }
    for (final photoUrl in widget.photoUrls) {
      _items.add(
        _ShareOption(
          type: ShareImageType.photo,
          title: 'Фото ${widget.photoUrls.indexOf(photoUrl) + 1}',
          photoUrl: photoUrl,
        ),
      );
    }

    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Заголовок с кнопками
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.getBorderColor(context),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Поделиться тренировкой',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    decoration: TextDecoration.none,
                  ),
                ),
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () {
                        if (!mounted) return;
                        if (!Navigator.of(context).canPop()) return;
                        final currentItem = _items[_currentIndex];
                        Navigator.of(context).pop(
                          ShareImageSelection(
                            type: currentItem.type,
                            photoUrl: currentItem.photoUrl,
                            mapImageUrl: currentItem.type == ShareImageType.map
                                ? _currentMapUrl
                                : null,
                          ),
                        );
                      },
                      child: const Text(
                        'Выбрать',
                        style: TextStyle(
                          color: CupertinoColors.activeBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () {
                        if (!mounted) return;
                        if (!Navigator.of(context).canPop()) return;
                        Navigator.of(context).pop();
                      },
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 20,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Слайдер с изображениями
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return _buildSlide(item);
              },
            ),
          ),

          // Индикаторы точек
          if (_items.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? CupertinoColors.activeBlue
                            : CupertinoColors.systemGrey3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(_ShareOption item) {
    if (item.type == ShareImageType.map && widget.activity != null) {
      // Показываем карту
      final points = widget.activity!.points
          .map((c) => LatLng(c.lat, c.lng))
          .toList();

      if (points.isEmpty) {
        return const Center(child: Text('Карта недоступна'));
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.of(context).devicePixelRatio;
          final widthPx = (constraints.maxWidth * dpr).round();
          final heightPx = (constraints.maxHeight * dpr).round();

          final mapUrl = StaticMapUrlBuilder.fromPoints(
            points: points,
            widthPx: widthPx.toDouble(),
            heightPx: heightPx.toDouble(),
            strokeWidth: 3.0,
            padding: 12.0,
          );

          // Сохраняем URL карты для использования при репосте
          if (_currentMapUrl != mapUrl) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentMapUrl = mapUrl;
                });
              }
            });
          }

          return CachedNetworkImage(
            imageUrl: mapUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              color: AppColors.getSurfaceColor(context),
              child: const Center(child: CupertinoActivityIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.getSurfaceColor(context),
              child: const Center(
                child: Icon(
                  CupertinoIcons.map,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Показываем фото
      return CachedNetworkImage(
        imageUrl: item.photoUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: AppColors.disabled,
          child: const Center(child: CupertinoActivityIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.disabled,
          child: const Center(
            child: Icon(
              CupertinoIcons.photo,
              size: 48,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      );
    }
  }
}

class _ShareOption {
  final ShareImageType type;
  final String title;
  final String? photoUrl;

  _ShareOption({required this.type, required this.title, this.photoUrl});
}
