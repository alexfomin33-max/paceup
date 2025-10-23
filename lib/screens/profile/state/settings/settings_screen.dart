import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart';
import 'settings_placeholder_screen.dart'; // 👈 экран-заглушка
import '../../../../widgets/interactive_back_swipe.dart';
import 'connected_trackers/connected_trackers_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext context, String title, {String? note}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPlaceholderScreen(title: title, note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: () => _open(context, 'Управление подпиской PacePro'),
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
                      MaterialPageRoute(
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
                _SettingsTile(
                  icon: CupertinoIcons.phone,
                  iconColor: AppColors.brandPrimary,
                  title: 'Телефон',
                  trailingText: '+7 (9**) ***–25–38',
                  onTap: () => _open(context, 'Телефон'),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.envelope,
                  iconColor: AppColors.brandPrimary,
                  title: 'E-mail',
                  trailingText: 'pa*****@ya.ru',
                  onTap: () => _open(context, 'E-mail'),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.lock,
                  iconColor: AppColors.brandPrimary,
                  title: 'Пароль',
                  trailingText: '********',
                  onTap: () => _open(context, 'Пароль'),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.rectangle_on_rectangle_angled,
                  iconColor: AppColors.brandPrimary,
                  title: 'Код-пароль и Face ID',
                  trailingText: 'Откл.',
                  onTap: () => _open(context, 'Код-пароль и Face ID'),
                ),
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
                  onTap: () => _open(context, 'Push-уведомления'),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.arrow_2_circlepath,
                  iconColor: AppColors.brandPrimary,
                  title: 'Доступ к данным',
                  onTap: () => _open(context, 'Доступ к данным'),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.person_2,
                  iconColor: AppColors.brandPrimary,
                  title: 'Контакты',
                  onTap: () => _open(context, 'Контакты'),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.question_circle,
                  iconColor: AppColors.brandPrimary,
                  title: 'Справочная информация',
                  onTap: () => _open(context, 'Справочная информация'),
                ),
                const _Divider(),
                _SettingsTile(
                  icon: CupertinoIcons.bubble_left,
                  iconColor: AppColors.brandPrimary,
                  title: 'Предложения по улучшению',
                  onTap: () => _open(context, 'Предложения по улучшению'),
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
                  onTap: () => _open(
                    context,
                    'На кофе разработчикам',
                    note: 'Здесь будет окно оплаты доната.',
                  ),
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
                  onTap: () => _open(
                    context,
                    'Выйти',
                    note: 'Тут появится подтверждение и выход из аккаунта.',
                  ),
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
