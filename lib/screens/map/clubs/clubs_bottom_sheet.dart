import 'package:flutter/material.dart';
import 'package:paceup/theme/app_theme.dart';
import 'coffeerun_vld/coffeerun_vld_screen.dart';

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
    final h = MediaQuery.of(context).size.height;
    final maxH = h * maxHeightFraction;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.large),
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // «ручка»
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10, top: 6),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // заголовок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(title, style: AppTextStyles.h1)),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 6),

              // контент
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: child,
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
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
    return const Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Text(
        'Здесь будет контент…',
        style: TextStyle(fontSize: 14, color: AppColors.text),
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
      style: const TextStyle(fontSize: 14, color: AppColors.text),
    );
  }
}

/// ===== Контент: «Клубы Владимира» =====
/// Картинки:
///  - assets/coffeerun.png
///  - assets/club_5.png
///  - assets/club_6.png
class ClubsListVladimir extends StatelessWidget {
  const ClubsListVladimir({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // нижний отступ как в events
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
      child: Column(
        children: [
          _ClubRow(
            asset: 'assets/coffeerun.png',
            name: 'CoffeeRun_vld',
            city: 'Владимир',
            members: 400,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CoffeeRunVldScreen()),
              );
            },
          ),
          _ClubsDivider(),
          _ClubRow(
            asset: 'assets/club_5.png',
            name: 'Велоклуб "Владимир"',
            city: 'Владимир',
            members: 2508,
          ),
          _ClubsDivider(),
          _ClubRow(
            asset: 'assets/club_6.png',
            name: 'I Love Running Владимир',
            city: 'Владимир',
            members: 708,
          ),
          _ClubsDivider(),
        ],
      ),
    );
  }
}

class _ClubsDivider extends StatelessWidget {
  const _ClubsDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
    );
  }
}

/// Ряд клуба — превью строго 90×60 как в «Событиях», без скруглений
class _ClubRow extends StatelessWidget {
  final String asset;
  final String name;
  final String city;
  final int members;
  final VoidCallback? onTap;

  const _ClubRow({
    required this.asset,
    required this.name,
    required this.city,
    required this.members,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start, // как в events
      children: [
        Image.asset(asset, width: 90, height: 60),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$city · Участников: $members',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: row,
      ),
    );
  }
}
