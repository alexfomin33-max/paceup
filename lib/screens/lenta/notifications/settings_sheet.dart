// lib/screens/lenta/notifications/settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // для WidgetState/WidgetStateProperty
import '../../../../theme/app_theme.dart';

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
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        bottom: true, // чтобы не заезжать под системную «бороду»
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: double.infinity, // на всю ширину
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.large), // только верхние углы
              ),
              child: Material(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
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
                            onChanged: (v) => setState(() => tFollowers = v),
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
    );
  }
}

class _ToggleList extends StatelessWidget {
  final List<Widget> children;
  const _ToggleList({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        color: Colors.white,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.text,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            // ✅ Замена MaterialStateProperty → WidgetStateProperty
            activeTrackColor: AppColors.secondary,
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.secondary;
              }
              return const Color(0xFFCFD3DA);
            }),
            trackOutlineColor: WidgetStateProperty.all<Color>(
              Colors.transparent,
            ),
            thumbColor: WidgetStateProperty.all<Color>(Colors.white),
          ),
        ],
      ),
    );
  }
}
