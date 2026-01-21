import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/segmented_pill.dart';
import '../../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar

import 'tabs/friends_content.dart';
import 'tabs/clubs_content.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///                          Поиск: Друзья / Клубы
///  • Переключатель вкладок без анимации и свайпа
///  • При смене вкладки отображается только выбранный контент (загрузка по факту)
/// ─────────────────────────────────────────────────────────────────────────────
class SearchPrefsPage extends StatefulWidget {
  /// 0 = Друзья (по умолчанию), 1 = Клубы
  final int startIndex;
  const SearchPrefsPage({super.key, this.startIndex = 0});

  @override
  State<SearchPrefsPage> createState() => _SearchPrefsPageState();
}

class _SearchPrefsPageState extends State<SearchPrefsPage> {
  // Текущая вкладка (0/1)
  int _index = 0;

  // Поле ввода + фокус
  final _controller = TextEditingController();
  final _focus = FocusNode();

  // Поле поиска скрыто по умолчанию, показывается по тапу на иконку в AppBar
  bool _searchFieldVisible = false;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
  }

  @override
  void dispose() {
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

  /// Слайверы-шапка: пилюля и поле поиска, скроллятся вместе с контентом
  List<Widget> _buildHeaderSlivers({required bool isFriends}) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: SegmentedPill(
              left: 'Друзья',
              right: 'Клубы',
              value: _index,
              duration: Duration.zero,
              haptics: true,
              showBorder: false,
              boxShadow: const [
                BoxShadow(
                  color: AppColors.twinshadow,
                  blurRadius: 20,
                  offset: Offset(0, 1),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _index = v;
                  _controller.clear();
                  _focus.unfocus();
                });
              },
            ),
          ),
        ),
      ),
      if (_searchFieldVisible) const SliverToBoxAdapter(child: SizedBox(height: 16)),
      if (_searchFieldVisible)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _SearchField(
              controller: _controller,
              focusNode: _focus,
              hintText: isFriends ? 'Поиск друзей' : 'Поиск клуба',
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.twinBg,

      // ── Глобальная шапка, справа — иконка поиска (показать/скрыть поле)
      appBar: PaceAppBar(
        title: 'Поиск',
        backgroundColor: AppColors.twinBg,
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
        ],
      ),

      // ───────────────────────────────────────────────────────────────────
      // Тело: один скролл — пилюля, поле поиска и контент скроллятся вместе
      // ───────────────────────────────────────────────────────────────────
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: _index == 0
            ? SearchFriendsContent(
                query: _controller.text.trim(),
                customHeaderSlivers: _buildHeaderSlivers(isFriends: true),
              )
            : SearchClubsContent(
                query: _controller.text.trim(),
                customHeaderSlivers: _buildHeaderSlivers(isFriends: false),
              ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///                             Локальные виджеты
/// ─────────────────────────────────────────────────────────────────────────────

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
        cursorColor: AppColors.getTextSecondaryColor(context),
        textInputAction: TextInputAction.search,
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
          fillColor: Colors.transparent,
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
        ),
      ),
    );
  }
}
