// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// контенты по вкладкам
import 'tabs/active_content.dart';
import 'tabs/available_content.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _segment = 0; // 0 — Активные, 1 — Доступные

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        title: const Text('Задачи', style: AppTextStyles.h1),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            Center(
              child: _SegmentedPill(
                left: 'Активные',
                right: 'Доступные',
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
            ),
            const SizedBox(height: 20),

            // контент вкладок
            if (_segment == 0)
              const ActiveContent()
            else
              const AvailableContent(),
          ],
        ),
      ),
    );
  }
}

/// Пилюльный переключатель (унифицированный со стилем в проекте)
class _SegmentedPill extends StatelessWidget {
  final String left;
  final String right;
  final int value; // 0 или 1
  final ValueChanged<int> onChanged;
  const _SegmentedPill({
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_seg(0, left), _seg(1, right)],
      ),
    );
  }

  Widget _seg(int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? AppColors.surface : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
