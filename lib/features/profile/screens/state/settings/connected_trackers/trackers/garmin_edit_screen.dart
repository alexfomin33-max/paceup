import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../core/widgets/primary_button.dart';
import '../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../core/services/garmin_sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ЭКРАН РЕДАКТИРОВАНИЯ НАСТРОЕК GARMIN
//  Поля: email (из БД), пароль (только ввод нового, скрыт, просмотр недоступен)
// ─────────────────────────────────────────────────────────────────────────────

class GarminEditScreen extends ConsumerStatefulWidget {
  const GarminEditScreen({super.key});

  @override
  ConsumerState<GarminEditScreen> createState() => _GarminEditScreenState();
}

class _GarminEditScreenState extends ConsumerState<GarminEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Загрузка сохранённого email с сервера (пароль не отдаётся)
  Future<void> _loadCredentials() async {
    try {
      final garminService = ref.read(garminSyncServiceProvider);
      final response = await garminService.getCredentials();

      if (!mounted) return;
      if (response['success'] == true && response['email'] != null) {
        _emailController.text = response['email'] as String;
        setState(() {
          _isLoading = false;
          _loadError = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _loadError =
              response['message'] as String? ?? 'Не удалось загрузить данные';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = ErrorHandler.format(e);
        });
      }
    }
  }

  /// Сохранение: email обязателен; пароль опционален (если введён — обновляем)
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final garminService = ref.read(garminSyncServiceProvider);
      final password = _passwordController.text.trim();
      final response = await garminService.updateCredentials(
        email: _emailController.text.trim(),
        password: password.isEmpty ? null : password,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (response['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      _showError(response['message'] as String? ?? 'Ошибка сохранения');
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError(ErrorHandler.format(e));
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Настройки Garmin'),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText.rich(
                          TextSpan(
                            text: _loadError,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ─────────── Пояснение ───────────
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: AppColors.border,
                                ),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.info_circle_fill,
                                        color: AppColors.brandPrimary,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Данные синхронизации Garmin',
                                        style: AppTextStyles.h14w6,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Измените email и/или введите новый пароль. '
                                    'Пароль хранится в зашифрованном виде и '
                                    'не отображается — можно только ввести новый.',
                                    style: AppTextStyles.h13w4,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ─────────── Email ───────────
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              textInputAction: TextInputAction.next,
                              enabled: !_isSaving,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'example@mail.com',
                                prefixIcon: const Icon(CupertinoIcons.mail),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Введите email';
                                }
                                if (!value.trim().contains('@')) {
                                  return 'Введите корректный email';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ─────────── Новый пароль (всегда скрыт, без показа) ───────────
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              enabled: !_isSaving,
                              onFieldSubmitted: (_) => _save(),
                              decoration: InputDecoration(
                                labelText: 'Новый пароль',
                                hintText:
                                    'Оставьте пустым, чтобы не менять пароль',
                                prefixIcon: const Icon(CupertinoIcons.lock),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            PrimaryButton(
                              text: _isSaving ? 'Сохранение…' : 'Сохранить',
                              onPressed: () {
                                if (!_isSaving) _save();
                              },
                              isLoading: _isSaving,
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
