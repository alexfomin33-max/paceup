import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../service/api_service.dart';
import '../../../../../service/auth_service.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart';
import '../../../../../widgets/interactive_back_swipe.dart';

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
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.currentEmail;
    _emailController.addListener(() {
      setState(() {
        _error = null;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Сохранение нового email
  Future<void> _saveEmail() async {
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
          'email': _emailController.text.trim(),
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop(_emailController.text.trim());
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
        appBar: const PaceAppBar(title: 'E-mail'),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                // Поле ввода email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'example@mail.ru',
                    errorText: _error,
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
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
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

                const SizedBox(height: 24),

                // Кнопка сохранения
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      disabledBackgroundColor: AppColors.disabled,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Сохранить',
                            style: AppTextStyles.h16w6,
                          ),
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

