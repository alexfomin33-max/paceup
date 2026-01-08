// lib/features/lenta/screens/widgets/activity/actions/share_image_selector_dialog.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Тип изображения для репоста
enum ShareImageType {
  map, // Карта с треком
  photo, // Фото из активности
}

/// Результат выбора изображения для репоста
class ShareImageSelection {
  final ShareImageType type;
  final String? photoUrl; // URL выбранного фото (если type == photo)

  const ShareImageSelection({
    required this.type,
    this.photoUrl,
  });
}

/// Диалог выбора типа изображения для репоста активности
class ShareImageSelectorDialog extends StatelessWidget {
  final List<String> photoUrls;
  final bool hasMap;

  const ShareImageSelectorDialog({
    super.key,
    required this.photoUrls,
    required this.hasMap,
  });

  static Future<ShareImageSelection?> show({
    required BuildContext context,
    required List<String> photoUrls,
    required bool hasMap,
  }) async {
    return showCupertinoModalPopup<ShareImageSelection>(
      context: context,
      builder: (context) => ShareImageSelectorDialog(
        photoUrls: photoUrls,
        hasMap: hasMap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = <_ShareOption>[];

    // Добавляем опцию карты, если есть маршрут
    if (hasMap) {
      options.add(_ShareOption(
        type: ShareImageType.map,
        title: 'Карта с треком',
        icon: CupertinoIcons.map,
      ));
    }

    // Добавляем опции для каждого фото
    for (final photoUrl in photoUrls) {
      options.add(_ShareOption(
        type: ShareImageType.photo,
        title: photoUrls.length > 1 
            ? 'Фото ${photoUrls.indexOf(photoUrl) + 1}'
            : 'Фото',
        icon: CupertinoIcons.photo,
        photoUrl: photoUrl,
      ));
    }

    return CupertinoActionSheet(
      title: const Text(
        'Выберите изображение для репоста',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      actions: options.map((option) {
        return CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop(ShareImageSelection(
              type: option.type,
              photoUrl: option.photoUrl,
            ));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(option.icon, size: 20),
              const SizedBox(width: 8),
              Text(option.title),
            ],
          ),
        );
      }).toList(),
      cancelButton: CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('Отмена'),
      ),
    );
  }
}

class _ShareOption {
  final ShareImageType type;
  final String title;
  final IconData icon;
  final String? photoUrl;

  _ShareOption({
    required this.type,
    required this.title,
    required this.icon,
    this.photoUrl,
  });
}

