import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsPlaceholderScreen extends StatelessWidget {
  final String title;
  final String? note;
  const SettingsPlaceholderScreen({super.key, required this.title, this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.getSurfaceColor(context),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: AppColors.getIconPrimaryColor(context),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          splashRadius: 18,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: SizedBox(
            height: 0.5,
            child: ColoredBox(color: AppColors.getDividerColor(context)),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.cube_box,
                size: 56,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(height: 16),
              Text(
                '$title (в разработке)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 8),
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
