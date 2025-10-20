// lib/screens/.../communication_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/segmented_pill.dart'; // ← глобальная пилюля
import '../../../../widgets/app_bar.dart'; // ← глобальный AppBar
import 'tabs/subscriptions/subscriptions_content.dart';
import 'tabs/subscribers/subscribers_content.dart';

/// Главная страница «Связи»: сегмент + поиск + контент (с пагинацией свайпами)
class CommunicationPrefsPage extends StatefulWidget {
  /// 0 = Подписки (по умолчанию), 1 = Подписчики
  final int startIndex;
  const CommunicationPrefsPage({super.key, this.startIndex = 0});

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

  void _onPageChanged(int i) {
    if (_index != i) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
              onPageChanged: _onPageChanged,
              children: [
                // ключи сохраняют вертикальный скролл внутри вкладок
                _PageKeepAlive(
                  child: SubscriptionsContent(
                    key: const ValueKey('subscriptions'),
                    query: query,
                  ),
                ),
                _PageKeepAlive(
                  child: SubscribersContent(
                    key: const ValueKey('subscribers'),
                    query: query,
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
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        cursorColor: AppColors.brandPrimary,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.outline, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.outline, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: AppColors.brandPrimary,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }
}
