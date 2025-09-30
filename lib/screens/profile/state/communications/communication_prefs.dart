import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import 'subscriptions_content.dart';
import 'subscribers_content.dart';

/// Главная страница «Связи»: сегмент + поиск + контент
class CommunicationPrefsPage extends StatefulWidget {
  /// 0 = Подписки (по умолчанию), 1 = Подписчики
  final int startIndex;
  const CommunicationPrefsPage({super.key, this.startIndex = 0});

  @override
  State<CommunicationPrefsPage> createState() => _CommunicationPrefsPageState();
}

class _CommunicationPrefsPageState extends State<CommunicationPrefsPage> {
  int _index = 0;
  final _controller = TextEditingController();
  final _focus = FocusNode();

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

  @override
  Widget build(BuildContext context) {
    final isSubs = _index == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Связи',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        leading: IconButton(
          splashRadius: 22,
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.text,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 14),

          // Переключатели (как в 200k_run_screen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: _SegmentedPill(
                left: 'Подписки',
                right: 'Подписчики',
                value: _index,
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

          const SizedBox(height: 16),

          // Поисковое поле
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

          // Контент
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isSubs
                  ? SubscriptionsContent(
                      key: const ValueKey('subscriptions'),
                      query: _controller.text.trim(),
                    )
                  : SubscribersContent(
                      key: const ValueKey('subscribers'),
                      query: _controller.text.trim(),
                    ),
            ),
          ),
        ],
      ),
    );
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEAEAEA), width: 1),
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
          color: selected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.text,
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
        cursorColor: AppColors.secondary,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          color: AppColors.text,
        ),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.greytext,
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: AppColors.greytext,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFE6E6E8), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFE6E6E8), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: AppColors.secondary,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
