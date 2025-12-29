// lib/screens/map/clubs/club_popup.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/transparent_route.dart';
import 'club_detail_screen.dart';

/// Попап клуба, показываемый при клике на маркер с count == 1.
/// Поведение и размеры совпадают с equipment_popup.dart:
/// - 260×56 (минимальная высота), динамическая высота до 284px (максимум 5 элементов)
/// - Появление с анимацией Fade + Scale(0.8→1.0, easeOutBack ~250мс)
/// - Позиция: центр экрана с небольшим смещением вверх
/// - Горизонталь: по центру экрана
class ClubPopup {
  /// Показать попап с информацией о клубе.
  /// [club] - данные клуба из API
  /// [screenX] - координата X на экране (опционально, для якорения)
  /// [screenY] - координата Y на экране (опционально, для якорения)
  static void show(
    BuildContext context, {
    required Map<String, dynamic> club,
    double? screenX,
    double? screenY,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final screenSize = MediaQuery.of(context).size;

    const double popupW = 220;
    const double minHeight = 56.0;
    const double markerHeight = 36.0; // примерная высота кастомного маркера
    const double minMargin = 20.0; // минимальные отступы от краев экрана
    const double verticalOffset = 12.0; // зазор между маркером и попапом

    // Горизонталь: центрируем попап относительно маркера или экрана
    double left;
    if (screenX != null) {
      left = screenX - popupW / 2;
      left = left.clamp(8.0, screenSize.width - popupW - 8.0);
    } else {
      left = (screenSize.width - popupW) / 2;
    }

    // Вертикаль: стараемся показать попап над маркером, при нехватке места — под ним
    double initialTop;
    if (screenY != null) {
      final double markerTop = screenY - markerHeight / 2;
      final double markerBottom = screenY + markerHeight / 2;
      final double preferredTop = markerTop - minHeight - verticalOffset;

      if (preferredTop >= minMargin) {
        initialTop = preferredTop;
      } else {
        initialTop = markerBottom + verticalOffset;
      }

      initialTop = initialTop.clamp(
        minMargin,
        screenSize.height - minHeight - minMargin,
      );
    } else {
      initialTop = (screenSize.height / 2 - minHeight / 2).clamp(
        minMargin,
        screenSize.height - minHeight - minMargin,
      );
    }

    late OverlayEntry entry;

    void close() {
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _AnimatedClubPopup(
        left: left,
        initialTop: initialTop,
        width: popupW,
        onDismiss: close,
        club: club,
      ),
    );

    overlay.insert(entry);
  }
}

class _AnimatedClubPopup extends StatefulWidget {
  final double left;
  final double initialTop;
  final double width;
  final VoidCallback onDismiss;
  final Map<String, dynamic> club;

  const _AnimatedClubPopup({
    required this.left,
    required this.initialTop,
    required this.width,
    required this.onDismiss,
    required this.club,
  });

