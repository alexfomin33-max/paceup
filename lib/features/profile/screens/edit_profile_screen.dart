// lib/screens/profile/edit_profile_screen.dart
// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE SCREEN
//
//  Экран редактирования профиля пользователя
//  Декомпозирован на отдельные виджеты и провайдеры для улучшения читаемости
// ────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../providers/services/api_provider.dart';
import 'edit_profile/providers/edit_profile_provider.dart';
import 'edit_profile/providers/edit_profile_state.dart';
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
  
  // ── Список городов для автокомплита (загружается из БД)
  List<String> _cities = [];

  // Флаги для отслеживания, редактирует ли пользователь поля
  bool _isUserEditingFirstName = false;
  bool _isUserEditingLastName = false;
  bool _isUserEditingNickname = false;
  bool _isUserEditingCity = false;
  bool _isUserEditingHeight = false;
  bool _isUserEditingWeight = false;
  bool _isUserEditingHrMax = false;

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
      _loadCities();
      
      // Добавляем слушатели для обновления состояния провайдера при изменении
      // Делаем это после синхронизации, чтобы не вызывать обновления при инициализации
      final notifier = ref.read(editProfileProvider(widget.userId).notifier);
      
      _firstName.addListener(() {
        if (!_isUserEditingFirstName) return;
        notifier.updateFirstName(_firstName.text);
      });

      _lastName.addListener(() {
        if (!_isUserEditingLastName) return;
        notifier.updateLastName(_lastName.text);
      });

      _city.addListener(() {
        if (!_isUserEditingCity) return;
        notifier.updateCity(_city.text);
      });

      _nickname.addListener(() {
        if (!_isUserEditingNickname) return;
        notifier.updateNickname(_nickname.text);
      });

      _height.addListener(() {
        if (!_isUserEditingHeight) return;
        notifier.updateHeight(_height.text);
      });

      _weight.addListener(() {
        if (!_isUserEditingWeight) return;
        notifier.updateWeight(_weight.text);
      });

      _hrMax.addListener(() {
        if (!_isUserEditingHrMax) return;
        notifier.updateHrMax(_hrMax.text);
      });
      
      // После синхронизации включаем отслеживание изменений
      _isUserEditingFirstName = true;
      _isUserEditingLastName = true;
      _isUserEditingNickname = true;
      _isUserEditingCity = true;
      _isUserEditingHeight = true;
      _isUserEditingWeight = true;
      _isUserEditingHrMax = true;
    });
  }
  
  /// Загрузка списка городов из БД через API
  Future<void> _loadCities() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api
          .get('/get_cities.php')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'Превышено время ожидания загрузки городов',
              );
            },
          );

      if (data['success'] == true && data['cities'] != null) {
        final cities = data['cities'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _cities = cities.map((city) => city.toString()).toList();
          });
        }
      }
    } catch (e) {
      // В случае ошибки оставляем пустой список
    }
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
    // Временно отключаем отслеживание изменений при синхронизации
    _isUserEditingFirstName = false;
    _isUserEditingLastName = false;
    _isUserEditingNickname = false;
    _isUserEditingCity = false;
    _isUserEditingHeight = false;
    _isUserEditingWeight = false;
    _isUserEditingHrMax = false;
    
    _firstName.text = state.firstName;
    _lastName.text = state.lastName;
    _nickname.text = state.nickname;
    _city.text = state.city;
    _height.text = state.height;
    _weight.text = state.weight;
    _hrMax.text = state.hrMax;
    
    // Включаем отслеживание обратно
    _isUserEditingFirstName = true;
    _isUserEditingLastName = true;
    _isUserEditingNickname = true;
    _isUserEditingCity = true;
    _isUserEditingHeight = true;
    _isUserEditingWeight = true;
    _isUserEditingHrMax = true;
  }

  /// Сохранение профиля
  Future<void> _onSave() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;
    FocusScope.of(context).unfocus();

    // Проверяем, что город выбран из списка
    final cityText = _city.text.trim();
    if (cityText.isNotEmpty && !_cities.contains(cityText)) {
      // Город не найден в списке - очищаем поле
      _city.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите город из списка'),
        ),
      );
      return;
    }

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

    // Слушаем изменения состояния провайдера и синхронизируем контроллеры
    // когда данные загружаются из API
    ref.listen<EditProfileState>(editProfileProvider(widget.userId), (previous, next) {
      // Синхронизируем контроллеры только если данные действительно изменились
      // Используем addPostFrameCallback чтобы избежать проблем во время билда
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        // Проверяем, есть ли активный фокус на любом поле
        final hasActiveFocus = FocusScope.of(context).focusedChild != null;
        
        // При первой загрузке данных (previous == null) синхронизируем все поля
        // независимо от фокуса, чтобы гарантировать установку значений из API
        final isFirstLoad = previous == null;
        
        // Синхронизируем контроллеры только если нет активного фокуса
        // или если это первая загрузка данных (previous == null)
        // Также проверяем, что значение действительно отличается от текущего
        if (isFirstLoad || !hasActiveFocus) {
          if (next.firstName != _firstName.text) {
            _isUserEditingFirstName = false;
            _firstName.text = next.firstName;
            _isUserEditingFirstName = true;
          }
          if (next.lastName != _lastName.text) {
            _isUserEditingLastName = false;
            _lastName.text = next.lastName;
            _isUserEditingLastName = true;
          }
          if (next.nickname != _nickname.text) {
            _isUserEditingNickname = false;
            _nickname.text = next.nickname;
            _isUserEditingNickname = true;
          }
          // Для города всегда синхронизируем при первой загрузке или если значение изменилось
          if (isFirstLoad || next.city != _city.text) {
            _isUserEditingCity = false;
            _city.text = next.city;
            _isUserEditingCity = true;
          }
          if (next.height != _height.text) {
            _isUserEditingHeight = false;
            _height.text = next.height;
            _isUserEditingHeight = true;
          }
          if (next.weight != _weight.text) {
            _isUserEditingWeight = false;
            _weight.text = next.weight;
            _isUserEditingWeight = true;
          }
          if (next.hrMax != _hrMax.text) {
            _isUserEditingHrMax = false;
            _hrMax.text = next.hrMax;
            _isUserEditingHrMax = true;
          }
        }
      });
    });

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
      cities: _cities,
      onCitySelected: (city) {
        // Обновляем состояние провайдера при выборе города
        notifier.updateCity(city);
      },
      backgroundUrl: profileState.backgroundUrl,
      backgroundBytes: profileState.backgroundBytes,
      onPickBackground: () => notifier.pickBackground(context),
      onRemoveBackground: () => notifier.updateBackgroundBytes(null),
    );
  }
}
