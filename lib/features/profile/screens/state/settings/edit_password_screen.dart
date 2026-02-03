import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/utils/error_handler.dart';
import 'user_settings_provider.dart';

/// Экран редактирования пароля
class EditPasswordScreen extends ConsumerStatefulWidget {
  final bool hasPassword;
  const EditPasswordScreen({super.key, required this.hasPassword});

  @override
  ConsumerState<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends ConsumerState<EditPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _oldPasswordFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // ── добавляем слушатели для обновления состояния при изменении фокуса и текста
    _oldPasswordFocusNode.addListener(() => setState(() {}));
    _newPasswordFocusNode.addListener(() => setState(() {}));
    _confirmPasswordFocusNode.addListener(() => setState(() {}));
    _oldPasswordController.addListener(() {
      setState(() {
        _error = null; // Очищаем ошибку при изменении текста
      });
    });
    _newPasswordController.addListener(() {
      setState(() {
        _error = null;
      });
    });
    _confirmPasswordController.addListener(() {
      setState(() {
        _error = null;
      });
    });
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  // ── проверка, заполнены ли все обязательные поля
  bool get _isFormValid {
    final newPasswordFilled = _newPasswordController.text.trim().isNotEmpty;
    final confirmPasswordFilled = _confirmPasswordController.text
        .trim()
        .isNotEmpty;

    if (widget.hasPassword) {
      final oldPasswordFilled = _oldPasswordController.text.trim().isNotEmpty;
      return oldPasswordFilled && newPasswordFilled && confirmPasswordFilled;
    }

    return newPasswordFilled && confirmPasswordFilled;
  }

  /// Сохранение нового пароля
  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final authService = ref.read(authServiceProvider);
    final userId = await authService.getUserId();
    if (userId == null) {
      if (mounted) {
        setState(() {
          _error = 'Пользователь не авторизован';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSubmitting = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.post(
        '/update_user_settings.php',
        body: {
          'user_id': userId,
          'password': _newPasswordController.text,
          if (widget.hasPassword) 'old_password': _oldPasswordController.text,
        },
      );

      // Очищаем кеш и обновляем данные
      await clearUserSettingsCache();
      ref.invalidate(userSettingsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.format(error);
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(title: 'Пароль', backgroundColor: AppColors.twinBg, elevation: 0, scrolledUnderElevation: 0, showBottomDivider: false,),
        body: GestureDetector(
          // Снимаем фокус при тапе вне полей ввода
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Form(
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
                  // Поле старого пароля (если пароль уже установлен)
                  if (widget.hasPassword) ...[
                    _buildPasswordField(
                      controller: _oldPasswordController,
                      focusNode: _oldPasswordFocusNode,
                      labelText: 'Текущий пароль',
                      obscureText: _obscureOldPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureOldPassword = !_obscureOldPassword;
                        });
                      },
                      errorText: _error,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите текущий пароль';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Поле нового пароля
                  _buildPasswordField(
                    controller: _newPasswordController,
                    focusNode: _newPasswordFocusNode,
                    labelText: widget.hasPassword ? 'Новый пароль' : 'Пароль',
                    obscureText: _obscureNewPassword,
                    onToggleObscure: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите пароль';
                      }
                      if (value.length < 6) {
                        return 'Пароль должен содержать минимум 6 символов';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Поле подтверждения пароля
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocusNode,
                    labelText: 'Подтвердите пароль',
                    obscureText: _obscureConfirmPassword,
                    onToggleObscure: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _savePassword(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Подтвердите пароль';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Пароли не совпадают';
                      }
                      return null;
                    },
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
                        color: _isFormValid && !_isSubmitting
                            ? AppColors.button
                            : AppColors.button.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        elevation: 0,
                        child: InkWell(
                          onTap: _isFormValid && !_isSubmitting
                              ? _savePassword
                              : null,
                          borderRadius: BorderRadius.circular(AppRadius.xxl),
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _isFormValid && !_isSubmitting
                                  ? AppColors.button
                                  : AppColors.button.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(AppRadius.xxl),
                            ),
                            child: Center(
                              child: _isSubmitting
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

  // ── Вспомогательный метод для создания поля пароля с единым стилем
  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    TextInputAction textInputAction = TextInputAction.next,
    String? errorText,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      style: const TextStyle(
        fontSize: 15,
        fontFamily: 'Inter',
      ),
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        hintText: labelText,
        hintStyle: TextStyle(
          color: AppColors.getTextPlaceholderColor(context),
          fontSize: 15,
        ),
        errorText: errorText,
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 22,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
            size: 18,
            color: AppColors.getIconSecondaryColor(context),
          ),
          onPressed: onToggleObscure,
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
    );
  }
}
