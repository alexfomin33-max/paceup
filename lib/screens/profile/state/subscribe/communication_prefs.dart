import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import 'subscriptions_content.dart';
import 'subscribers_content.dart';

/// Главная страница «Связи»: сегмент + поиск + контент (с пагинацией свайпами)
class CommunicationPrefsPage extends StatefulWidget {
  /// 0 = Подписки (по умолчанию), 1 = Подписчики
  final int startIndex;
  const CommunicationPrefsPage({super.key, this.startIndex = 0});

  @override
  State<CommunicationPrefsPage> createState() => _CommunicationPrefsPageState();
}

class _CommunicationPrefsPageState extends State<CommunicationPrefsPage> {
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
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int i) {
    if (_index != i) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Связи', style: AppTextStyles.h17w6),
        leading: IconButton(
          splashRadius: 22,
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.iconPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 14),

          // Переключатели (как в stats_tab / 200k_run_screen) — синхронизированы с PageView
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: _SegmentedPill(
                left: 'Подписки',
                right: 'Подписчики',
                value: _index,
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
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(height: 8),

          // Контент с горизонтальными свайпами
          Expanded(
            child: PageView(
              controller: _page,
              physics: const BouncingScrollPhysics(),
              onPageChanged: _onPageChanged,
              children: const [
                // ключи сохранят позицию скролла у каждой вкладки
                _PageKeepAlive(
                  child: SubscriptionsContent(
                    key: ValueKey('subscriptions'),
                    query: '',
                  ),
                ),
                _PageKeepAlive(
                  child: SubscribersContent(
                    key: ValueKey('subscribers'),
                    query: '',
                  ),
                ),
              ].map((w) => w).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Обёртка для сохранения состояния дочерних списков внутри PageView.
/// Мы прокинем актуальный query через Inherited/Builder ниже.
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

/// ===== локальные виджеты (стиль «пилюли» и поиск)

class _SegmentedPill extends StatelessWidget {
  final String left;
  final String right;
  final int value;
  final ValueChanged<int> onChanged;
  const _SegmentedPill({
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Expanded(child: _seg(0, left)),
            Expanded(child: _seg(1, right)),
          ],
        ),
      ),
    );
  }

  Widget _seg(int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.surface : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

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