  @override
  State<_AnimatedClubPopup> createState() => _AnimatedClubPopupState();
}

class _AnimatedClubPopupState extends State<_AnimatedClubPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Тап по полупрозрачному фону — закрыть
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: FadeTransition(
              opacity: _fade.drive(Tween(begin: 0.0, end: 1.0)),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Попап с контентом
        Positioned(
          left: widget.left,
          top: widget.initialTop,
          width: widget.width,
          child: GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.deferToChild,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Material(
                  color: Colors.transparent,
                  child: IntrinsicHeight(
                    child: Container(
                      width: widget.width,
                      constraints: const BoxConstraints(
                        minHeight: 56.0,
                        maxHeight: 284.0,
                      ),
                      decoration: BoxDecoration(
                        // ────────────────────────────────────────────────────────────────
                        // 🌓 ТЕМНАЯ ТЕМА: фон попапа такой же, как у плашки экипировки
                        // ────────────────────────────────────────────────────────────────
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSurfaceMuted
                            : AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: [
                          BoxShadow(
                            // ────────────────────────────────────────────────────────────────
                            // 🌓 ТЕМНАЯ ТЕМА: адаптивная тень
                            // ────────────────────────────────────────────────────────────────
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkShadowSoft
                                : AppColors.textTertiary,
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _ClubPopupContent(
                        club: widget.club,
                        onDismiss: widget.onDismiss,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Контент попапа: карточка клуба
class _ClubPopupContent extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onDismiss;

  const _ClubPopupContent({required this.club, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final clubId = club['id'] as int?;
    final name = club['name'] as String? ?? '';
    final logoUrl = club['logo_url'] as String?;
    final membersCount = club['members_count'] as int? ?? 0;

    return _ClubRow(
      imageUrl: logoUrl,
      name: name,
      membersCount: membersCount,
      onTap: clubId != null
          ? () async {
              onDismiss(); // закрываем попап
              if (context.mounted) {
                await Navigator.of(context).push(
                  TransparentPageRoute(
                    builder: (_) => ClubDetailScreen(clubId: clubId),
                  ),
                );
              }
            }
          : null,
    );
  }
}

/// Одна строка 56px: слева 80px под картинку, справа — текстовый блок.
class _ClubRow extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final int membersCount;
  final VoidCallback? onTap;

  const _ClubRow({
    required this.imageUrl,
    required this.name,
    required this.membersCount,
    this.onTap,
  });

  Widget _buildRowContent(BuildContext context) {
    return Row(
      children: [
        // Слева 56×56 - квадратный контейнер для изображения из БД или заглушки
        Container(
          width: 56,
          height: 56,
          // ────────────────────────────────────────────────────────────────
          // 🌓 ТЕМНАЯ ТЕМА: фон контейнера такой же, как у попапа (darkSurfaceMuted)
          // ────────────────────────────────────────────────────────────────
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceMuted
              : AppColors.getSurfaceColor(context),
          padding: const EdgeInsets.all(8),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Builder(
                  builder: (context) {
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final w = (40 * dpr)
                        .round(); // 56 - 8*2 = 40px для изображения
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.contain,
                        memCacheWidth: w,
                        maxWidthDiskCache: w,
                        placeholder: (context, url) => Container(
                          // ────────────────────────────────────────────────────────────────
                          // 🌓 ТЕМНАЯ ТЕМА: адаптивный фон placeholder
                          // ────────────────────────────────────────────────────────────────
                          color: AppColors.getBackgroundColor(context),
                          child: Center(
                            child: CupertinoActivityIndicator(
                              radius: 10,
                              // ────────────────────────────────────────────────────────────────
                              // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет индикатора загрузки
                              // ────────────────────────────────────────────────────────────────
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.brandPrimary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          // ────────────────────────────────────────────────────────────────
                          // 🌓 ТЕМНАЯ ТЕМА: адаптивный фон и цвет иконки ошибки
                          // ────────────────────────────────────────────────────────────────
                          color: AppColors.getBackgroundColor(context),
                          child: Icon(
                            Icons.group,
                            size: 32,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    // ────────────────────────────────────────────────────────────────
                    // 🌓 ТЕМНАЯ ТЕМА: адаптивный фон и цвет иконки заглушки
                    // ────────────────────────────────────────────────────────────────
                    color: AppColors.getBackgroundColor(context),
                    child: Icon(
                      Icons.group,
                      size: 32,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                ),
        ),
        // Справа - текстовый блок
        Expanded(
          child: Container(
            height: 56,
            // ────────────────────────────────────────────────────────────────
            // 🌓 ТЕМНАЯ ТЕМА: фон текстового блока такой же, как у попапа (darkSurfaceMuted)
            // ────────────────────────────────────────────────────────────────
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceMuted
                : AppColors.getSurfaceColor(context),
            padding: const EdgeInsets.only(left: 3, top: 8, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ────────────────────────────────────────────────────────────────
                // Название клуба в одну строку с ellipsis
                // ────────────────────────────────────────────────────────────────
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.7,
                    // ────────────────────────────────────────────────────────────────
                    // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет основного текста
                    // ────────────────────────────────────────────────────────────────
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // ────────────────────────────────────────────────────────────────
                // Вторая строка: "Участников: X"
                // ────────────────────────────────────────────────────────────────
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Участников: ",
                        style: AppTextStyles.h11w4Sec.copyWith(
                          // ────────────────────────────────────────────────────────────────
                          // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет вторичного текста
                          // ────────────────────────────────────────────────────────────────
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                      TextSpan(
                        text: "$membersCount",
                        style: AppTextStyles.h12w5.copyWith(
                          // ────────────────────────────────────────────────────────────────
                          // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет основного текста
                          // ────────────────────────────────────────────────────────────────
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowContent = SizedBox(
      height: 56,
      width: double.infinity,
      child: _buildRowContent(context),
    );

    if (onTap == null) {
      return rowContent;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: rowContent,
    );
  }
}
