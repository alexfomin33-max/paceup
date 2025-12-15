import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../models/main_tab_data.dart';

class GearSectionSliver extends StatelessWidget {
  final String title; // Заголовок секции ("Кроссовки"/"Велосипед")
  final List<GearItem> items; // Список элементов снаряжения
  final bool isBike; // Управляет подписью второй метрики: "Скорость" или "Темп"
  final bool isOwnProfile; // true, если открыт профиль текущего пользователя
  final VoidCallback? onItemTap; // 👈 колбэк на тап по карточке

  const GearSectionSliver({
    super.key,
    required this.title,
    required this.items,
    required this.isBike,
    required this.isOwnProfile,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    // childCount = 2 (заголовок + отступ) + количество карточек
    final childCount = items.length + 2;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // 0: заголовок секции
        if (index == 0) {
          return _SectionTitle(title);
        }
        // 1: отступ после заголовка
        if (index == 1) {
          return const SizedBox(height: 8);
        }

        // Остальные индексы — карточки
        final i = index - 2;
        if (i < 0 || i >= items.length) return const SizedBox.shrink();

        final g = items[i];
        final isLast = i == items.length - 1;

        return Padding(
          // Нижний отступ секции: у велосипедов он чуть больше, как у тебя было
          padding: EdgeInsets.only(bottom: isLast ? (isBike ? 16 : 12) : 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onItemTap, // 👈 дергаем внешний колбэк
            child: _GearCard(
              title: g.title,
              imageUrl: g.imageAsset,
              isBike: isBike,
              isOwnProfile: isOwnProfile,
              stat1Label: 'Пробег:',
              stat1Value: g.mileage,
              stat2Label: isBike ? 'Скорость:' : 'Темп:',
              stat2Value: g.paceOrSpeed,
            ),
          ),
        );
      }, childCount: childCount),
    );
  }
}

/// Локальный заголовок секции
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
          style: AppTextStyles.h15w6.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.getTextPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

// ───────────────────── Адаптивное изображение снаряжения
// Определяет пропорции изображения и выбирает подходящий BoxFit
class _AdaptiveGearImage extends StatefulWidget {
  final String? imageUrl;
  final bool isBike;
  const _AdaptiveGearImage({required this.imageUrl, required this.isBike});

  @override
  State<_AdaptiveGearImage> createState() => _AdaptiveGearImageState();
}

