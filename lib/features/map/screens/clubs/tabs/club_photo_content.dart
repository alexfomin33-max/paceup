// lib/features/map/screens/clubs/tabs/club_photo_content.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/image_picker_helper.dart';
import '../../../../../core/utils/local_image_compressor.dart'
    show ImageCompressionPreset;

/// Контент вкладки "Фото" для детальной страницы клуба
/// Пока без API функционала — структура готова для будущей интеграции
class ClubPhotoContent extends StatefulWidget {
  final int clubId;
  final bool canEdit; // Является ли пользователь владельцем клуба

  const ClubPhotoContent({
    super.key,
    required this.clubId,
    required this.canEdit,
  });

  @override
  State<ClubPhotoContent> createState() => _ClubPhotoContentState();
}

class _ClubPhotoContentState extends State<ClubPhotoContent> {
  // ───── Локальное хранилище выбранных фото (пока без API) ─────
  // TODO: Заменить на загрузку фото через API по clubId
  final List<File> _localPhotos = [];

  /// ──────────────────────── Добавление фото ────────────────────────
  /// Открывает галерею с обрезкой фото в соотношении 1:1
  Future<void> _addPhoto() async {
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: 1.0, // Квадратное фото, как логотип
      maxSide: ImageCompressionPreset.eventPhoto.maxSide,
      jpegQuality: ImageCompressionPreset.eventPhoto.quality,
      cropTitle: 'Обрезка фото',
    );
    if (processed == null || !mounted) return;

