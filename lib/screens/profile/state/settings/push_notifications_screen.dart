import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/providers/form_state_provider.dart';
import '../../../../../core/widgets/form_error_display.dart';

/// Экран настроек Push-уведомлений
class PushNotificationsScreen extends ConsumerStatefulWidget {
  const PushNotificationsScreen({super.key});

  @override
  ConsumerState<PushNotificationsScreen> createState() =>
      _PushNotificationsScreenState();
}

class _PushNotificationsScreenState
    extends ConsumerState<PushNotificationsScreen> {
  // Настройки уведомлений
  bool _newFollowers = true;
  bool _newLikes = true;
  bool _newComments = true;
  bool _newMessages = true;
  bool _eventReminders = true;
  bool _achievements = true;
  bool _weeklyStats = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Загрузка настроек уведомлений
  Future<void> _loadSettings() async {
    final formNotifier = ref.read(formStateProvider.notifier);

    await formNotifier.submitWithLoading(
      () async {
        final authService = ref.read(authServiceProvider);
        final userId = await authService.getUserId();
        if (userId == null) {
          throw Exception('Пользователь не авторизован');
        }

        final api = ref.read(apiServiceProvider);
        final data = await api.post(
          '/get_push_settings.php',
          body: {'user_id': userId},
        );

        if (!mounted) return;

        setState(() {
          _newFollowers = data['new_followers'] ?? true;
          _newLikes = data['new_likes'] ?? true;
          _newComments = data['new_comments'] ?? true;
          _newMessages = data['new_messages'] ?? true;
          _eventReminders = data['event_reminders'] ?? true;
          _achievements = data['achievements'] ?? true;
          _weeklyStats = data['weekly_stats'] ?? false;
        });
      },
    );
  }

  /// Сохранение настройки уведомления
  Future<void> _saveSetting(String key, bool value) async {
    try {
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();
      if (userId == null) return;

      final api = ref.read(apiServiceProvider);
      await api.post(
        '/update_push_settings.php',
        body: {'user_id': userId, key: value ? 1 : 0},
      );
    } catch (e) {
      // В случае ошибки откатываем значение
      if (mounted) {
        setState(() {
          switch (key) {
            case 'new_followers':
              _newFollowers = !value;
              break;
            case 'new_likes':
              _newLikes = !value;
              break;
            case 'new_comments':
              _newComments = !value;
              break;
            case 'new_messages':
              _newMessages = !value;
              break;
            case 'event_reminders':
              _eventReminders = !value;
              break;
            case 'achievements':
              _achievements = !value;
              break;
            case 'weekly_stats':
              _weeklyStats = !value;
              break;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Push-уведомления'),
        body: SafeArea(
          child: formState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                )
              : formState.hasErrors
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        FormErrorDisplay(formState: formState),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Повторить',
                          onPressed: () => _loadSettings(),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Социальные уведомления
                    _NotificationSection(
                      title: 'Социальные',
                      children: [
                        _NotificationTile(
                          icon: CupertinoIcons.person_add,
                          iconColor: AppColors.brandPrimary,
                          title: 'Новые подписчики',
                          value: _newFollowers,
                          onChanged: (value) {
                            setState(() {
                              _newFollowers = value;
                            });
                            _saveSetting('new_followers', value);
                          },
                        ),
                        const _Divider(),
                        _NotificationTile(
                          icon: CupertinoIcons.heart,
                          iconColor: AppColors.error,
                          title: 'Новые лайки',
                          value: _newLikes,
                          onChanged: (value) {
                            setState(() {
                              _newLikes = value;
                            });
                            _saveSetting('new_likes', value);
                          },
                        ),
                        const _Divider(),
                        _NotificationTile(
                          icon: CupertinoIcons.chat_bubble,
                          iconColor: AppColors.brandPrimary,
                          title: 'Новые комментарии',
                          value: _newComments,
                          onChanged: (value) {
                            setState(() {
                              _newComments = value;
                            });
                            _saveSetting('new_comments', value);
                          },
                        ),
                        const _Divider(),
                        _NotificationTile(
                          icon: CupertinoIcons.mail,
                          iconColor: AppColors.brandPrimary,
                          title: 'Новые сообщения',
                          value: _newMessages,
                          onChanged: (value) {
                            setState(() {
                              _newMessages = value;
                            });
                            _saveSetting('new_messages', value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // События и достижения
                    _NotificationSection(
                      title: 'События и достижения',
                      children: [
                        _NotificationTile(
                          icon: CupertinoIcons.calendar,
                          iconColor: AppColors.brandPrimary,
                          title: 'Напоминания о событиях',
                          value: _eventReminders,
                          onChanged: (value) {
                            setState(() {
                              _eventReminders = value;
                            });
                            _saveSetting('event_reminders', value);
                          },
                        ),
                        const _Divider(),
                        _NotificationTile(
                          icon: CupertinoIcons.star,
                          iconColor: AppColors.warning,
                          title: 'Достижения',
                          value: _achievements,
                          onChanged: (value) {
                            setState(() {
                              _achievements = value;
                            });
                            _saveSetting('achievements', value);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Статистика
                    _NotificationSection(
                      title: 'Статистика',
                      children: [
                        _NotificationTile(
                          icon: CupertinoIcons.chart_bar,
                          iconColor: AppColors.brandPrimary,
                          title: 'Еженедельная статистика',
                          value: _weeklyStats,
                          onChanged: (value) {
                            setState(() {
                              _weeklyStats = value;
                            });
                            _saveSetting('weekly_stats', value);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Секция уведомлений
class _NotificationSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _NotificationSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.getBorderColor(context), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: AppTextStyles.h12w5.copyWith(
                color: AppColors.getTextSecondaryColor(context),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Пункт уведомления
class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotificationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              alignment: Alignment.centerLeft,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.brandPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Разделитель
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final hairline = 0.7 / MediaQuery.of(context).devicePixelRatio;
    return Container(
      margin: const EdgeInsets.only(left: 48, right: 12),
      height: hairline,
      color: AppColors.getDividerColor(context),
    );
  }
}
