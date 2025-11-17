// lib/screens/profile/tabs/equipment/editing/editing_equipment_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import 'tabs/editing_sneakers_content.dart';
import 'tabs/editing_bike_content.dart';

/// Экран «Редактирование снаряжения»
class EditingEquipmentScreen extends StatelessWidget {
  /// ID записи в equip_user
  final int equipUserId;
  /// Тип снаряжения: 'boots' или 'bike'
  final String type;

  const EditingEquipmentScreen({
    super.key,
    required this.equipUserId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        centerTitle: true,
        title: const Text(
          'Редактирование снаряжения',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leadingWidth: 52,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.iconPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: type == 'bike'
              ? EditingBikeContent(
                  equipUserId: equipUserId,
                )
              : EditingSneakersContent(
                  equipUserId: equipUserId,
                ),
        ),
      ),
    );
  }
}

