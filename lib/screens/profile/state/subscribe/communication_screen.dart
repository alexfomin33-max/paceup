// lib/screens/.../communication_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/segmented_pill.dart'; // ← глобальная пилюля
import '../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar
import 'tabs/subscriptions/subscriptions_content.dart';
import 'tabs/subscribers/subscribers_content.dart';

/// Главная страница «Связи»: сегмент + поиск + контент (с пагинацией свайпами)
class CommunicationPrefsPage extends StatefulWidget {
  /// 0 = Подписки (по умолчанию), 1 = Подписчики
  final int startIndex;
  /// ID пользователя, чьи подписки/подписчики нужно показать
  /// Если null, используются подписки/подписчики авторизованного пользователя
  final int? userId;
  const CommunicationPrefsPage({
    super.key,
    this.startIndex = 0,
    this.userId,
  });

  @override
  State<CommunicationPrefsPage> createState() => _CommunicationPrefsPageState();
}

class _CommunicationPrefsPageState extends State<CommunicationPrefsPage> {
  // motion-токены (как в остальных экранах)
  static const Duration _kTabAnim = Duration(milliseconds: 300);
  static const Curve _kTabCurve = Curves.easeOutCubic;

  late int _index;
  late final PageController _page;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _switchTo(int i) {
    if (_index == i) return;
    _controller.clear();
    _focus.unfocus();
    setState(() => _index = i);
    _page.animateToPage(i, duration: _kTabAnim, curve: _kTabCurve);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: const PaceAppBar(
        title: 'Связи',
        // дефолтная «назад», центрированный титул, нижний разделитель — уже настроены
      ),
      body: Column(
        children: [
          const SizedBox(height: 14),

          // Пилюля — глобальный виджет с синхронизацией с PageView
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SegmentedPill(
                left: 'Подписки',
                right: 'Подписчики',
                value: _index,
                width: 280,
                height: 40,
                duration: _kTabAnim,
                curve: _kTabCurve,
                haptics: true,
                onChanged: _switchTo,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Поиск — общий для текущей вкладки
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _SearchField(
              controller: _controller,
              focusNode: _focus,
              hintText: 'Поиск',
              onChanged: (_) => setState(() {}), // обновим query
            ),
          ),

          const SizedBox(height: 8),

          // Контент с горизонтальными свайпами
          Expanded(
            child: PageView(
              controller: _page,
              physics: const BouncingScrollPhysics(),
              allowImplicitScrolling: true,
              onPageChanged: (i) {
                if (_index == i) return; // гард от лишнего setState
                setState(() => _index = i);
              },
              children: [
                // ключи сохраняют вертикальный скролл внутри вкладок
                _PageKeepAlive(
                  child: SubscriptionsContent(
                    key: const ValueKey('subscriptions'),
                    query: query,
                    userId: widget.userId,
                  ),
                ),
                _PageKeepAlive(
                  child: SubscribersContent(
                    key: const ValueKey('subscribers'),
                    query: query,
                    userId: widget.userId,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Обёртка для сохранения состояния дочерних списков внутри PageView.
class _PageKeepAlive extends StatefulWidget {
  final Widget child;
  const _PageKeepAlive({required this.child});

  @override
  State<_PageKeepAlive> createState() => _PageKeepAliveState();
}

class _PageKeepAliveState extends State<_PageKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// ===== локальные виджеты (поиск остаётся здесь)

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const _SearchField({
    required this.controller,
    this.focusNode,
    required this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.words,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.search,
      cursorColor: AppColors.getTextSecondaryColor(context),
      style: AppTextStyles.h14w4.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          CupertinoIcons.search,
          size: 18,
          color: AppColors.getIconSecondaryColor(context),
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        hintText: hintText,
        hintStyle: AppTextStyles.h14w4Place.copyWith(
          color: AppColors.getTextPlaceholderColor(context),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
      ),
    );
  }
}
