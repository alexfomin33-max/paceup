// lib/widgets/user_header.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';

/// ──────────────────────────────────────────────────────────────
/// USER HEADER: аватар, имя, дата + trailing (справа) и bottom (снизу)
/// ──────────────────────────────────────────────────────────────
/// Зачем: единый визуал для Поста и Активности.
/// Что даст: единые отступы/стили, вертикальное выравнивание имени/даты
/// по центру аватара, а нижний слот не влияет на выравнивание заголовка.
class UserHeader extends StatelessWidget {
  final String userName;
  final String userAvatar; // url или asset
  final String dateText; // готовая строка даты
  final VoidCallback? onAvatarTap;
  final Widget? trailing; // справа, например, кнопка "…"
  final Widget? bottom; // снизу, например, StatsRow
  final double bottomGap; // отступ между датой и bottom (по исходнику 18)

  /// Размер аватара (по умолчанию 50 как в макете)
  final double avatarSize;

  const UserHeader({
    super.key,
    required this.userName,
    required this.userAvatar,
    required this.dateText,
    this.onAvatarTap,
    this.trailing,
    this.bottom,
    this.bottomGap = 18.0,
    this.avatarSize = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      // ──────────────────────────────────────────────────────────────
      // ВЕРХНИЙ РЯД: аватар слева, справа — колонка с заголовком и bottom
      // ──────────────────────────────────────────────────────────────
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // АВАТАР (кликабелен опционально)
        GestureDetector(
          onTap: onAvatarTap,
          child: Avatar(image: userAvatar, size: avatarSize),
        ),
        const SizedBox(width: 12),

        // ПРАВАЯ КОЛОНКА: (1) заголовок фиксированной высоты = avatarSize
        // с вертикальным центрированием имени/даты; (2) опциональный bottom ниже.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────────────────────────────────────────────────────
              // ЗАГОЛОВОК (ИМЯ + ДАТА): всегда по вертикальному центру аватара
              // ──────────────────────────────────────────────────────────────
              SizedBox(
                height: avatarSize,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: AppTextStyles.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: AppTextStyles.date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ──────────────────────────────────────────────────────────────
              // НИЖНИЙ СЛОТ (например, метрики Активности)
              // ──────────────────────────────────────────────────────────────
              if (bottom != null) ...[SizedBox(height: bottomGap), bottom!],
            ],
          ),
        ),

        // ──────────────────────────────────────────────────────────────
        // TRAILING (например, кнопка "…"): центрируем по аватару
        // ──────────────────────────────────────────────────────────────
        if (trailing != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: avatarSize,
            child: Center(child: trailing!),
          ),
        ],
      ],
    );
  }
}
