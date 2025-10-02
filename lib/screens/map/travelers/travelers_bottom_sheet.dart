import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Каркас bottom sheet для вкладки «Попутчики» — 1:1 как в events_bottom_sheet.dart
class TravelersBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFraction;

  const TravelersBottomSheet({
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
class TravelersSheetPlaceholder extends StatelessWidget {
  const TravelersSheetPlaceholder({super.key});
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

/// Простой текст (аналог EventsSheetText/ClubsSheetText/SlotsSheetText)
class TravelersSheetText extends StatelessWidget {
  final String text;
  const TravelersSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, color: AppColors.text),
    );
  }
}

/// Пример списка заявок попутчиков (когда будут ассеты — можно задействовать)
/// Превью строго 90×60, стили и отступы — как в событиях/клубах/слотах.
class TravelersListVladimir extends StatelessWidget {
  const TravelersListVladimir({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // нижний отступ как в других листах
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
      child: Column(
        children: const [
          _TravelerRow(
            asset: 'assets/traveler_example_1.png',
            title: 'Ищу попутчиков на «Коферан»',
            subtitle: '14 июня 2025 · старт у Золотых ворот',
          ),
          _TravelersDivider(),
          _TravelerRow(
            asset: 'assets/traveler_example_2.png',
            title: 'Москва → Владимир: беговой уикенд',
            subtitle: 'Пятница вечером · 2 места в авто',
          ),
        ],
      ),
    );
  }
}

class _TravelersDivider extends StatelessWidget {
  const _TravelersDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
    );
  }
}

/// Ряд заявки — превью 90×60, типографика идентична остальным шитам
class _TravelerRow extends StatelessWidget {
  final String asset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _TravelerRow({
    required this.asset,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(asset, width: 90, height: 60, fit: BoxFit.cover),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // заголовок
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              // подпись
              Text(
                subtitle,
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
