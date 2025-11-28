// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE AVATAR SECTION
//
//  Секция редактирования аватара пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../providers/avatar_version_provider.dart';

/// Размер аватара по умолчанию
const double kEditProfileAvatarSize = 88.0;

/// ───────────────────────────── Редактируемый аватар ─────────────────────────────

/// Виджет аватара с возможностью редактирования
class EditProfileAvatarEditable extends ConsumerWidget {
  const EditProfileAvatarEditable({
    super.key,
    required this.bytes,
    required this.avatarUrl,
    required this.size,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String? avatarUrl;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (size * dpr).round();

    // Получаем текущую версию аватарки для cache-busting
    final avatarVersion = ref.watch(avatarVersionProvider);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: _buildAvatarImage(
              context: context,
              size: size,
              cacheWidth: cacheW,
              avatarVersion: avatarVersion,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getBorderColor(context),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                CupertinoIcons.camera,
                size: 16,
                color: AppColors.getIconPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage({
    required BuildContext context,
    required double size,
    required int cacheWidth,
    required int avatarVersion,
  }) {
    // 1) Выбранные байты (превью выбранного изображения)
    if (bytes != null && bytes!.isNotEmpty) {
      try {
        return Image.memory(
          bytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // НЕ используем cacheWidth/cacheHeight для Image.memory!
          // Они искажают пропорции, если оригинальное изображение не квадратное.
          // BoxFit.cover сам корректно обрежет изображение в квадрат 88×88.
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/avatar_0.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (error) {
        return Image.asset(
          'assets/avatar_0.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
    }

    // 2) URL - используем CachedNetworkImage для синхронизации с профилем и лентой
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      // Добавляем версию для cache-busting
      final separator = url.contains('?') ? '&' : '?';
      final versionedUrl = avatarVersion > 0
          ? '$url${separator}v=$avatarVersion'
          : url;

      final dpr = MediaQuery.of(context).devicePixelRatio;
      final w = (size * dpr).round();
      return CachedNetworkImage(
        imageUrl: versionedUrl,
        // НЕ передаем cacheManager - используется DefaultCacheManager с offline support
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: w,
        maxWidthDiskCache: w,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceMuted
              : AppColors.skeletonBase,
        ),
        errorWidget: (context, url, error) => Image.asset(
          'assets/avatar_0.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    // 3) Фолбэк-ассет
    return Image.asset(
      'assets/avatar_0.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

