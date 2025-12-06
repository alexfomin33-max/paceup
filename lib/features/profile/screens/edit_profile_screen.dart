// lib/screens/profile/edit_profile_screen.dart
// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE SCREEN
//
//  Экран редактирования профиля пользователя
//  Декомпозирован на отдельные виджеты и провайдеры для улучшения читаемости
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../core/providers/form_state_provider.dart';
import 'edit_profile/providers/edit_profile_provider.dart';
import 'edit_profile/widgets/edit_profile_states.dart';
import 'edit_profile/widgets/edit_profile_form_pane.dart';

/// Экран редактирования профиля
class EditProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // Контроллеры для полей формы
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _nickname;
  late final TextEditingController _city;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _hrMax;
  // ── отдельный фокус для пикера даты рождения, чтобы не возвращалась клавиатура
  final _pickerFocusNode = FocusNode(debugLabel: 'editProfilePickerFocus');

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _nickname = TextEditingController();
    _city = TextEditingController();
    _height = TextEditingController();
    _weight = TextEditingController();
    _hrMax = TextEditingController();

    // Синхронизируем контроллеры с состоянием после первого билда
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncControllersWithState();
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nickname.dispose();
    _city.dispose();
    _height.dispose();
    _weight.dispose();
    _hrMax.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
  }

  /// Синхронизация контроллеров с состоянием из провайдера
  void _syncControllersWithState() {
    final state = ref.read(editProfileProvider(widget.userId));
    _firstName.text = state.firstName;
    _lastName.text = state.lastName;
    _nickname.text = state.nickname;
    _city.text = state.city;
    _height.text = state.height;
    _weight.text = state.weight;
    _hrMax.text = state.hrMax;
  }

  /// Сохранение профиля
  Future<void> _onSave() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(editProfileProvider(widget.userId).notifier);

    // Обновляем состояние из контроллеров перед сохранением
    notifier.updateFirstName(_firstName.text);
    notifier.updateLastName(_lastName.text);
    notifier.updateNickname(_nickname.text);
    notifier.updateCity(_city.text);
    notifier.updateHeight(_height.text);
    notifier.updateWeight(_weight.text);
    notifier.updateHrMax(_hrMax.text);

    await notifier.save();

    if (!mounted) return;

    // Если сохранение успешно, закрываем экран
    final currentFormState = ref.read(formStateProvider);
    if (!currentFormState.isSubmitting && currentFormState.error == null) {
      Navigator.of(context).maybePop(true);
    } else if (currentFormState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить: ${currentFormState.error}'),
        ),
      );
    }
  }

  /// Показ пикера даты рождения
  Future<void> _pickBirthDate() async {
    _unfocusKeyboard();
    final state = ref.read(editProfileProvider(widget.userId));
    final notifier = ref.read(editProfileProvider(widget.userId).notifier);
    final initial = state.birthDate ?? DateTime(1990, 1, 1);

    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        return Container(
          height: 260 + bottom,
          color: AppColors.getSurfaceColor(context),
          child: SafeArea(
            top: false,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: initial,
              maximumYear: DateTime.now().year,
              minimumYear: 1900,
              onDateTimeChanged: (d) {
                notifier.updateBirthDate(d);
              },
            ),
          ),
        );
      },
    );
  }

  // ── снимаем фокус перед показом пикера, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(editProfileProvider(widget.userId));
    final formState = ref.watch(formStateProvider);
    final notifier = ref.read(editProfileProvider(widget.userId).notifier);

    // Синхронизируем контроллеры при изменении состояния
    if (profileState.firstName != _firstName.text) {
      _firstName.text = profileState.firstName;
    }
    if (profileState.lastName != _lastName.text) {
      _lastName.text = profileState.lastName;
    }
    if (profileState.nickname != _nickname.text) {
      _nickname.text = profileState.nickname;
    }
    if (profileState.city != _city.text) {
      _city.text = profileState.city;
    }
    if (profileState.height != _height.text) {
      _height.text = profileState.height;
    }
    if (profileState.weight != _weight.text) {
      _weight.text = profileState.weight;
    }
    if (profileState.hrMax != _hrMax.text) {
      _hrMax.text = profileState.hrMax;
    }

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          title: 'Профиль',
          actions: [
            TextButton(
              onPressed: formState.isSubmitting || formState.isLoading
                  ? null
                  : _onSave,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: formState.isSubmitting
                  ? const CupertinoActivityIndicator(radius: 8)
                  : const Text('Сохранить'),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: _buildBody(profileState, notifier),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(dynamic profileState, dynamic notifier) {
    final formState = ref.watch(formStateProvider);

    if (formState.isLoading) {
      return const EditProfileLoadingPane(key: ValueKey('loading'));
    }

    if (profileState.loadError != null) {
      return EditProfileErrorPane(
        key: const ValueKey('error'),
        message: profileState.loadError!,
        onRetry: () => notifier.loadProfile(),
      );
    }

    return EditProfileFormPane(
      key: const ValueKey('form'),
      avatarUrl: profileState.avatarUrl,
      avatarBytes: profileState.avatarBytes,
      onPickAvatar: () => notifier.pickAvatar(context),
      isLoading: formState.isLoading,
      firstName: _firstName,
      lastName: _lastName,
      nickname: _nickname,
      city: _city,
      height: _height,
      weight: _weight,
      hrMax: _hrMax,
      birthDate: profileState.birthDate,
      gender: profileState.gender,
      mainSport: profileState.mainSport,
      setBirthDate: (d) => notifier.updateBirthDate(d),
      setGender: (g) => notifier.updateGender(g),
      setSport: (s) => notifier.updateMainSport(s),
      pickBirthDate: _pickBirthDate,
    );
  }
}
