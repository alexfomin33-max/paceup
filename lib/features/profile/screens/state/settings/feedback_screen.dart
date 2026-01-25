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

/// Экран предложений по улучшению
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitted = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── проверка, заполнено ли поле
  bool get _isFormValid {
    return _textController.text.trim().isNotEmpty &&
        _textController.text.trim().length >= 10;
  }

  /// Отправка предложения
  Future<void> _submitFeedback() async {
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
        '/submit_feedback.php',
        body: {'user_id': userId, 'text': _textController.text.trim()},
      );

      if (!mounted) return;
      setState(() {
        _isSubmitted = true;
        _isSubmitting = false;
        _textController.clear();
      });
      // Показываем сообщение об успехе
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Спасибо за ваше предложение!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        appBar: const PaceAppBar(title: 'Предложения по улучшению',backgroundColor: AppColors.twinBg, elevation: 0, scrolledUnderElevation: 0, showBottomDivider: false,),
        body: GestureDetector(
          // Снимаем фокус при тапе вне поля ввода
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            top: false,
            bottom: false,
            child: _isSubmitted
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            size: 64,
                            color: AppColors.success,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Спасибо за ваше предложение!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h17w6.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Мы рассмотрим ваше предложение и учтём его при разработке новых функций.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            text: 'Отправить ещё',
                            onPressed: () {
                              setState(() {
                                _isSubmitted = false;
                              });
                            },
                          ),
                        ],
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
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                        // Информационная карточка
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceColor(context),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: AppColors.twinchip,
            width: 0.7,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.info,
                                    size: 20,
                                    color: AppColors.brandPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ваше мнение важно для нас',
                                    style: AppTextStyles.h14w6.copyWith(
                                      color: AppColors.getTextPrimaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Поделитесь своими идеями по улучшению приложения. Мы внимательно рассмотрим каждое предложение.',
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Заголовок поля ввода
                        Text(
                          'Ваше предложение',
                          style: AppTextStyles.h14w6.copyWith(
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Поле ввода предложения
                        TextFormField(
                          controller: _textController,
                          focusNode: _focusNode,
                          maxLines: 14,
                          minLines: 7,
                          textInputAction: TextInputAction.newline,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Опишите, что бы вы хотели улучшить или добавить в приложение...',
                            hintStyle: TextStyle(
                              color: AppColors.getTextPlaceholderColor(context),
                            ),
                            errorText: _error,
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
                              borderSide: const BorderSide(
                                color: AppColors.error,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.getSurfaceColor(context),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите ваше предложение';
                            }
                            if (value.trim().length < 10) {
                              return 'Минимум 10 символов';
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
                        // КНОПКА "ОТПРАВИТЬ"
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
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              elevation: 0,
                              child: InkWell(
                                onTap: _isFormValid && !_isSubmitting
                                    ? _submitFeedback
                                    : null,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                child: Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _isFormValid && !_isSubmitting
                                        ? AppColors.button
                                        : AppColors.button.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
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
                                            'Отправить',
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
