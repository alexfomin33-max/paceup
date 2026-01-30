import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/services/sync_provider_service.dart';
import '../../../../../../providers/services/api_provider.dart';
import 'trackers/health_connect_screen.dart';
import 'trackers/garmin_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ЭКРАН «ПОДКЛЮЧЕННЫЕ ТРЕКЕРЫ»
// ─────────────────────────────────────────────────────────────────────────────

class ConnectedTrackersScreen extends ConsumerStatefulWidget {
  const ConnectedTrackersScreen({super.key});

  @override
  ConsumerState<ConnectedTrackersScreen> createState() =>
      _ConnectedTrackersScreenState();
}

class _ConnectedTrackersScreenState
    extends ConsumerState<ConnectedTrackersScreen> {
  // ───────── Состояние ─────────
  String? _syncProvider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSyncProvider();
  }

  /// 🔹 Загрузка текущего способа синхронизации
  Future<void> _loadSyncProvider() async {
    try {
      final syncProviderService = ref.read(syncProviderServiceProvider);
      final provider = await syncProviderService.getSyncProvider();
      
      if (mounted) {
        setState(() {
          _syncProvider = provider;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 🔹 Получение названия трекера по sync_provider
  String? _getTrackerName(String? provider) {
    switch (provider) {
      case 'health_connect':
        return 'Health Connect';
      case 'apple_health':
        return 'Apple Health';
      case 'garmin':
        return 'Garmin';
      case 'coros':
        return 'Coros';
      case 'suunto':
        return 'SUUNTO';
      case 'polar':
        return 'Polar';
      default:
        return null;
    }
  }

  /// 🔹 Получение списка всех доступных трекеров
  List<_TrackerInfo> _getAvailableTrackers() {
    final allTrackers = <_TrackerInfo>[
      // Health Connect только на Android
      if (Platform.isAndroid)
        _TrackerInfo(
          id: 'health_connect',
          title: 'Health Connect',
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => const HealthConnectScreen(),
              ),
            );
          },
        ),
      // Apple Health только на iOS
      if (Platform.isIOS)
        _TrackerInfo(
          id: 'apple_health',
          title: 'Apple Health',
          onTap: () {
            // TODO: Реализовать экран Apple Health
          },
        ),
      _TrackerInfo(
        id: 'garmin',
        title: 'Garmin',
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => const GarminScreen(),
            ),
          );
        },
      ),
      _TrackerInfo(
        id: 'coros',
        title: 'Coros',
        onTap: () {
          // TODO: Реализовать экран Coros
        },
      ),
      _TrackerInfo(
        id: 'suunto',
        title: 'SUUNTO',
        onTap: () {
          // TODO: Реализовать экран SUUNTO
        },
      ),
      _TrackerInfo(
        id: 'polar',
        title: 'Polar',
        onTap: () {
          // TODO: Реализовать экран Polar
        },
      ),
    ];

    // Фильтруем: убираем уже подключенный трекер
    return allTrackers
        .where((tracker) => tracker.id != _syncProvider)
        .toList();
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'Трекеры',
          backgroundColor: AppColors.twinBg,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  // Заголовок «Подключенные»
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 12),
                    child: Text(
                      'Подключенные',
                      style: AppTextStyles.h15w6,
                    ),
                  ),

                  // Подключенный трекер или сообщение об отсутствии
                  if (_syncProvider != null)
                    _ConnectedTrackerTile(
                      title: _getTrackerName(_syncProvider) ?? 'Трекер',
                    )
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
                      ),
                      child: const Text(
                        'Вы ещё не подключили ни один трекер',
                        style: AppTextStyles.h13w4,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Заголовок «Доступные»
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Доступные',
                      style: AppTextStyles.h15w6,
                    ),
                  ),

                  // Список доступных трекеров
                  ..._getAvailableTrackers()
                      .map(
                        (tracker) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TrackerTile(
                            title: tracker.title,
                            onTap: tracker.onTap,
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
      ),
    );
  }
}

/// Информация о трекере
class _TrackerInfo {
  const _TrackerInfo({
    required this.id,
    required this.title,
    required this.onTap,
  });

  final String id;
  final String title;
  final VoidCallback onTap;
}

/// Карточка подключенного трекера
class _ConnectedTrackerTile extends StatelessWidget {
  const _ConnectedTrackerTile({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.twinchip,
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h15w5,
            ),
          ),
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 20,
            color: AppColors.brandPrimary,
          ),
        ],
      ),
    );
  }
}

/// Карточка трекера в списке доступных
class _TrackerTile extends StatelessWidget {
  const _TrackerTile({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16,22,16,22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.twinchip,
                          width: 0.7,),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h15w5,
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
