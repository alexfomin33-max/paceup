import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/primary_button.dart';
import '../../../../../../core/utils/error_handler.dart';
import 'user_settings_provider.dart';

/// Экран редактирования email
class EditEmailScreen extends ConsumerStatefulWidget {
  final String currentEmail;
  const EditEmailScreen({super.key, required this.currentEmail});

  @override
  ConsumerState<EditEmailScreen> createState() => _EditEmailScreenState();
}

class _EditEmailScreenState extends ConsumerState<EditEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.currentEmail;
    _emailController.addListener(() {
      setState(() {
        _error = null; // Очищаем ошибку при изменении текста
      });
    });
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── проверка, заполнено ли поле
  bool get _isFormValid {
    return _emailController.text.trim().isNotEmpty;
  }

  /// Сохранение нового email
  Future<void> _saveEmail() async {
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
        body: {'user_id': userId, 'email': _emailController.text.trim()},
      );

      // Очищаем кеш и обновляем данные
      await clearUserSettingsCache();
      ref.invalidate(userSettingsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(_emailController.text.trim());
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
        appBar: const PaceAppBar(title: 'Почта'),
        body: GestureDetector(
          // Снимаем фокус при тапе вне поля ввода
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
                  // Поле ввода email
                  TextFormField(
                    controller: _emailController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      labelStyle: AppTextStyles.h14w4Sec.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      alignLabelWithHint: true,
                      hintText: 'example@mail.ru',
                      hintStyle: TextStyle(
                        color: AppColors.getTextPlaceholderColor(context),
                      ),
                      errorText: _error,
                      filled: true,
                      fillColor: AppColors.getBackgroundColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: AppColors.getBorderColor(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: AppColors.getBorderColor(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: AppColors.getBorderColor(context),
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                    onFieldSubmitted: (_) => _saveEmail(),
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
                      onPressed: _saveEmail,
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
}
