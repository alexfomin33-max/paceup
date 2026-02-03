// lib/features/map/screens/clubs/tabs/club_photo_content.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/image_picker_helper.dart';
import '../../../../../core/utils/local_image_compressor.dart'
    show ImageCompressionPreset, compressLocalImage;
import '../../../../../core/utils/error_handler.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';

/// Контент вкладки "Фото" для детальной страницы клуба
/// Работает с API для загрузки, отображения и удаления фотографий
class ClubPhotoContent extends ConsumerStatefulWidget {
  final int clubId;
  final bool canEdit; // Является ли пользователь владельцем клуба
  final Map<String, dynamic>? clubData; // Данные клуба с фотографиями
  final VoidCallback?
  onPhotosUpdated; // Callback для обновления данных после загрузки/удаления

  const ClubPhotoContent({
    super.key,
    required this.clubId,
    required this.canEdit,
    this.clubData,
    this.onPhotosUpdated,
  });

  @override
  ConsumerState<ClubPhotoContent> createState() => _ClubPhotoContentState();
}

class _ClubPhotoContentState extends ConsumerState<ClubPhotoContent> {
  // ───── Список фотографий из API ─────
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void didUpdateWidget(ClubPhotoContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем фото, если изменились данные клуба
    if (oldWidget.clubData != widget.clubData) {
      _loadPhotos();
    }
  }

  /// ──────────────────────── Загрузка фотографий из данных клуба ────────────────────────
  void _loadPhotos() {
    if (widget.clubData == null) return;

    final photosList = widget.clubData!['photos'] as List<dynamic>? ?? [];
    setState(() {
      // Разворачиваем список, чтобы новые фото были в начале
      _photos = photosList
          .map(
            (p) => {
              'id': p['id'] as int? ?? 0,
              'url': p['url'] as String? ?? '',
            },
          )
          .where((p) => p['url'] != null && (p['url'] as String).isNotEmpty)
          .toList()
          .reversed
          .toList();
    });
  }

  /// ──────────────────────── Добавление фото ────────────────────────
  /// Открывает галерею с обрезкой фото в соотношении 1:1 и загружает на сервер
  Future<void> _addPhoto() async {
    if (_isLoading || !widget.canEdit) return;

    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      // Выбираем и обрабатываем изображение
      final processed = await ImagePickerHelper.pickAndProcessImage(
        context: context,
        aspectRatio: 1.0, // Квадратное фото
        maxSide: ImageCompressionPreset.eventPhoto.maxSide,
        jpegQuality: ImageCompressionPreset.eventPhoto.quality,
        cropTitle: 'Обрезка фото',
      );
      if (processed == null || !mounted) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Сжимаем изображение (на случай, если pickAndProcessImage не сжал)
      final compressed = await compressLocalImage(
        sourceFile: processed,
        maxSide: ImageCompressionPreset.eventPhoto.maxSide,
        jpegQuality: ImageCompressionPreset.eventPhoto.quality,
      );

      // Получаем userId для загрузки
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();
      if (userId == null || !mounted) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Необходимо войти в систему'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Загружаем на сервер
      final api = ref.read(apiServiceProvider);
      final response = await api.postMultipart(
        '/upload_club_photo.php',
        files: {'file0': compressed},
        fields: {
          'user_id': userId.toString(),
          'club_id': widget.clubId.toString(),
        },
        timeout: const Duration(minutes: 2),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // Обновляем список фотографий из ответа
        // Разворачиваем список, чтобы новые фото были в начале
        final photosList = response['photos'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _photos = photosList
                .map(
                  (p) => {
                    'id': p['id'] as int? ?? 0,
                    'url': p['url'] as String? ?? '',
                  },
                )
                .where((p) => p['url'] != null && (p['url'] as String).isNotEmpty)
                .toList()
                .reversed
                .toList();
          });
        }

        // Вызываем callback для обновления данных клуба
        widget.onPhotosUpdated?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Фотография загружена'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        final errorMessage =
            response['message'] as String? ?? 'Ошибка загрузки фотографии';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.format(e)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ──────────────────────── Удаление фото ────────────────────────
  Future<void> _deletePhoto(int index) async {
    if (_isDeleting ||
        !widget.canEdit ||
        index < 0 ||
        index >= _photos.length) {
      return;
    }

    final photo = _photos[index];
    final photoId = photo['id'] as int?;
    if (photoId == null || photoId <= 0) return;

    // Показываем диалог подтверждения
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Удалить фотографию?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isDeleting = true);

