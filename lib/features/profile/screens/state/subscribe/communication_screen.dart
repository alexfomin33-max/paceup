// lib/screens/.../communication_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar
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

class _CommunicationPrefsPageState extends State<CommunicationPrefsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  // Поле поиска скрыто по умолчанию, показывается по тапу на иконку в AppBar
  bool _searchFieldVisible = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.startIndex,
    );
    _tab.addListener(() {
      if (_tab.indexIsChanging) {
        _controller.clear();
        _focus.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// По тапу на иконку поиска в AppBar: показать/скрыть поле (без автофокуса)
  void _onSearchIconTap() {
    setState(() {
      _searchFieldVisible = !_searchFieldVisible;
      if (!_searchFieldVisible) {
        _controller.clear();
        _focus.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Scaffold(
      backgroundColor: AppColors.getSurfaceColor(context),
      appBar: PaceAppBar(
        title: 'Связи',
        showBottomDivider: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            splashRadius: 22,
            icon: Icon(
              CupertinoIcons.search,
              size: 22,
              color: _searchFieldVisible
                  ? AppColors.brandPrimary
                  : AppColors.getIconPrimaryColor(context),
            ),
            onPressed: _onSearchIconTap,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // ── Вкладки: TabBar в стиле favorites_screen
          Container(
            color: AppColors.getSurfaceColor(context),
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              labelColor: AppColors.brandPrimary,
              unselectedLabelColor: AppColors.getTextSecondaryColor(context),
              indicator: const BoxDecoration(),
              dividerColor: AppColors.getBorderColor(context),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: const [
                Tab(text: 'Подписки'),
                Tab(text: 'Подписчики'),
              ],
            ),
          ),

          // Поиск — общий для текущей вкладки (показывается только при _searchFieldVisible)
          if (_searchFieldVisible) ...[
            const SizedBox(height: 16),
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
          ],

          // Контент с TabBarView
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const BouncingScrollPhysics(),
              children: [
                _KeepAliveWrapper(
                  child: SubscriptionsContent(
                    key: const ValueKey('subscriptions'),
                    query: query,
                    userId: widget.userId,
                  ),
                ),
                _KeepAliveWrapper(
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

/// Обёртка для сохранения состояния вкладок в TabBarView
class _KeepAliveWrapper extends StatefulWidget {
  const _KeepAliveWrapper({required this.child});

  final Widget child;

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: const [
          BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 20,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
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
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),),
    );
  }
}