    setState(() {
      _localPhotos.add(processed);
    });
  }

  /// ──────────────────────── Удаление фото ────────────────────────
  void _deletePhoto(int index) {
    setState(() {
      _localPhotos.removeAt(index);
    });
  }

  /// ──────────────────────── Открытие галереи ────────────────────────
  void _openGallery(BuildContext context, int index) {
    // Преобразуем File в String (путь) для галереи
    final photoPaths = _localPhotos.map((f) => f.path).toList();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: AppColors.scrim40,
        pageBuilder: (_, __, ___) => _FullscreenGallery(
          initialIndex: index,
          photoPaths: photoPaths,
          clubId: widget.clubId,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ───── Если не владелец и фото нет — показываем пустое состояние ─────
    if (!widget.canEdit && _localPhotos.isEmpty) {
      return Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.photo_on_rectangle,
                  size: 64,
                  color: AppColors.getIconSecondaryColor(context),
                ),
                const SizedBox(height: 16),
                Text(
                  'Фотографий пока нет',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: AppColors.getTextSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ───── Показываем сетку: для владельца — с плейсхолдером, для остальных — без ─────
    return ClipRRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 3;
          const spacing = 2.0;
          final cellW =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          final dpr = MediaQuery.of(context).devicePixelRatio;
          final cacheWidth = (cellW * dpr).round();

          // Минимальная высота: три строки фотографий
          // 3 ячейки по высоте cellW + 2 промежутка между строками
          final minHeight = (3 * cellW) + (2 * spacing);

          // Количество элементов:
          // - Для владельца: плейсхолдер + фото
          // - Для остальных: только фото
          final itemCount = (widget.canEdit ? 1 : 0) + _localPhotos.length;

          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: GridView.builder(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: itemCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (_, i) {
                // Для владельца: первая ячейка (index 0) — плейсхолдер для добавления фото
                if (widget.canEdit && i == 0) {
                  return _AddPhotoPlaceholder(
                    cellSize: cellW,
                    onTap: _addPhoto,
                  );
                }

                // Остальные ячейки — фото
                // Для владельца: смещаем индекс на 1 (пропускаем плейсхолдер)
                // Для остальных: используем индекс как есть
                final photoIndex = widget.canEdit ? i - 1 : i;
                final photoFile = _localPhotos[photoIndex];

                return _PhotoItem(
                  photoFile: photoFile,
                  photoIndex: photoIndex,
                  clubId: widget.clubId,
                  cellSize: cellW,
                  cacheWidth: cacheWidth,
                  canEdit: widget.canEdit,
                  onTap: () => _openGallery(context, photoIndex),
                  onDelete: () => _deletePhoto(photoIndex),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// ──────────────────────── Плейсхолдер для добавления фото ────────────────────────
/// Квадратный плейсхолдер с иконкой добавления фото
class _AddPhotoPlaceholder extends StatelessWidget {
  final double cellSize;
  final VoidCallback onTap;

  const _AddPhotoPlaceholder({required this.cellSize, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Builder(
        builder: (context) => Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppColors.getSurfaceColor(context),
            border: Border.all(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.photo_camera,
              size: 32,
              color: AppColors.getIconSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// ──────────────────────── Элемент фото в сетке ────────────────────────
/// Фото с возможностью удаления для владельца клуба
class _PhotoItem extends StatelessWidget {
  final File photoFile;
  final int photoIndex;
  final int clubId;
  final double cellSize;
  final int cacheWidth;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoItem({
    required this.photoFile,
    required this.photoIndex,
    required this.clubId,
    required this.cellSize,
    required this.cacheWidth,
    required this.canEdit,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Hero(
            tag: 'club-photo-$clubId-$photoIndex',
            flightShuttleBuilder:
                (
                  BuildContext flightContext,
                  Animation<double> animation,
                  HeroFlightDirection flightDirection,
                  BuildContext fromHeroContext,
                  BuildContext toHeroContext,
                ) {
                  final Hero toHero = toHeroContext.widget as Hero;
                  return toHero.child;
                },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.file(
                photoFile,
                fit: BoxFit.cover,
                width: cellSize,
                height: cellSize,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) => Builder(
                  builder: (context) => Container(
                    width: cellSize,
                    height: cellSize,
                    color: AppColors.getBorderColor(context),
                    child: Icon(
                      Icons.broken_image,
                      size: 24,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Иконка удаления (только для владельца)
        if (canEdit)
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Builder(
                builder: (context) => Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1),
                  ),
                  child: const Icon(
                    CupertinoIcons.clear,
                    size: 16,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ──────────────────────── Полноэкранная галерея ────────────────────────
/// Полноэкранная галерея с перелистыванием, Hero-анимацией и зумом
/// Работает с локальными файлами (File.path) и URL (для будущего API)
class _FullscreenGallery extends StatefulWidget {
  final int initialIndex;
  final List<String> photoPaths; // Пути к фото (локальные или URL)
  final int clubId;

  const _FullscreenGallery({
    required this.initialIndex,
    required this.photoPaths,
    required this.clubId,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  void _close() => Navigator.of(context).maybePop();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scrim90,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: widget.photoPaths.length,
            itemBuilder: (_, i) {
              final photoPath = widget.photoPaths[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close, // Закрываем по тапу
                child: Center(
                  child: Hero(
                    tag: 'club-photo-${widget.clubId}-$i',
                    child: _ZoomableImage(photoPath: photoPath),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  _CircleIconButton(icon: Icons.close, onTap: _close),
                  const Spacer(),
                  _CounterBadge(
                    text: '${_index + 1}/${widget.photoPaths.length}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ──────────────────────── Кнопка в кружке ────────────────────────
/// Полупрозрачная круглая кнопка на чёрном фоне
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(icon, size: 20, color: AppColors.surface),
      ),
    );
  }
}

/// ──────────────────────── Бейдж-счётчик ────────────────────────
/// Небольшой бейдж-счётчик вверху экрана
class _CounterBadge extends StatelessWidget {
  final String text;

  const _CounterBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.surface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// ──────────────────────── Картинка с зумом ────────────────────────
/// Картинка с pinch-to-zoom и перетаскиванием
/// Поддерживает как локальные файлы, так и URL (для будущего API)
class _ZoomableImage extends StatefulWidget {
  final String photoPath; // Путь к фото (локальный File.path или URL)

  const _ZoomableImage({required this.photoPath});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  /// Определяет, является ли путь локальным файлом или URL
  bool get _isLocalFile => !widget.photoPath.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _tc,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: true,
      scaleEnabled: true,
      child: _isLocalFile
          ? Image.file(
              File(widget.photoPath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Builder(
                builder: (context) => Container(
                  color: AppColors.getBorderColor(context),
                  child: Icon(
                    Icons.broken_image,
                    size: 48,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              ),
            )
          : Image.network(
              widget.photoPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Builder(
                builder: (context) => Container(
                  color: AppColors.getBorderColor(context),
                  child: Icon(
                    Icons.broken_image,
                    size: 48,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              ),
            ),
    );
  }
}
