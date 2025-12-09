import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/primary_button.dart';
import '../../../../../../core/utils/error_handler.dart';

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
      setState(() {
        _error = 'Пользователь не авторизован';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

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
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Пароль'),
        body: GestureDetector(
          // Снимаем фокус при тапе вне полей ввода
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
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

                  // Кнопка сохранения
                  Center(
                    child: PrimaryButton(
                      text: 'Сохранить',
                      onPressed: _savePassword,
                      isLoading: _isSubmitting,
                      enabled: _isFormValid && !_isSubmitting,
                      horizontalPadding: 68,
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
    // ── определяем, какой лейбл показывать
    final bool hasText = controller.text.trim().isNotEmpty;
    final bool isFocused = focusNode.hasFocus;
    final String dynamicLabelText = (hasText || isFocused)
        ? labelText
        : labelText; // для паролей можно оставить одинаковый текст

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: dynamicLabelText,
        labelStyle: AppTextStyles.h14w4Sec.copyWith(
          color: AppColors.getTextSecondaryColor(context),
        ),
        floatingLabelStyle: TextStyle(
          color: AppColors.getTextSecondaryColor(context),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        alignLabelWithHint: true,
        errorText: errorText,
        filled: true,
        fillColor: AppColors.getBackgroundColor(context),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
            size: 18,
            color: AppColors.getIconSecondaryColor(context),
          ),
          onPressed: onToggleObscure,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
