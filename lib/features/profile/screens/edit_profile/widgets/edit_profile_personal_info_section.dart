// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE PERSONAL INFO SECTION
//
//  Секция личной информации (имя, фамилия, никнейм, дата рождения, пол, город, спорт)
// ────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'edit_profile_form_fields.dart';
import 'edit_profile_avatar_section.dart';
import 'edit_profile_avatar_section.dart' as avatar;
import '../../../../../core/theme/app_theme.dart';
import '../../../../leaderboard/widgets/city_autocomplete_field.dart';

/// ───────────────────────────── Секция личной информации ─────────────────────────────

/// Секция формы с личной информацией пользователя
class EditProfilePersonalInfoSection extends StatelessWidget {
  const EditProfilePersonalInfoSection({
    super.key,
    required this.avatarUrl,
    required this.avatarBytes,
    required this.onPickAvatar,
    required this.isLoading,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.city,
    required this.birthDate,
    required this.gender,
    required this.mainSport,
    required this.setBirthDate,
    required this.setGender,
    required this.setSport,
    required this.pickBirthDate,
    required this.cities,
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

  final DateTime? birthDate;
  final String gender;
  final String mainSport;

  final void Function(DateTime) setBirthDate;
  final void Function(String) setGender;
  final void Function(String) setSport;

  final Future<void> Function() pickBirthDate;
  
  final List<String> cities;
  final void Function(String)? onCitySelected;

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Шапка: аватар + Имя/Фамилия + QR ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar.EditProfileAvatarEditable(
              bytes: avatarBytes,
              avatarUrl: avatarUrl,
              size: kEditProfileAvatarSize,
              onTap: onPickAvatar,
              isLoading: isLoading,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditProfileNameBlock(
                firstController: firstName,
                secondController: lastName,
                firstHint: 'Имя',
                secondHint: 'Фамилия',
              ),
            ),
            const SizedBox(width: 12),
            EditProfileCircleIconBtn(
              icon: CupertinoIcons.qrcode_viewfinder,
              onTap: () {},
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Блок личной информации ──
        EditProfileGroupBlock(
          children: [
            EditProfileFieldRow.input(
              label: 'Никнейм',
              controller: nickname,
              hint: 'nickname',
            ),
            EditProfileFieldRow.picker(
              label: 'Дата рождения',
              value: _formatDate(birthDate),
              onTap: pickBirthDate,
            ),
            EditProfileFieldRow.dropdown(
              label: 'Пол',
              value: gender.isEmpty ? null : gender,
              items: const ['Мужской', 'Женский'],
              onChanged: setGender,
            ),
            // ── Поле города с автокомплитом
            SizedBox(
              height: 50,
              child: Row(
                children: [
                  SizedBox(
                    width: kEditProfileLabelWidth,
                    child: Text(
                      'Город',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondaryColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CityAutocompleteField(
                      controller: city,
                      suggestions: cities,
                      hintText: 'Город',
                      onSelected: (selectedCity) {
                        city.text = selectedCity;
                        if (onCitySelected != null) {
                          onCitySelected!(selectedCity);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            EditProfileFieldRow.dropdown(
              label: 'Основной вид спорта',
              value: mainSport.isEmpty ? null : mainSport,
              items: const ['Бег', 'Велоспорт', 'Плавание', 'Лыжи'],
              onChanged: setSport,
            ),
          ],
        ),
      ],
    );
  }
}
