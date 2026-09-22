import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/config/app_config.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.register = false});
  final bool register;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _password = TextEditingController(),
      _phone = TextEditingController();
  bool _busy = false, _obscure = true;
  Object? _error;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .submit(
            register: widget.register,
            username: _username.text,
            password: _password.text,
            phone: _phone.text,
          );
      _password.clear();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(configProvider).isConfigured;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(28),
              shrinkWrap: true,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => ref.read(localeProvider.notifier).toggle(),
                    icon: const Icon(Icons.language),
                    label: Text(
                      context.t(context.strings.ar ? 'english' : 'arabic'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.spa_rounded,
                      color: AppColors.accent,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppConfig.brand,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  context.t('tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 36),
                Text(
                  context.t(widget.register ? 'register' : 'welcomeBack'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(widget.register ? 'registerHint' : 'loginHint'),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                if (!configured) AppCard(child: Text(context.t('setupHint'))),
                if (configured)
                  AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          if (widget.register) ...[
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: context.t('phone'),
                                prefixIcon: const Icon(Icons.phone_outlined),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? context.t('REQUIRED')
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _username,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: InputDecoration(
                              labelText: context.t('username'),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? context.t('REQUIRED')
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: [
                              widget.register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: context.t('password'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: context.t(
                                  _obscure ? 'showPassword' : 'hidePassword',
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? context.t('REQUIRED')
                                : null,
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  context.strings.error(_error!),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              label: context.t(
                                widget.register ? 'register' : 'login',
                              ),
                              busy: _busy,
                              onPressed: _submit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.go(
                          widget.register ? '/login' : '/register',
                        ),
                  child: Text(
                    context.t(
                      widget.register ? 'existingAccount' : 'newAccount',
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
