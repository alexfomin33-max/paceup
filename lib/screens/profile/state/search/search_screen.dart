import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/segmented_pill.dart';
import '../../../../widgets/app_bar.dart'; // ← глобальный AppBar

import 'tabs/friends_content.dart';
import 'tabs/clubs_content.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///                          Поиск: Друзья / Клубы
///  • Свайп между вкладками: PageView + PageController
///  • Пилюля со скользящим "thumb": AnimatedAlign
///  • Двусторонняя синхронизация: тап → листание, свайп → активное состояние
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

  // Пейджер для свайпа вкладок
  late final PageController _page;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFriends = _index == 0;

    return Scaffold(
      backgroundColor: AppColors.background,

      // ── Глобальная шапка
      appBar: const PaceAppBar(title: 'Поиск'),

      // ───────────────────────────────────────────────────────────────────
      // Тело: пилюля, поле поиска, затем контент как PageView (свайп!)
      // ───────────────────────────────────────────────────────────────────
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            const SizedBox(height: 14),

            // Переключатель "Друзья / Клубы" с анимированным thumb
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SegmentedPill(
                  left: 'Друзья',
                  right: 'Клубы',
                  value: _index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic, // тот же, что и для animateToPage
                  haptics: true, // лёгкая отдача
                  onChanged: (v) {
                    setState(() {
                      _index = v;
                      _controller.clear();
                      _focus.unfocus();
                    });
                    _page.animateToPage(
                      v,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Поисковое поле
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchField(
                controller: _controller,
                focusNode: _focus,
                hintText: isFriends ? 'Поиск друзей' : 'Поиск клуба',
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 8),

            // Контент вкладок с горизонтальным свайпом
            Expanded(
              child: PageView(
                controller: _page,
                physics: const BouncingScrollPhysics(),
                allowImplicitScrolling: true, // советую включить и здесь
                onPageChanged: (i) {
                  if (_index == i) return; // гард от лишнего перерендера
                  setState(() {
                    _index = i;
                    _controller.clear(); // очищаем строку поиска
                    _focus.unfocus(); // убираем клавиатуру/фокус
                  });
                },
                children: [
                  // Важно: даём ключи, чтобы сохранить состояние при переключении
                  // query передается как prop, виджет обновится через setState при изменении текста
                  SearchFriendsContent(
                    key: const PageStorageKey('search_friends_page'),
                    query: _controller.text.trim(),
                  ),
                  SearchClubsContent(
                    key: const PageStorageKey('search_clubs_page'),
                    query: _controller.text.trim(),
                  ),
                ],
              ),
            ),
          ],
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
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        cursorColor: AppColors.textSecondary,
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
            color: AppColors.textPlaceholder,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border, width: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border, width: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.outline, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }
}
