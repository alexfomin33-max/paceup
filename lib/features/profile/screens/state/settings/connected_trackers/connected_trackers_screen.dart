import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
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
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // Заголовок «Подключенные»
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Text(
                'Подключенные',
                style: AppTextStyles.h16w6,
              ),
            ),

            // Сообщение о том, что трекеры не подключены
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Text(
                'Вы ещё не подключили ни один трекер',
                style: AppTextStyles.h13w4,
              ),
            ),

            const SizedBox(height: 24),

            // Заголовок «Доступные»
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Доступные',
                style: AppTextStyles.h16w6,
              ),
            ),

            // Список доступных трекеров
            _TrackerTile(
              title: 'Health Connect',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HealthConnectScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _TrackerTile(
              title: 'Garmin',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GarminScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _TrackerTile(
              title: 'Coros',
              onTap: () {
                // TODO: Реализовать экран Coros
              },
            ),
            const SizedBox(height: 8),
            _TrackerTile(
              title: 'SUUNTO',
              onTap: () {
                // TODO: Реализовать экран SUUNTO
              },
            ),
            const SizedBox(height: 8),
            _TrackerTile(
              title: 'Polar',
              onTap: () {
                // TODO: Реализовать экран Polar
              },
            ),
          ],
        ),
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 1),
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
