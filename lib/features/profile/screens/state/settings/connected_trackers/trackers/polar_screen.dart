import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../core/widgets/primary_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ЭКРАН «POLAR»
// ─────────────────────────────────────────────────────────────────────────────

class PolarScreen extends ConsumerStatefulWidget {
  const PolarScreen({super.key});

  @override
  ConsumerState<PolarScreen> createState() => _PolarScreenState();
}

class _PolarScreenState extends ConsumerState<PolarScreen> {
  // Состояние подключения
  bool _connected = false;
  bool _busy = false;

  // Краткий статус
  String _status = '';

  // Для SnackBar
  String? _snackBarMessage;

  // Для запроса подключения и синхронизации
  bool _requestingConnection = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  // ───────── Утилиты форматирования ─────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    setState(() => _snackBarMessage = message);
  }

  // ───────── Проверка подключения ─────────

  Future<void> _checkConnection() async {
    setState(() {
      _status = 'Проверка подключения…';
    });

    // TODO: Реализовать проверку подключения Polar через API
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      _connected = false; // TODO: Заменить на реальную проверку
      _status = _connected
          ? 'Polar подключен. Готов к синхронизации.'
          : 'Polar не подключен.';
    });
  }

  // ───────── Подключение Polar ─────────

  Future<void> _connectPolar() async {
    if (_requestingConnection) return;

    setState(() {
      _requestingConnection = true;
      _status = 'Подключение к Polar…';
    });

    try {
      // TODO: Реализовать OAuth авторизацию Polar
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Имитация успешного подключения
      setState(() {
        _connected = true;
        _status = 'Polar успешно подключен.';
        _requestingConnection = false;
      });

      _showSnackBar('Polar успешно подключен');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Ошибка подключения: ${ErrorHandler.format(e)}';
        _requestingConnection = false;
      });
      _showSnackBar('Ошибка подключения: ${ErrorHandler.format(e)}');
    }
  }

  // ───────── Синхронизация ─────────

  Future<void> _syncPolar() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = 'Синхронизация с Polar…';
    });

    try {
      // TODO: Реализовать синхронизацию тренировок из Polar
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _status = 'Синхронизация завершена.';
        _busy = false;
      });

      _showSnackBar('Тренировки успешно синхронизированы из Polar');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Ошибка синхронизации: ${ErrorHandler.format(e)}';
        _busy = false;
      });
      _showSnackBar('Ошибка синхронизации: ${ErrorHandler.format(e)}');
    }
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    // Ленивая демонстрация SnackBar
    if (_snackBarMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_snackBarMessage!)));
        setState(() => _snackBarMessage = null);
      });
    }

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'Polar',
          backgroundColor: AppColors.twinBg,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // Инфоблок
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.heart_fill,
                        size: 28,
                        color: AppColors.brandPrimary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Синхронизация с Polar. Подключите аккаунт Polar, чтобы импортировать тренировки, дистанцию, пульс и активные калории.',
                          style: AppTextStyles.h13w4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Кнопка подключения/синхронизации
            Center(
              child: PrimaryButton(
                text: _requestingConnection
                    ? 'Подключение…'
                    : _busy
                        ? 'Синхронизация…'
                        : _connected
                            ? 'Синк из Polar'
                            : 'Подключить Polar',
                onPressed: (_requestingConnection || _busy)
                    ? () {}
                    : (_connected ? _syncPolar : _connectPolar),
                width: 260,
                height: 44,
                isLoading: _requestingConnection || _busy,
              ),
            ),

            const SizedBox(height: 16),

            // Статус
            if (_status.isNotEmpty)
              _StatusRichCard(
                title: 'Статус',
                message: _status,
              ),
          ],
        ),
      ),
    );
  }
}

/// Карточка «Статус»
class _StatusRichCard extends StatelessWidget {
  const _StatusRichCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h14w6),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.h13w4),
        ],
      ),
    );
  }
}
