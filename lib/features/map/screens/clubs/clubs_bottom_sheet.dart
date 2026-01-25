import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/transparent_route.dart';
import 'club_detail_screen.dart';

/// Каркас bottom sheet для вкладки «Клубы» — 1:1 как в events_bottom_sheet.dart
class ClubsBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFraction;

  const ClubsBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.maxHeightFraction = 0.5, // не выше 50% экрана
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top; // Высота верхней брови (notch)
    final bottomPadding =
        mediaQuery.padding.bottom; // Высота нижней безопасной зоны
    // Максимальная высота: от низа экрана до верхней брови
    // Вычитаем небольшой отступ снизу для визуального комфорта
    final maxH =
        screenHeight - topPadding - (bottomPadding > 0 ? bottomPadding : 16);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getBackgroundColor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Вычисляем доступную высоту для контента
            // Вычитаем высоту ручки (4 + 10), заголовка (~40), отступов (12 + 10 + 12)
            final availableHeight = maxH - 88;
            final contentMaxHeight = availableHeight > 0
                ? availableHeight
                : 100.0;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // «ручка»
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10, top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.getBorderColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),

                  // заголовок
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        title,
                        style: AppTextStyles.h17w6.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // контент — динамическая высота: занимает только необходимое место
                  // до максимальной высоты, после чего включается скролл
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: contentMaxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: child,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Заглушка (если контента нет)
class ClubsSheetPlaceholder extends StatelessWidget {
  const ClubsSheetPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Text(
        'Здесь будет контент…',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.getTextSecondaryColor(context),
        ),
      ),
    );
  }
}

/// Простой текст в шите «Клубы» (аналог EventsSheetText)
class ClubsSheetText extends StatelessWidget {
  final String text;
  const ClubsSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.getTextPrimaryColor(context),
      ),
    );
  }
}

/// Список клубов из API (для отображения в bottom sheet)
class ClubsListFromApi extends StatefulWidget {
  final List<dynamic> clubs;
  final double? latitude;
  final double? longitude;

  const ClubsListFromApi({
    super.key,
    required this.clubs,
    this.latitude,
    this.longitude,
  });

  @override
  State<ClubsListFromApi> createState() => _ClubsListFromApiState();
}

class _ClubsListFromApiState extends State<ClubsListFromApi> {
  late List<dynamic> _clubs;

  @override
  void initState() {
    super.initState();
    // ── Создаем копию списка для локального обновления
    _clubs = List.from(widget.clubs);
  }

  @override
  void didUpdateWidget(ClubsListFromApi oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ── Обновляем список, если изменился исходный список
    if (oldWidget.clubs != widget.clubs) {
      _clubs = List.from(widget.clubs);
    }
  }

