import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../providers/services/auth_provider.dart';
import '../../../../../../../core/services/garmin_sync_service.dart';
import '../garmin_auth_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ЭКРАН «GARMIN»
// ─────────────────────────────────────────────────────────────────────────────

class GarminScreen extends ConsumerStatefulWidget {
  const GarminScreen({super.key});

  @override
  ConsumerState<GarminScreen> createState() => _GarminScreenState();
}

class _GarminScreenState extends ConsumerState<GarminScreen> {
  // Для Garmin
  bool _garminConnected = false;
  String? _garminLastSync;
  bool _checkingGarmin = false;

  // Краткий статус
  String _status = '';

  // Для SnackBar
  String? _snackBarMessage;

  @override
  void initState() {
    super.initState();
    _checkGarminConnection();
  }

  // ───────── Утилиты форматирования ─────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    setState(() => _snackBarMessage = message);
  }

  // ───────── Garmin ─────────

  /// Проверяет статус подключения Garmin
  Future<void> _checkGarminConnection() async {
    if (_checkingGarmin) return;

    setState(() => _checkingGarmin = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          setState(() {
            _garminConnected = false;
            _checkingGarmin = false;
          });
        }
        return;
      }

      final garminService = ref.read(garminSyncServiceProvider);
      final response = await garminService.checkConnection();

      if (mounted) {
        setState(() {
          _garminConnected = response['connected'] == true;
          if (response['expires_at'] != null) {
            // Можно сохранить время истечения токена для отображения
          }
          _checkingGarmin = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _garminConnected = false;
          _checkingGarmin = false;
        });
      }
      if (kDebugMode) {
        debugPrint('Ошибка проверки подключения Garmin: $e');
      }
    }
  }

  /// Открывает экран авторизации Garmin
  Future<void> _connectGarmin() async {
    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const GarminAuthScreen(),
        ),
      );

      // Если авторизация успешна, обновляем статус
      if (result == true) {
        _checkGarminConnection();
      }
    } catch (e) {
      _showSnackBar('Ошибка подключения Garmin: ${ErrorHandler.format(e)}');
    }
  }

  /// Синхронизирует последнюю тренировку из Garmin
  Future<void> _syncGarmin() async {
    if (_checkingGarmin) return;

    setState(() {
      _checkingGarmin = true;
      _status = 'Синхронизация Garmin…';
    });

    try {
      final garminService = ref.read(garminSyncServiceProvider);
      final response = await garminService.syncLastActivity();

      if (mounted) {
        final message = response['message'] ?? 'Синхронизация завершена';

        setState(() {
          _status = message;
          _checkingGarmin = false;
        });

        if (response['success'] == true) {
          // Проверяем различные случаи успешного ответа
          if (response['already_synced'] == true) {
            _showSnackBar('Тренировка уже была синхронизирована ранее');
          } else if (response['synced_count'] != null &&
              response['synced_count'] == 0) {
            // Тренировок нет или нет подходящих типов
            _showSnackBar(message);
          } else if (response['activity_id'] != null) {
            // Тренировка успешно синхронизирована
            _showSnackBar('Тренировка успешно синхронизирована из Garmin');
          } else {
            // Другие случаи успеха
            _showSnackBar(message);
          }
        } else {
          // Обрабатываем ошибки с дополнительной информацией
          String errorMessage = message;

          // Если есть информация о неподдерживаемых типах
          if (response['found_types'] != null &&
              response['supported_types'] != null) {
            final foundTypes = (response['found_types'] as List).join(', ');
            final supportedTypes =
                (response['supported_types'] as List).join(', ');
            errorMessage = 'Неподдерживаемый тип активности.\n'
                'Найдено: $foundTypes\n'
                'Допустимые: $supportedTypes';
          }

          _showSnackBar(errorMessage);
        }

        // Если success=true, но synced_count=0 и есть unsupported_count - это информационное сообщение
        if (response['success'] == true &&
            (response['synced_count'] == null ||
                response['synced_count'] == 0) &&
            response['unsupported_count'] != null &&
            (response['unsupported_count'] as int) > 0) {
          // Это не ошибка, просто информационное сообщение
          // Логи отключены
          // if (kDebugMode) {
          //   debugPrint('ℹ️ [Garmin] ${response['message']}');
          // }
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = ErrorHandler.format(e);
        setState(() {
          _status = 'Ошибка синхронизации Garmin: $errorMessage';
          _checkingGarmin = false;
        });
        _showSnackBar('Ошибка синхронизации Garmin: $errorMessage');
      }
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
          title: 'Garmin',
          backgroundColor: AppColors.twinBg,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const SizedBox(height: 16),

            // Кнопка Garmin
            Center(
              child: SizedBox(
                width: 260,
                height: 44,
                child: OutlinedButton(
                  onPressed: _checkingGarmin
                      ? null
                      : (_garminConnected ? _syncGarmin : _connectGarmin),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _garminConnected
                        ? AppColors.brandPrimary
                        : Colors.transparent,
                    foregroundColor: _garminConnected
                        ? Colors.white
                        : AppColors.textPrimary,
                    side: BorderSide(
                      color: _garminConnected
                          ? AppColors.brandPrimary
                          : AppColors.border,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _checkingGarmin
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CupertinoActivityIndicator(radius: 9),
                        )
                      : Text(
                          _garminConnected
                              ? 'Синк из Garmin'
                              : 'Подключить Garmin',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
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
