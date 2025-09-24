import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'settings_placeholder_screen.dart'; // 👈 экран-заглушка

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.text),
          onPressed: () => Navigator.of(context).maybePop(),
          splashRadius: 18,
        ),
        title: const Text(
          'Настройки',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: SizedBox(
            height: 0.5,
            child: ColoredBox(color: Color(0xFFEAEAEA)),
          ),
        ),
      ),
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
                iconColor: AppColors.secondary,
                title: 'Подключенные трекеры',
                onTap: () => _open(context, 'Подключенные трекеры'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Аккаунт
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: CupertinoIcons.phone,
                iconColor: AppColors.secondary,
                title: 'Телефон',
                trailingText: '+7 (9**) ***–25–38',
                onTap: () => _open(context, 'Телефон'),
              ),
              const _Divider(),
              _SettingsTile(
                icon: CupertinoIcons.envelope,
                iconColor: AppColors.secondary,
                title: 'E-mail',
                trailingText: 'pa*****@ya.ru',
                onTap: () => _open(context, 'E-mail'),
              ),
              const _Divider(),
              _SettingsTile(
                icon: CupertinoIcons.lock,
                iconColor: AppColors.secondary,
                title: 'Пароль',
                trailingText: '********',
                onTap: () => _open(context, 'Пароль'),
              ),
              const _Divider(),
              _SettingsTile(
                icon: CupertinoIcons.rectangle_on_rectangle_angled,
                iconColor: AppColors.secondary,
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
                iconColor: AppColors.secondary,
                title: 'Push-уведомления',
                onTap: () => _open(context, 'Push-уведомления'),
              ),
              const _Divider(),
              _SettingsTile(
                icon: CupertinoIcons.arrow_2_circlepath,
                iconColor: AppColors.secondary,
                title: 'Доступ к данным',
                onTap: () => _open(context, 'Доступ к данным'),
              ),
              const _Divider(),
              _SettingsTile(
                icon: CupertinoIcons.person_2,
                iconColor: AppColors.secondary,
                title: 'Контакты',
                onTap: () => _open(context, 'Контакты'),
              ),
              const _Divider(),
              _SettingsTile(
                icon: CupertinoIcons.question_circle,
                iconColor: AppColors.secondary,
                title: 'Справочная информация',
                onTap: () => _open(context, 'Справочная информация'),
              ),
              const _Divider(),
              _SettingsTile(
                icon: CupertinoIcons.bubble_left,
                iconColor: AppColors.secondary,
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
                iconColor: const Color(0xFFD32F2F),
                title: 'На кофе разработчикам',
                trailingText: '99 ₽',
                trailingTextColor: const Color(0xFFD32F2F),
                trailingIconColor: const Color(
                  0xFFD32F2F,
                ), // 🔹 красная стрелка
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
                iconColor: AppColors.secondary,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: _cardDecoration,
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                  height: 1.2,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: AppColors.secondary,
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
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailingText,
    this.trailingTextColor,
    this.onTap,
    this.trailingIconColor = AppColors.secondary, // по умолчанию серый
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(12),
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
                color: iconColor ?? const Color(0xFF5E6A7D),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: trailingTextColor ?? const Color(0xFF5E6A7D),
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
      color: const Color(0xFFE0E0E0),
    );
  }
}

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFEAEAEA), width: 1)),
);
