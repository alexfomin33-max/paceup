import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../core/services/garmin_sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ЭКРАН РЕДАКТИРОВАНИЯ НАСТРОЕК GARMIN
//  Поля: email (из БД), пароль (только ввод нового, скрыт, просмотр недоступен)
// ─────────────────────────────────────────────────────────────────────────────

class GarminEditScreen extends ConsumerStatefulWidget {
  const GarminEditScreen({super.key});

  @override
  ConsumerState<GarminEditScreen> createState() => _GarminEditScreenState();
}

class _GarminEditScreenState extends ConsumerState<GarminEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscurePassword = true;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
    _emailController.addListener(() {
      setState(() {
        _error = null; // Очищаем ошибку при изменении текста
      });
    });
    _passwordController.addListener(() {
      setState(() {
        _error = null;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ── проверка, заполнено ли поле email
  bool get _isFormValid {
    return _emailController.text.trim().isNotEmpty;
  }

  /// Загрузка сохранённого email с сервера (пароль не отдаётся)
  Future<void> _loadCredentials() async {
    try {
      final garminService = ref.read(garminSyncServiceProvider);
      final response = await garminService.getCredentials();

      if (!mounted) return;
      if (response['success'] == true && response['email'] != null) {
        _emailController.text = response['email'] as String;
        setState(() {
          _isLoading = false;
          _loadError = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _loadError =
              response['message'] as String? ?? 'Не удалось загрузить данные';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = ErrorHandler.format(e);
        });
      }
    }
  }

  /// Сохранение: email обязателен; пароль опционален (если введён — обновляем)
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    if (mounted) {
      setState(() {
        _isSaving = true;
        _error = null;
      });
    }

    try {
      final garminService = ref.read(garminSyncServiceProvider);
      final password = _passwordController.text.trim();
      final response = await garminService.updateCredentials(
        email: _emailController.text.trim(),
        password: password.isEmpty ? null : password,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (response['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = response['message'] as String? ?? 'Ошибка сохранения';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.format(e);
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'Настройки Garmin',
          backgroundColor: AppColors.twinBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          showBottomDivider: false,
        ),
        body: GestureDetector(
          // Снимаем фокус при тапе вне полей ввода
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            top: false,
            bottom: false,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText.rich(
                            TextSpan(
                              text: _loadError,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // ──────────────────────────────────────────────────────────────
                            // ПРОКРУЧИВАЕМЫЙ КОНТЕНТ
                            // ──────────────────────────────────────────────────────────────
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ─────────── Пояснение ───────────
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(AppRadius.md),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: const Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  CupertinoIcons.info_circle_fill,
                                                  color: AppColors.brandPrimary,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Данные синхронизации Garmin',
                                                  style: AppTextStyles.h14w6,
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'Измените email и/или введите новый пароль. '
                                              'Пароль хранится в зашифрованном виде и '
                                              'не отображается — можно только ввести новый.',
                                              style: AppTextStyles.h13w4,
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 24),

                                      // Поле ввода email
                                      TextFormField(
                                        controller: _emailController,
                                        focusNode: _emailFocusNode,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        textCapitalization: TextCapitalization.none,
                                        autocorrect: false,
                                        enabled: !_isSaving,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontFamily: 'Inter',
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'example@mail.ru',
                                          hintStyle: TextStyle(
                                            color: AppColors.getTextPlaceholderColor(context),
                                            fontSize: 15,
                                          ),
                                          errorText: _error,
                                          filled: true,
                                          fillColor: AppColors.getSurfaceColor(context),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 22,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            borderSide: const BorderSide(
                                              color: AppColors.twinchip,
                                              width: 0.7,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            borderSide: const BorderSide(
                                              color: AppColors.twinchip,
                                              width: 0.7,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            borderSide: const BorderSide(
                                              color: AppColors.twinchip,
                                              width: 0.7,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            borderSide: const BorderSide(color: AppColors.error),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Введите email';
                                          }
                                          final emailRegex = RegExp(
                                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                          );
                                          if (!emailRegex.hasMatch(value)) {
                                            return 'Некорректный формат email';
                                          }
                                          return null;
                                        },
                                        onFieldSubmitted: (_) {
                                          FocusScope.of(context).requestFocus(_passwordFocusNode);
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      // Поле нового пароля
                                      TextFormField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocusNode,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        textCapitalization: TextCapitalization.none,
                                        autocorrect: false,
                                        enabled: !_isSaving,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontFamily: 'Inter',
                                        ),
                                        onFieldSubmitted: (_) => _save(),
                                        decoration: InputDecoration(
                                          hintText: 'Пароль',
                                          hintStyle: TextStyle(
                                            color: AppColors.getTextPlaceholderColor(context),
                                            fontSize: 15,
                                          ),
                                          filled: true,
                                          fillColor: AppColors.getSurfaceColor(context),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 22,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? CupertinoIcons.eye_slash
                                                  : CupertinoIcons.eye,
                                              size: 18,
                                              color: AppColors.getIconSecondaryColor(context),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            borderSide: const BorderSide(
                                              color: AppColors.twinchip,
                                              width: 0.7,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            borderSide: const BorderSide(
                                              color: AppColors.twinchip,
                                              width: 0.7,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            borderSide: const BorderSide(
                                              color: AppColors.twinchip,
                                              width: 0.7,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.lg),
                                            borderSide: const BorderSide(color: AppColors.error),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 30),

                                      // Показываем ошибку, если есть
                                      if (_error != null)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 20),
                                          child: SelectableText.rich(
                                            TextSpan(
                                              text: _error!,
                                              style: const TextStyle(
                                                color: AppColors.error,
                                                fontSize: 14,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // ──────────────────────────────────────────────────────────────
                            // КНОПКА "СОХРАНИТЬ"
                            // ──────────────────────────────────────────────────────────────
                            SafeArea(
                              top: false,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: AppColors.twinBg,
                                ),
                                child: Material(
                                  color: _isFormValid && !_isSaving
                                      ? AppColors.button
                                      : AppColors.button.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                                  elevation: 0,
                                  child: InkWell(
                                    onTap: _isFormValid && !_isSaving ? _save : null,
                                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                                    child: Container(
                                      width: double.infinity,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: _isFormValid && !_isSaving
                                            ? AppColors.button
                                            : AppColors.button.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                                      ),
                                      child: Center(
                                        child: _isSaving
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    AppColors.surface,
                                                  ),
                                                ),
                                              )
                                            : const Text(
                                                'Сохранить',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.surface,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
