import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../service/api_service.dart';
import '../../../../../service/auth_service.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart';
import '../../../../../widgets/interactive_back_swipe.dart';
import '../../../../../widgets/primary_button.dart';

/// Экран предложений по улучшению
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Отправка предложения
  Future<void> _submitFeedback() async {
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
        '/submit_feedback.php',
        body: {
          'user_id': userId,
          'text': _textController.text.trim(),
        },
      );

      if (!mounted) return;

      setState(() {
        _isSubmitted = true;
        _isLoading = false;
        _textController.clear();
      });

      // Показываем сообщение об успехе
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Спасибо за ваше предложение!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
        appBar: const PaceAppBar(title: 'Предложения по улучшению'),
        body: SafeArea(
          child: _isSubmitted
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: 64,
                          color: AppColors.success,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Спасибо за ваше предложение!',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h17w6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Мы рассмотрим ваше предложение и учтём его при разработке новых функций.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h14w4.copyWith(
                            color: AppColors.textSecondary,
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.info,
                                  size: 20,
                                  color: AppColors.brandPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ваше мнение важно для нас',
                                  style: AppTextStyles.h14w6,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Поделитесь своими идеями по улучшению приложения. Мы внимательно рассмотрим каждое предложение.',
                              style: AppTextStyles.h14w4.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Поле ввода предложения
                      TextFormField(
                        controller: _textController,
                        maxLines: 10,
                        minLines: 6,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Ваше предложение',
                          hintText:
                              'Опишите, что бы вы хотели улучшить или добавить в приложение...',
                          errorText: _error,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.brandPrimary,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
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

                      const SizedBox(height: 24),

                      // Кнопка отправки
                      Center(
                        child: PrimaryButton(
                          text: 'Отправить',
                          onPressed: _submitFeedback,
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