class _AdaptiveGearImageState extends State<_AdaptiveGearImage> {
  BoxFit _fit = BoxFit.contain; // По умолчанию contain для вписывания по длинной стороне
  ImageStreamListener? _listener;
  ImageStream? _imageStream;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl != null &&
        widget.imageUrl!.isNotEmpty &&
        (widget.imageUrl!.startsWith('http://') ||
            widget.imageUrl!.startsWith('https://'))) {
      _determineFit();
    }
  }

  @override
  void didUpdateWidget(_AdaptiveGearImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _cleanupListener();
      if (widget.imageUrl != null &&
          widget.imageUrl!.isNotEmpty &&
          (widget.imageUrl!.startsWith('http://') ||
              widget.imageUrl!.startsWith('https://'))) {
        _determineFit();
      }
    }
  }

  @override
  void dispose() {
    _cleanupListener();
    super.dispose();
  }

  void _cleanupListener() {
    if (_listener != null && _imageStream != null) {
      _imageStream!.removeListener(_listener!);
      _listener = null;
      _imageStream = null;
    }
  }

  void _determineFit() {
    if (widget.imageUrl == null ||
        widget.imageUrl!.isEmpty ||
        (!widget.imageUrl!.startsWith('http://') &&
            !widget.imageUrl!.startsWith('https://'))) {
      return;
    }

    final imageProvider = NetworkImage(widget.imageUrl!);
    _imageStream = imageProvider.resolve(const ImageConfiguration());

    _listener = ImageStreamListener(
      (ImageInfo imageInfo, bool _) {
        final image = imageInfo.image;
        final imageWidth = image.width.toDouble();
        final imageHeight = image.height.toDouble();
        
        // Размеры контейнера
        const containerWidth = 66.0;
        const containerHeight = 44.0;
        
        // Определяем, какая сторона у изображения длиннее
        final imageIsWider = imageWidth > imageHeight;
        // Определяем, какая сторона у контейнера длиннее
        final containerIsWider = containerWidth > containerHeight;
        
        // Если длинная сторона изображения соответствует длинной стороне контейнера,
        // используем fit по длинной стороне
        if (imageIsWider && containerIsWider) {
          // Горизонтальное изображение в горизонтальном контейнере - fit по ширине
          _fit = BoxFit.fitWidth;
        } else if (!imageIsWider && !containerIsWider) {
          // Вертикальное изображение в вертикальном контейнере - fit по высоте
          _fit = BoxFit.fitHeight;
        } else {
          // Разная ориентация - используем contain для полного вписывания
          _fit = BoxFit.contain;
        }

        if (mounted) {
          setState(() {});
        }
        _cleanupListener();
      },
      onError: (exception, stackTrace) {
        // При ошибке используем contain по умолчанию
        if (mounted) {
          setState(() {
            _fit = BoxFit.contain;
          });
        }
        _cleanupListener();
      },
    );

    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final defaultImage = widget.isBike
        ? 'assets/add_bike.png'
        : 'assets/add_boots.png';

    if (widget.imageUrl != null &&
        widget.imageUrl!.isNotEmpty &&
        (widget.imageUrl!.startsWith('http://') ||
            widget.imageUrl!.startsWith('https://'))) {
      // Изображение вписывается по длинной стороне с сохранением пропорций
      final imageWidget = SizedBox(
        width: 66,
        height: 44,
        child: Image.network(
          widget.imageUrl!,
          fit: _fit,
          errorBuilder: (context, error, stackTrace) {
            final image = Image.asset(
              defaultImage,
              width: 66,
              height: 44,
              fit: BoxFit.contain,
            );
            return widget.isBike
                ? image
                : Opacity(opacity: 0.9, child: image);
          },
        ),
      );

      return imageWidget;
    }

    // Дефолтное изображение
    final image = Image.asset(
      defaultImage,
      width: 66,
      height: 44,
      fit: BoxFit.contain,
    );
    return widget.isBike ? image : Opacity(opacity: 0.9, child: image);
  }
}

/// Карточка снаряжения: картинка + заголовок + две краткие метрики
class _GearCard extends StatelessWidget {
  final String title;
  final String imageUrl; // URL изображения из базы данных (может быть пустым)
  final bool
  isBike; // Флаг для определения типа снаряжения (кроссовки/велосипед)
  final bool isOwnProfile; // true, если открыт профиль текущего пользователя
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;

  const _GearCard({
    required this.title,
    required this.imageUrl,
    required this.isBike,
    required this.isOwnProfile,
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
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkShadowSoft
                  : AppColors.shadowSoft,
              offset: const Offset(0, 1),
              blurRadius: 1,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Row(
          children: [
            // Превью изображения (из базы данных или дефолтное)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: _AdaptiveGearImage(
                imageUrl:
                    imageUrl.isNotEmpty &&
                        (imageUrl.startsWith('http://') ||
                            imageUrl.startsWith('https://'))
                    ? imageUrl
                    : null,
                isBike: isBike,
              ),
            ),
            const SizedBox(width: 12),
            // Текстовая часть с заголовком и метриками
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок карточки + "карандаш" справа (только для своего профиля)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h14w5.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ),
                      if (isOwnProfile) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurfaceMuted
                                : AppColors.skeletonBase,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          child: Icon(
                            CupertinoIcons.pencil,
                            size: 12,
                            color: AppColors.getIconPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Две метрики в одну строку
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

/// Небольшой текстовый компонент "метка + значение"
class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  const _InlineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Разделяем значение на числовую часть и единицы измерения
    // Паттерны: "582 км", "4:18 /км", "35,7 км/ч"
    String numberPart = value;
    String unitPart = '';

    // Проверяем наличие единиц измерения в конце строки
    if (value.endsWith(' км')) {
      numberPart = value.substring(0, value.length - 3);
      unitPart = ' км';
    } else if (value.endsWith(' /км')) {
      numberPart = value.substring(0, value.length - 4);
      unitPart = ' /км';
    } else if (value.endsWith(' км/ч')) {
      numberPart = value.substring(0, value.length - 5);
      unitPart = ' км/ч';
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          TextSpan(
            text: numberPart,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          if (unitPart.isNotEmpty)
            TextSpan(
              text: unitPart,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