      // Получаем userId для удаления
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();
      if (userId == null || !mounted) {
        setState(() => _isDeleting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Необходимо войти в систему'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Удаляем на сервере
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/delete_club_photo.php',
        body: {
          'user_id': userId.toString(),
          'club_id': widget.clubId.toString(),
          'photo_id': photoId.toString(),
        },
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // Обновляем список фотографий из ответа
        // Разворачиваем список, чтобы новые фото были в начале
        final photosList = response['photos'] as List<dynamic>? ?? [];
        setState(() {
          _photos = photosList
              .map(
                (p) => {
                  'id': p['id'] as int? ?? 0,
                  'url': p['url'] as String? ?? '',
                },
              )
              .where((p) => p['url'] != null && (p['url'] as String).isNotEmpty)
              .toList()
              .reversed
              .toList();
        });

        // Вызываем callback для обновления данных клуба
        widget.onPhotosUpdated?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Фотография удалена'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        final errorMessage =
            response['message'] as String? ?? 'Ошибка удаления фотографии';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.format(e)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  /// ──────────────────────── Открытие галереи ────────────────────────
  void _openGallery(BuildContext context, int index) {
    // Преобразуем URL в список строк для галереи
    final photoUrls = _photos.map((p) => p['url'] as String).toList();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: AppColors.scrim40,
        pageBuilder: (_, _, _) => _FullscreenGallery(
          initialIndex: index,
          photoUrls: photoUrls,
          clubId: widget.clubId,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ───── Если не владелец и фото нет — показываем пустое состояние ─────
    if (!widget.canEdit && _photos.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 400),
        child: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.photo_on_rectangle,
                    size: 32,
                    color: AppColors.getTextPlaceholderColor(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Фотографий пока нет',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.getTextPlaceholderColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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

          // Минимальная высота: три строки фотографий, но не менее 400
          final calculatedHeight = (3 * cellW) + (2 * spacing);
          final minHeight = calculatedHeight < 400 ? 400.0 : calculatedHeight;

          // Количество элементов:
          // - Для владельца: плейсхолдер + фото
          // - Для остальных: только фото
          final itemCount = (widget.canEdit ? 1 : 0) + _photos.length;

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
                    onTap: _isLoading ? null : _addPhoto,
                    isLoading: _isLoading,
                  );
                }

                // Остальные ячейки — фото
                // Для владельца: смещаем индекс на 1 (пропускаем плейсхолдер)
                // Для остальных: используем индекс как есть
                final photoIndex = widget.canEdit ? i - 1 : i;
                if (photoIndex < 0 || photoIndex >= _photos.length) {
                  return const SizedBox.shrink();
                }
                final photo = _photos[photoIndex];
                final photoUrl = photo['url'] as String? ?? '';

                return _PhotoItem(
                  photoUrl: photoUrl,
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
  final VoidCallback? onTap;
  final bool isLoading;

  const _AddPhotoPlaceholder({
    required this.cellSize,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: AppColors.twinphoto,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CupertinoActivityIndicator(
                    radius: 10,
                    color: AppColors.scrim20,
                  ),
                )
              : const Icon(
                  CupertinoIcons.camera_fill,
                  size: 24,
                  color: AppColors.scrim20,
                ),
        ),
      ),
    );
  }
}

/// ──────────────────────── Элемент фото в сетке ────────────────────────
/// Фото с возможностью удаления для владельца клуба
class _PhotoItem extends StatelessWidget {
  final String photoUrl;
  final int photoIndex;
  final int clubId;
  final double cellSize;
  final int cacheWidth;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoItem({
    required this.photoUrl,
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
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                width: cellSize,
                height: cellSize,
                fit: BoxFit.cover,
                memCacheWidth: cacheWidth,
                errorWidget: (context, url, error) => Builder(
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
                placeholder: (context, url) => Builder(
                  builder: (context) => Container(
                    width: cellSize,
                    height: cellSize,
                    color: AppColors.getBorderColor(context),
                    child: Center(
                      child: CupertinoActivityIndicator(
                        radius: 10,
                        color: AppColors.getIconSecondaryColor(context),
                      ),
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
/// Работает с URL из API
class _FullscreenGallery extends StatefulWidget {
  final int initialIndex;
  final List<String> photoUrls; // URL фотографий
  final int clubId;

  const _FullscreenGallery({
    required this.initialIndex,
    required this.photoUrls,
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
            itemCount: widget.photoUrls.length,
            itemBuilder: (_, i) {
              final photoUrl = widget.photoUrls[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close, // Закрываем по тапу
                child: Center(
                  child: Hero(
                    tag: 'club-photo-${widget.clubId}-$i',
                    child: _ZoomableImage(photoUrl: photoUrl),
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
                    text: '${_index + 1}/${widget.photoUrls.length}',
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
/// Работает с URL из API
class _ZoomableImage extends StatefulWidget {
  final String photoUrl; // URL фотографии

  const _ZoomableImage({required this.photoUrl});

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

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _tc,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: true,
      scaleEnabled: true,
      child: CachedNetworkImage(
        imageUrl: widget.photoUrl,
        fit: BoxFit.contain,
        errorWidget: (context, url, error) => Builder(
          builder: (context) => Container(
            color: AppColors.getBorderColor(context),
            child: Icon(
              Icons.broken_image,
              size: 48,
              color: AppColors.getIconSecondaryColor(context),
            ),
          ),
        ),
        placeholder: (context, url) => Builder(
          builder: (context) => Container(
            color: AppColors.getBorderColor(context),
            child: Center(
              child: CupertinoActivityIndicator(
                radius: 10,
                color: AppColors.getIconSecondaryColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
