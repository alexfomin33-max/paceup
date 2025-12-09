import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import 'notification_settings_provider.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  // Локальное состояние для немедленного отображения изменений
  NotificationSettings? _localSettings;
  bool _isSaving = false;

  // Обновляем локальное состояние при изменении данных из провайдера
  void _updateLocalSettingsFromProvider() {
    final settingsAsync = ref.read(notificationSettingsProvider);
    settingsAsync.whenData((settings) {
      if (mounted && _localSettings == null) {
        setState(() {
          _localSettings = settings;
        });
      }
    });
  }

  // Загружаем настройки при открытии
  @override
  void initState() {
    super.initState();
    // Предзагружаем настройки
    Future.microtask(_updateLocalSettingsFromProvider);
  }

  // Сохранение настроек на сервер
  Future<void> _saveSettings(NotificationSettings settings) async {
    if (_isSaving) return; // Предотвращаем множественные сохранения

    setState(() {
      _isSaving = true;
    });

    try {
      await saveNotificationSettings(ref, settings);
      // После успешного сохранения обновляем локальное состояние
      setState(() {
        _localSettings = settings;
        _isSaving = false;
      });
    } catch (e) {
      // В случае ошибки показываем сообщение пользователю
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Обновление конкретной настройки
  void _updateSetting(String key, bool value) {
    final current =
        _localSettings ??
        const NotificationSettings(
          workouts: true,
          likes: true,
          comments: true,
          posts: true,
          events: true,
          registrations: true,
          followers: true,
        );

    final updated = switch (key) {
      'workouts' => current.copyWith(workouts: value),
      'likes' => current.copyWith(likes: value),
      'comments' => current.copyWith(comments: value),
      'posts' => current.copyWith(posts: value),
      'events' => current.copyWith(events: value),
      'registrations' => current.copyWith(registrations: value),
      'followers' => current.copyWith(followers: value),
      _ => current,
    };

    setState(() {
      _localSettings = updated;
    });

    // Сохраняем на сервер
    _saveSettings(updated);
  }

  @override
  Widget build(BuildContext context) {
    // Получаем настройки из провайдера
    final settingsAsync = ref.watch(notificationSettingsProvider);

    // Используем локальное состояние, если оно есть, иначе данные из провайдера
    final NotificationSettings settings =
        _localSettings ??
        settingsAsync.when(
          data: (s) => s,
          loading: () => const NotificationSettings(
            workouts: true,
            likes: true,
            comments: true,
            posts: true,
            events: true,
            registrations: true,
            followers: true,
          ),
          error: (_, _) => const NotificationSettings(
            workouts: true,
            likes: true,
            comments: true,
            posts: true,
            events: true,
            registrations: true,
            followers: true,
          ),
        );

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
                    color: AppColors.getSurfaceColor(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.getBorderColor(context),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Показываем состояние загрузки или ошибки
                        settingsAsync.when(
                          data: (_) => Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                            child: _ToggleList(
                              children: [
                                _ToggleRow(
                                  label: 'Уведомления о новых тренировках',
                                  value: settings.workouts,
                                  onChanged: _isSaving
                                      ? null
                                      : (v) => _updateSetting('workouts', v),
                                ),
                                _ToggleRow(
                                  label: 'Уведомления о новых лайках',
                                  value: settings.likes,
                                  onChanged: _isSaving
                                      ? null
                                      : (v) => _updateSetting('likes', v),
                                ),
                                _ToggleRow(
                                  label: 'Уведомления о новых комментариях',
                                  value: settings.comments,
                                  onChanged: _isSaving
                                      ? null
                                      : (v) => _updateSetting('comments', v),
                                ),
                                _ToggleRow(
                                  label: 'Уведомления о новых постах',
                                  value: settings.posts,
                                  onChanged: _isSaving
                                      ? null
                                      : (v) => _updateSetting('posts', v),
                                ),
                                _ToggleRow(
                                  label: 'Уведомления о новых событиях',
                                  value: settings.events,
                                  onChanged: _isSaving
                                      ? null
                                      : (v) => _updateSetting('events', v),
                                ),
                                _ToggleRow(
                                  label:
                                      'Уведомления о регистрациях на события',
                                  value: settings.registrations,
                                  onChanged: _isSaving
                                      ? null
                                      : (v) =>
                                            _updateSetting('registrations', v),
                                ),
                                _ToggleRow(
                                  label: 'Уведомления о новых подписчиках',
                                  value: settings.followers,
                                  onChanged: _isSaving
                                      ? null
                                      : (v) => _updateSetting('followers', v),
                                ),
                              ],
                            ),
                          ),
                          loading: () => const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, stack) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Ошибка загрузки настроек',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
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
        color: AppColors.getSurfaceColor(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.getBorderColor(context),
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
  final ValueChanged<bool>? onChanged;

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
              style: TextStyle(
                fontSize: 13,
                color: AppColors.getTextPrimaryColor(context),
              ),
              maxLines: 2, // если подпись длинная
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ↓ масштабируем сам переключатель
          Transform.scale(
            scale: 0.85, // 90% от стандартного размера. Поиграйся: 0.85–1.15
            child: Switch(
              value: value,
              onChanged: onChanged, // Может быть null при сохранении
              // ↓ уменьшаем «обязательную» зону касания
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,

              activeTrackColor: AppColors.brandPrimary,
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.brandPrimary;
                }
                // В темной теме используем более светлый цвет для неактивного трека
                return Theme.of(context).brightness == Brightness.dark
                    ? AppColors.getBorderColor(context).withValues(alpha: 0.3)
                    : AppColors.scrim20;
              }),
              trackOutlineColor: WidgetStateProperty.all<Color>(
                Colors.transparent,
              ),
              thumbColor: WidgetStateProperty.all<Color>(
                AppColors.getSurfaceColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
