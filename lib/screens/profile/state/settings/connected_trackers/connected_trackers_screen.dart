import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart'; // PaceAppBar
import '../../../../../widgets/interactive_back_swipe.dart'; // фуллскрин-свайп

class ConnectedTrackersScreen extends StatelessWidget {
  const ConnectedTrackersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PaceAppBar(title: 'Подключенные трекеры'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.waveform_path_ecg,
                  size: 56,
                  color: AppColors.brandPrimary,
                ),
                SizedBox(height: 16),
                Text(
                  'Подключенные трекеры (в разработке)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Здесь будут подключения Garmin, Polar, Suunto и др.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
