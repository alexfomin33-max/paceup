import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/primary_button.dart';
import '../../../../../../core/providers/form_state_provider.dart';
import '../../../../../../core/widgets/form_error_display.dart';

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

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Отправка предложения
  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final formNotifier = ref.read(formStateProvider.notifier);
    final authService = ref.read(authServiceProvider);
    final userId = await authService.getUserId();
    if (userId == null) {
      formNotifier.setError('Пользователь не авторизован');
      return;
    }

    final api = ref.read(apiServiceProvider);

    await formNotifier.submit(
      () async {
        await api.post(
          '/submit_feedback.php',
          body: {'user_id': userId, 'text': _textController.text.trim()},
        );
      },
      onSuccess: () {
        if (!mounted) return;
        setState(() {
          _isSubmitted = true;
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Предложения по улучшению'),
        body: GestureDetector(
          // Снимаем фокус при тапе вне поля ввода
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
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
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      children: [
                        // Информационная карточка
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceColor(context),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.getBorderColor(context),
                              width: 1,
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

                        // Поле ввода предложения
                        TextFormField(
                          controller: _textController,
                          focusNode: _focusNode,
                          maxLines: 10,
                          minLines: 6,
                          textInputAction: TextInputAction.newline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: 'Ваше предложение',
                            labelStyle: AppTextStyles.h14w4Sec.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                            hintText:
                                'Опишите, что бы вы хотели улучшить или добавить в приложение...',
                            hintStyle: TextStyle(
                              color: AppColors.getTextPlaceholderColor(context),
                            ),
                            errorText: formState.error,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: AppColors.getBorderColor(context),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: AppColors.getBorderColor(context),
                              ),
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
                        FormErrorDisplay(formState: formState),

                        // Кнопка отправки
                        Center(
                          child: PrimaryButton(
                            text: 'Отправить',
                            onPressed: _submitFeedback,
                            isLoading: formState.isSubmitting,
                            horizontalPadding: 60,
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
