// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE FORM PANE
//
//  Основная форма редактирования профиля, объединяющая все секции
// ────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
  });

  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final VoidCallback onPickAvatar;

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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Секция личной информации
          EditProfilePersonalInfoSection(
            avatarUrl: avatarUrl,
            avatarBytes: avatarBytes,
            onPickAvatar: onPickAvatar,
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

