import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../service/api_service.dart';
import '../../../../../service/auth_service.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart';
import '../../../../../widgets/interactive_back_swipe.dart';
import '../../../../../widgets/primary_button.dart';

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
  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Сохранение нового пароля
  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }

      final api = ApiService();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const PaceAppBar(title: 'Пароль'),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                // Поле старого пароля (если пароль уже установлен)
                if (widget.hasPassword) ...[
                  TextFormField(
                    controller: _oldPasswordController,
                    obscureText: _obscureOldPassword,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Текущий пароль',
                      errorText: _error,
                      filled: true,
                      fillColor: AppColors.surface,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureOldPassword
                              ? CupertinoIcons.eye_slash
                              : CupertinoIcons.eye,
                          size: 18,
                          color: AppColors.iconSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureOldPassword = !_obscureOldPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(
                          color: AppColors.brandPrimary,
                          width: 0.7,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                    ),
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
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: widget.hasPassword ? 'Новый пароль' : 'Пароль',
                    hintText: 'Минимум 6 символов',
                    filled: true,
                    fillColor: AppColors.surface,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        size: 18,
                        color: AppColors.iconSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.brandPrimary,
                        width: 0.7,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                  ),
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
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Подтвердите пароль',
                    filled: true,
                    fillColor: AppColors.surface,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        size: 18,
                        color: AppColors.iconSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                        color: AppColors.brandPrimary,
                        width: 0.7,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Подтвердите пароль';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Пароли не совпадают';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _savePassword(),
                ),

                const SizedBox(height: 24),

                // Кнопка сохранения
                Center(
                  child: PrimaryButton(
                    text: 'Сохранить',
                    onPressed: _savePassword,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
