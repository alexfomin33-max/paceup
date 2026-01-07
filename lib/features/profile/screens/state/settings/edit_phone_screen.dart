import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/primary_button.dart';
import '../../../../../../core/utils/error_handler.dart';
import 'package:mask_input_formatter/mask_input_formatter.dart';
import 'user_settings_provider.dart';

/// Экран редактирования телефона
class EditPhoneScreen extends ConsumerStatefulWidget {
  final String currentPhone;
  const EditPhoneScreen({super.key, required this.currentPhone});

  @override
  ConsumerState<EditPhoneScreen> createState() => _EditPhoneScreenState();
}

class _EditPhoneScreenState extends ConsumerState<EditPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();
  final _maskFormatter = MaskInputFormatter(mask: '+# (###) ###-##-##');
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentPhone;
    _phoneController.addListener(() {
      setState(() {
        _error = null; // Очищаем ошибку при изменении текста
      });
    });
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── проверка, заполнено ли поле
  bool get _isFormValid {
    return _phoneController.text.trim().isNotEmpty;
  }

  /// Сохранение нового телефона
  Future<void> _savePhone() async {
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
        body: {'user_id': userId, 'phone': _phoneController.text},
      );

      // Очищаем кеш и обновляем данные
      await clearUserSettingsCache();
      ref.invalidate(userSettingsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(_phoneController.text);
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
        appBar: const PaceAppBar(title: 'Телефон'),
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
                  // Поле ввода телефона
                  TextFormField(
                    controller: _phoneController,
                    focusNode: _focusNode,
                    inputFormatters: [_maskFormatter],
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: 'Телефон',
                      labelStyle: AppTextStyles.h14w4Sec.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      alignLabelWithHint: true,
                      hintText: '+7 (999) 123-45-67',
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
                        return 'Введите телефон';
                      }
                      // Убираем все нецифры для проверки
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 10) {
                        return 'Некорректный формат телефона';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _savePhone(),
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
                      onPressed: _savePhone,
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