  /// ──────────────────────── Обновление количества участников ────────────────────────
  void _updateMembersCount(int clubId, int newCount) {
    setState(() {
      for (var i = 0; i < _clubs.length; i++) {
        final club = _clubs[i] as Map<String, dynamic>;
        final id = club['id'] as int?;
        if (id != null && id == clubId) {
          final updatedClub = Map<String, dynamic>.from(club);
          updatedClub['members_count'] = newCount;
          _clubs[i] = updatedClub;
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_clubs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Text(
          'Клубы не найдены',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      );
    }

    // ───────────────────── Лёгкий префетч логотипов (топ-8) ─────────────────────
    // Выполняется при первом построении: подогреваем кэш под целевые размеры
    // для ускорения первого кадра и плавного скролла.
    () {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final targetW = (100 * dpr).round();
      final int limit = _clubs.length < 8 ? _clubs.length : 8;
      for (var i = 0; i < limit; i++) {
        final c = _clubs[i] as Map<String, dynamic>;
        final logoUrl = c['logo_url'] as String?;
        if (logoUrl != null && logoUrl.isNotEmpty) {
          // precacheImage не блокирует UI; повторные вызовы недороги благодаря кэшу
          precacheImage(
            CachedNetworkImageProvider(
              logoUrl,
              maxWidth: targetW,
              maxHeight: targetW,
            ),
            context,
          );
        }
      }
    }();

    // ───────────────────── Карточка клуба ─────────────────────
    Widget clubCard({
      required String? logoUrl,
      required String title,
      required int membersCount,
      required String? city,
      VoidCallback? onTap,
    }) {
      // ── определяем цвет тени в зависимости от темы
      final brightness = Theme.of(context).brightness;
      final shadowColor = brightness == Brightness.dark
          ? AppColors.darkShadowSoft
          : AppColors.shadowSoft;

      final card = Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.twinchip,
            width: 0.7,
          ),
          // boxShadow: [
          //   BoxShadow(
          //     color: shadowColor,
          //     offset: const Offset(0, 1),
          //     blurRadius: 1,
          //     spreadRadius: 0,
          //   ),
          // ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Логотип клуба (круглый)
            Container(
              height: 100,
              width: 100,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(child: _ClubLogoImage(logoUrl: logoUrl)),
            ),
            const SizedBox(height: 8),

            // Название клуба с обрезанием текста
            Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Количество участников и город
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.person_2,
                    size: 15,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatMembers(membersCount),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.2,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  if (city != null && city.isNotEmpty) ...[
                    Flexible(
                      child: Text(
                        '  ·  $city',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.2,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

      if (onTap == null) return card;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }

    // ─────────────────────────── Сетка карточек 2xN ───────────────────────────
    // Используем shrinkWrap для динамической высоты bottom sheet
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 174,
      ),
      itemCount: _clubs.length,
      itemBuilder: (context, index) {
        final club = _clubs[index] as Map<String, dynamic>;
        final clubId = club['id'] as int?;
        final name = club['name'] as String? ?? '';
        final logoUrl = club['logo_url'] as String?;
        final membersCount = club['members_count'] as int? ?? 0;
        final city = club['city'] as String?;

        return clubCard(
          logoUrl: logoUrl,
          title: name,
          membersCount: membersCount,
          city: city,
          onTap: clubId != null
              ? () async {
                  final result = await Navigator.of(context).push<dynamic>(
                    TransparentPageRoute(
                      builder: (_) => ClubDetailScreen(clubId: clubId),
                    ),
                  );
                  // ── если количество участников было обновлено, обновляем локально
                  if (result is Map<String, dynamic> &&
                      result['members_count_updated'] == true &&
                      context.mounted) {
                    final updatedCount = result['members_count'] as int? ?? 0;
                    final updatedClubId = result['club_id'] as int?;
                    if (updatedClubId != null) {
                      _updateMembersCount(updatedClubId, updatedCount);
                    }
                  }
                  // ── если клуб был удалён, закрываем bottom sheet с результатом
                  if (result == 'deleted' && context.mounted) {
                    Navigator.of(context).pop('club_deleted');
                  }
                }
              : null,
        );
      },
    );
  }
}

/// Виджет для отображения логотипа клуба
///
/// Использует CachedNetworkImage для загрузки изображения из API
/// Показывает placeholder при отсутствии логотипа или ошибке загрузки
class _ClubLogoImage extends StatelessWidget {
  final String? logoUrl;
  const _ClubLogoImage({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    // Если логотип не указан, показываем placeholder
    if (logoUrl == null || logoUrl!.isEmpty) {
      return Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.group,
          size: 40,
          color: AppColors.textSecondary,
        ),
      );
    }

    // Загружаем логотип из сети с кэшированием
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetW = (100 * dpr).round();

    return CachedNetworkImage(
      imageUrl: logoUrl!,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      memCacheWidth: targetW,
      maxWidthDiskCache: targetW,
      errorWidget: (context, imageUrl, error) => Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.photo,
          size: 24,
          color: AppColors.textSecondary,
        ),
      ),
      placeholder: (context, imageUrl) => Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const CupertinoActivityIndicator(radius: 10),
      ),
    );
  }
}

// Формат "58 234"
String _formatMembers(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    buf.write(s[i]);
    if (rev > 1 && rev % 3 == 1) {
      buf.write('\u202F'); // узкий неразрывный пробел
    }
  }
  return buf.toString();
}
