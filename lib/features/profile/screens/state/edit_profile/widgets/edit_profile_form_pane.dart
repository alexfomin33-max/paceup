// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE FORM PANE
//
//  Основная форма редактирования профиля, объединяющая все секции
// ────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../../core/theme/app_theme.dart';
import 'edit_profile_personal_info_section.dart';
import 'edit_profile_physical_info_section.dart';

/// ───────────────────────────── Форма редактирования профиля ─────────────────────────────

/// Основная форма редактирования профиля
class EditProfileFormPane extends StatelessWidget {
  const EditProfileFormPane({
    super.key,
    required this.avatarUrl,
    required this.avatarBytes,
    required this.onPickAvatar,
    required this.isLoading,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.city,
    required this.height,
    required this.weight,
    required this.hrMax,
    required this.birthDate,
    required this.gender,
    required this.mainSport,
    required this.setBirthDate,
    required this.setGender,
    required this.setSport,
    required this.pickBirthDate,
    required this.cities,
    this.backgroundUrl,
    this.backgroundBytes,
    this.onPickBackground,
    this.onRemoveBackground,
    this.onCitySelected,
  });

  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final VoidCallback onPickAvatar;
  final bool isLoading;

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController nickname;
  final TextEditingController city;
  final TextEditingController height;
  final TextEditingController weight;
  final TextEditingController hrMax;

  final DateTime? birthDate;
  final String gender;
  final String mainSport;

  final void Function(DateTime) setBirthDate;
  final void Function(String) setGender;
  final void Function(String) setSport;

  final Future<void> Function() pickBirthDate;

  final List<String> cities;
  final void Function(String)? onCitySelected;

  final String? backgroundUrl;
  final Uint8List? backgroundBytes;
  final VoidCallback? onPickBackground;
  final VoidCallback? onRemoveBackground;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Фоновая картинка профиля
          if (onPickBackground != null)
            _BackgroundImageSection(
              backgroundUrl: backgroundUrl,
              backgroundBytes: backgroundBytes,
              onPick: onPickBackground!,
              onRemove: onRemoveBackground,
            ),
          if (onPickBackground != null) const SizedBox(height: 20),
          // Секция личной информации
          EditProfilePersonalInfoSection(
            avatarUrl: avatarUrl,
            avatarBytes: avatarBytes,
            onPickAvatar: onPickAvatar,
            isLoading: isLoading,
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            city: city,
            birthDate: birthDate,
            gender: gender,
            mainSport: mainSport,
            setBirthDate: setBirthDate,
            setGender: setGender,
            setSport: setSport,
            pickBirthDate: pickBirthDate,
            cities: cities,
            onCitySelected: onCitySelected,
          ),

          const SizedBox(height: 20),

          // Секция физических параметров
          EditProfilePhysicalInfoSection(
            height: height,
            weight: weight,
            hrMax: hrMax,
          ),
        ],
      ),
    );
  }
}

/// ───────────────────────────── Секция фоновой картинки ─────────────────────────────

/// Виджет для отображения и редактирования фоновой картинки профиля
class _BackgroundImageSection extends StatelessWidget {
  const _BackgroundImageSection({
    required this.backgroundUrl,
    required this.backgroundBytes,
    required this.onPick,
    this.onRemove,
  });

  final String? backgroundUrl;
  final Uint8List? backgroundBytes;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    // Фиксированная высота обложки профиля
    const calculatedHeight = 180.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Фоновая картинка или плейсхолдер
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: double.infinity,
            height: calculatedHeight,
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.twinBg,
                width: 0.7,
              ),
              // boxShadow: [
              //   BoxShadow(
              //     color: Theme.of(context).brightness == Brightness.dark
              //         ? AppColors.darkShadowSoft
              //         : AppColors.shadowSoft,
              //     offset: const Offset(0, 1),
              //     blurRadius: 1,
              //     spreadRadius: 0,
              //   ),
              // ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: backgroundBytes != null
                  ? Image.memory(
                      backgroundBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: calculatedHeight,
                      errorBuilder: (context, error, stackTrace) =>
                          const _Placeholder(height: calculatedHeight),
                    )
                  : backgroundUrl != null && backgroundUrl!.isNotEmpty
                  ? _CachedBackgroundImage(
                      url: backgroundUrl!,
                      height: calculatedHeight,
                    )
                  : const _Placeholder(height: calculatedHeight),
            ),
          ),
        ),
        // ── Кнопка удаления (если есть картинка)
        if (onRemove != null &&
            (backgroundBytes != null ||
                (backgroundUrl != null && backgroundUrl!.isNotEmpty)))
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 24,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Плейсхолдер для фоновой картинки
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      color: AppColors.getSurfaceColor(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.photo,
            size: 40,
            color: AppColors.getIconSecondaryColor(context),
          ),
          const SizedBox(height: 12),
          Text(
            'Нажмите, чтобы добавить фон профиля',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кэшированное фоновое изображение
class _CachedBackgroundImage extends StatelessWidget {
  const _CachedBackgroundImage({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetW = (screenW * dpr).round();
    final targetH = (height * dpr).round();

    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      memCacheWidth: targetW,
      memCacheHeight: targetH,
      maxWidthDiskCache: targetW,
      maxHeightDiskCache: targetH,
      placeholder: (context, imageUrl) => Container(
        width: double.infinity,
        height: height,
        color: AppColors.getBackgroundColor(context),
        child: Center(
          child: CupertinoActivityIndicator(
            radius: 10,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      ),
      errorWidget: (context, imageUrl, error) => _Placeholder(height: height),
    );
  }
}
