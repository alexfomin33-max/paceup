import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../service/api_service.dart';
import '../../../../../service/auth_service.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_bar.dart';
import '../../../../../widgets/interactive_back_swipe.dart';
import '../../../../../widgets/primary_button.dart';
import 'package:mask_input_formatter/mask_input_formatter.dart';

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
  final _maskFormatter = MaskInputFormatter(mask: '+# (###) ###-##-##');
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.currentPhone;
    _phoneController.addListener(() {
      setState(() {
        _error = null;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Сохранение нового телефона
  Future<void> _savePhone() async {
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
          'phone': _phoneController.text,
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop(_phoneController.text);
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
        appBar: const PaceAppBar(title: 'Телефон'),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                // Поле ввода телефона
                TextFormField(
                  controller: _phoneController,
                  inputFormatters: [_maskFormatter],
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+7 (999) 123-45-67',
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

                const SizedBox(height: 24),

                // Кнопка сохранения
                Center(
                  child: PrimaryButton(
                    text: 'Сохранить',
                    onPressed: _savePhone,
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

