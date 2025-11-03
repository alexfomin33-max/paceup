import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool tWorkouts = true;
  bool tLikes = true;
  bool tComments = true;
  bool tPosts = true;
  bool tEvents = true;
  bool tRegistrations = true;
  bool tFollowers = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ← барьер для закрытия при клике вне окна
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
        ),
        // ← сам контент sheet
        SafeArea(
          top: false,
          bottom: true, // чтобы не заезжать под системную «бороду»
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              // ← останавливаем распространение кликов от контента sheet
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: double.infinity, // на всю ширину
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl), // только верхние углы
                  ),
                  child: Material(
                    color: AppColors.surface,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                          child: _ToggleList(
                            children: [
                              _ToggleRow(
                                label: 'Уведомления о новых тренировках',
                                value: tWorkouts,
                                onChanged: (v) => setState(() => tWorkouts = v),
                              ),
                              _ToggleRow(
                                label: 'Уведомления о новых лайках',
                                value: tLikes,
                                onChanged: (v) => setState(() => tLikes = v),
                              ),
                              _ToggleRow(
                                label: 'Уведомления о новых комментариях',
                                value: tComments,
                                onChanged: (v) => setState(() => tComments = v),
                              ),
                              _ToggleRow(
                                label: 'Уведомления о новых постах',
                                value: tPosts,
                                onChanged: (v) => setState(() => tPosts = v),
                              ),
                              _ToggleRow(
                                label: 'Уведомления о новых событиях',
                                value: tEvents,
                                onChanged: (v) => setState(() => tEvents = v),
                              ),
                              _ToggleRow(
                                label: 'Уведомления о регистрациях на события',
                                value: tRegistrations,
                                onChanged: (v) =>
                                    setState(() => tRegistrations = v),
                              ),
                              _ToggleRow(
                                label: 'Уведомления о новых подписчиках',
                                value: tFollowers,
                                onChanged: (v) =>
                                    setState(() => tFollowers = v),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 2),
                      ],
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

class _ToggleList extends StatelessWidget {
  final List<Widget> children;
  const _ToggleList({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        color: AppColors.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.border,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52, // ← желаемая высота строки (можно 48/52/60)
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              maxLines: 2, // если подпись длинная
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ↓ масштабируем сам переключатель
          Transform.scale(
            scale: 0.85, // 90% от стандартного размера. Поиграйся: 0.85–1.15
            child: Switch(
              value: value,
              onChanged: onChanged,

              // ↓ уменьшаем «обязательную» зону касания
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,

              activeTrackColor: AppColors.brandPrimary,
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.brandPrimary;
                }
                return AppColors.scrim20;
              }),
              trackOutlineColor: WidgetStateProperty.all<Color>(
                Colors.transparent,
              ),
              thumbColor: WidgetStateProperty.all<Color>(AppColors.surface),
            ),
          ),
        ],
      ),
    );
  }
}
