import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/segmented_pill.dart';
import '../../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar

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

  // Счетчик переключений вкладок для принудительного пересоздания виджетов
  // Это гарантирует обновление данных при каждом переключении вкладок
  int _tabSwitchCounter = 0;

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
      backgroundColor: AppColors.getBackgroundColor(context),

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
                      // Увеличиваем счетчик для принудительного пересоздания виджетов
                      _tabSwitchCounter++;
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    // Увеличиваем счетчик для принудительного пересоздания виджетов
                    _tabSwitchCounter++;
                  });
                },
                children: [
                  // ────────────────────────────────────────────────────────────────
                  // Используем ValueKey с индексом вкладки и счетчиком переключений
                  // для принудительного пересоздания виджетов при каждом переключении.
                  // Это гарантирует вызов initState и обновление провайдеров.
                  // ────────────────────────────────────────────────────────────────
                  SearchFriendsContent(
                    key: ValueKey('friends_${_index}_$_tabSwitchCounter'),
                    query: _controller.text.trim(),
                  ),
                  SearchClubsContent(
                    key: ValueKey('clubs_${_index}_$_tabSwitchCounter'),
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
    return TextField(
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
