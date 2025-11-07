import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart';
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../widgets/transparent_route.dart';
import 'connected_trackers/connected_trackers_screen.dart';
import 'edit_phone_screen.dart';
import 'edit_email_screen.dart';
import 'edit_password_screen.dart';
import 'push_notifications_screen.dart';
import 'health_data_access_screen.dart';
import 'contacts_access_screen.dart';
import 'help_info_screen.dart';
import 'feedback_screen.dart';
// import 'biometric_screen.dart'; // Закомментировано для macOS/web
import 'user_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Форматирование телефона для отображения
  String _formatPhone(String phone) {
    if (phone.isEmpty) return 'Не указан';
    if (phone.length <= 4) return phone;
    // Маскируем средние цифры
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return phone;
    return '+${digits.substring(0, 1)} (${digits.substring(1, 2)}**) ***-${digits.substring(digits.length - 2)}';
  }

  /// Форматирование email для отображения
  String _formatEmail(String email) {
    if (email.isEmpty) return 'Не указан';
    if (email.length <= 3) return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return email;
    return '${name.substring(0, 2)}***@$domain';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(userSettingsProvider);
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,

        // ── глобальный PaceAppBar (покажет системную «назад», если есть куда вернуться)
        appBar: const PaceAppBar(title: 'Настройки'),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Карточка подписки PacePro
            _SubscriptionCard(
              onTap: () {
                // Пока оставляем заглушку
              },
            ),

            const SizedBox(height: 12),

            // Подключения
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.slider_horizontal_3,
                  iconColor: AppColors.brandPrimary,
                  title: 'Подключенные трекеры',
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) => const ConnectedTrackersScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Аккаунт
            _SettingsGroup(
              children: [
                settingsAsync.when(
                  data: (settings) => _SettingsTile(
                    icon: CupertinoIcons.phone,
                    iconColor: AppColors.brandPrimary,
                    title: 'Телефон',
                    trailingText: _formatPhone(settings.phone),
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                        TransparentPageRoute(
                          builder: (_) => EditPhoneScreen(
                            currentPhone: settings.phone,
                          ),
                        ),
                      );
                      if (result != null && context.mounted) {
                        ref.invalidate(userSettingsProvider);
                      }
                    },
                  ),
                  loading: () => _SettingsTile(
                    icon: CupertinoIcons.phone,
                    iconColor: AppColors.brandPrimary,
                    title: 'Телефон',
                    trailingText: 'Загрузка...',
                    onTap: () {},
                  ),
                  error: (_, __) => _SettingsTile(
                    icon: CupertinoIcons.phone,
                    iconColor: AppColors.brandPrimary,
                    title: 'Телефон',
                    trailingText: 'Ошибка',
                    onTap: () {},
                  ),
                ),
                const _Divider(),
                settingsAsync.when(
                  data: (settings) => _SettingsTile(
                    icon: CupertinoIcons.envelope,
                    iconColor: AppColors.brandPrimary,
                    title: 'E-mail',
                    trailingText: _formatEmail(settings.email),
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                        TransparentPageRoute(
                          builder: (_) => EditEmailScreen(
                            currentEmail: settings.email,
                          ),
                        ),
                      );
                      if (result != null && context.mounted) {
                        ref.invalidate(userSettingsProvider);
                      }
                    },
                  ),
                  loading: () => _SettingsTile(
                    icon: CupertinoIcons.envelope,
                    iconColor: AppColors.brandPrimary,
                    title: 'E-mail',
                    trailingText: 'Загрузка...',
                    onTap: () {},
                  ),
                  error: (_, __) => _SettingsTile(
                    icon: CupertinoIcons.envelope,
                    iconColor: AppColors.brandPrimary,
                    title: 'E-mail',
                    trailingText: 'Ошибка',
                    onTap: () {},
                  ),
                ),
                const _Divider(),
                settingsAsync.when(
                  data: (settings) => _SettingsTile(
                    icon: CupertinoIcons.lock,
                    iconColor: AppColors.brandPrimary,
                    title: 'Пароль',
                    trailingText: settings.hasPassword ? '********' : 'Не установлен',
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                        TransparentPageRoute(
                          builder: (_) => EditPasswordScreen(
                            hasPassword: settings.hasPassword,
                          ),
                        ),
                      );
                      if (result != null && context.mounted) {
                        ref.invalidate(userSettingsProvider);
                      }
                    },
                  ),
                  loading: () => _SettingsTile(
                    icon: CupertinoIcons.lock,
                    iconColor: AppColors.brandPrimary,
                    title: 'Пароль',
                    trailingText: 'Загрузка...',
                    onTap: () {},
                  ),
                  error: (_, __) => _SettingsTile(
                    icon: CupertinoIcons.lock,
                    iconColor: AppColors.brandPrimary,
                    title: 'Пароль',
                    trailingText: 'Ошибка',
                    onTap: () {},
                  ),
                ),
                // Закомментировано: local_auth удален из проекта
                // const _Divider(),
                // _SettingsTile(
                //   icon: CupertinoIcons.rectangle_on_rectangle_angled,
                //   iconColor: AppColors.brandPrimary,
                //   title: 'Код-пароль и Face ID',
                //   trailingText: 'Откл.',
                //   onTap: () {
                //     Navigator.of(context).push(
                //       TransparentPageRoute(
                //         builder: (_) => const BiometricScreen(),
                //       ),
                //     );
                //   },
                // ),
              ],
            ),

            const SizedBox(height: 12),

            // Приложение и данные
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.bell,
                  iconColor: AppColors.brandPrimary,
                  title: 'Push-уведомления',
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) => const PushNotificationsScreen(),
                      ),
                    );
                  },
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.arrow_2_circlepath,
                  iconColor: AppColors.brandPrimary,
                  title: 'Доступ к данным',
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) => const HealthDataAccessScreen(),
                      ),
                    );
                  },
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.person_2,
                  iconColor: AppColors.brandPrimary,
                  title: 'Контакты',
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) => const ContactsAccessScreen(),
                      ),
                    );
                  },
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.question_circle,
                  iconColor: AppColors.brandPrimary,
                  title: 'Справочная информация',
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) => const HelpInfoScreen(),
                      ),
                    );
                  },
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.bubble_left,
                  iconColor: AppColors.brandPrimary,
                  title: 'Предложения по улучшению',
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) => const FeedbackScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Поддержать
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.heart,
                  iconColor: AppColors.error,
                  title: 'На кофе разработчикам',
                  trailingText: '99 ₽',
                  trailingTextColor: AppColors.error,
                  trailingIconColor: AppColors.error, // 🔹 красная стрелка
                  onTap: () {
                    // Пока оставляем заглушку
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Выход
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.square_arrow_right,
                  iconColor: AppColors.brandPrimary,
                  title: 'Выйти',
                  onTap: () {
                    // Пока оставляем заглушку
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка «Управление подпиской PacePro»
class _SubscriptionCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _SubscriptionCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        decoration: _cardDecoration,
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.asset(
                'assets/pacepro.png',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Управление подпиской PacePro',
                style: AppTextStyles.h14w5,
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: AppColors.brandPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Группа настроек (белая «карточка» со скруглениями)
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      child: Column(children: children),
    );
  }
}

/// Один пункт настроек
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? trailingText;
  final Color? trailingTextColor;
  final VoidCallback? onTap;

  /// Цвет стрелки справа
  final Color trailingIconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailingText,
    this.trailingTextColor,
    this.onTap,
    this.trailingIconColor = AppColors.brandPrimary, // по умолчанию серый
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              alignment: Alignment.centerLeft,
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? AppColors.iconSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppTextStyles.h14w4)),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(
                  color: trailingTextColor ?? AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: trailingIconColor, // 🔹 теперь может быть цветной
            ),
          ],
        ),
      ),
    );
  }
}

/// Тонкий разделитель внутри карточки
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final hairline = 0.7 / MediaQuery.of(context).devicePixelRatio;
    return Container(
      margin: const EdgeInsets.only(left: 48, right: 12),
      height: hairline,
      color: AppColors.divider,
    );
  }
}

const _cardDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
  border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 1)),
);
