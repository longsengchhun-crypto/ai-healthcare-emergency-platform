import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/kit.dart';
import '../../core/design/kit_extra.dart';
import '../../core/design/palette.dart';
import '../../core/errors/app_exception.dart';
import '../../core/i18n/language.dart';
import '../../core/network/providers.dart';
import 'auth_controller.dart';

/// Client-side validators. The server re-validates everything; these only give fast feedback.
class Validators {
  Validators._();

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Enter your email address';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Enter a password';
    if (value.length < 10) return 'Use at least 10 characters';
    return null;
  }

  static String? name(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Enter your full name' : null;

  static String? phone(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null; // optional
    return RegExp(r'^\+?[0-9 ()-]{6,32}$').hasMatch(value)
        ? null
        : 'Enter a valid phone number';
  }
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.back = false,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page + 4,
              Gap.lg,
              Gap.page + 4,
              Gap.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (back)
                        Tap(
                          onTap: () => context.pop(),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(Icons.arrow_back_rounded, color: p.ink),
                          ),
                        ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.ink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: p.paper,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'HealthResponse',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: p.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      LanguageToggle(
                        isKhmer: context.isKhmer,
                        onChanged: (c) => languageController.set(c),
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  Text(title, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 15.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_email.text.trim(), _password.text);
    } on AppException catch (e) {
      if (mounted)
        setState(
          () => _error = e.kind == ErrorKind.unauthorized
              ? context.t(
                  'អ៊ីមែល ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវ',
                  'Wrong email or password',
                )
              : describeError(e),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final expired = ref.watch(authControllerProvider).sessionExpired;
    return _AuthFrame(
      title: context.t('សូមស្វាគមន៍\nត្រឡប់មកវិញ', 'Welcome\nback'),
      subtitle: context.t(
        'ចូលគណនីដើម្បីមើលការណាត់ជួប និងកំណត់ត្រាសុខភាពរបស់អ្នក។',
        'Sign in to see your appointments and health records.',
      ),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expired)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.lg),
                  child: Notice(
                    context.t(
                      'សម័យកាលរបស់អ្នកបានផុតកំណត់ សូមចូលម្តងទៀត។',
                      'Your session expired. Please sign in again.',
                    ),
                    tone: Tone.amber,
                  ),
                ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: context.t('អ៊ីមែល', 'Email'),
                ),
                validator: (v) => Validators.email(v) == null
                    ? null
                    : context.t(
                        'សូមបញ្ចូលអ៊ីមែលឱ្យត្រឹមត្រូវ',
                        'Enter a valid email address',
                      ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: context.t('ពាក្យសម្ងាត់', 'Password'),
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? context.t('បង្ហាញ', 'Show')
                        : context.t('លាក់', 'Hide'),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? context.t('សូមបញ្ចូលពាក្យសម្ងាត់', 'Enter your password')
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: Gap.md),
                Notice(_error!, tone: Tone.red),
              ],
              const SizedBox(height: Gap.xl),
              PrimaryButton(
                label: context.t('ចូលគណនី', 'Sign in'),
                busy: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: Gap.sm),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/reset'),
                  child: Text(
                    context.t('ភ្លេចពាក្យសម្ងាត់?', 'Forgot password?'),
                    style: TextStyle(
                      color: p.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
              GhostButton(
                label: context.t('បង្កើតគណនីថ្មី', 'Create an account'),
                onPressed: () => context.push('/register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _accepted = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_accepted) {
      setState(
        () => _error = context.t(
          'សូមយល់ព្រមនឹងការជូនដំណឹងអំពីឯកជនភាពដើម្បីបន្ត។',
          'Please accept the privacy notice to continue.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            _name.text.trim(),
            _email.text.trim(),
            _password.text,
            _phone.text.trim(),
          );
      try {
        await ref
            .read(apiClientProvider)
            .post(
              '/consents',
              body: {'purpose': 'PRIVACY_NOTICE', 'granted': true},
            );
      } catch (_) {
        // Best effort: the checkbox gate already applied.
      }
      if (mounted) context.go('/');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return _AuthFrame(
      back: true,
      title: context.t('បង្កើតគណនី', 'Create your\naccount'),
      subtitle: context.t(
        'ចំណាយពេលតែមួយនាទី។ អ្នកអាចបំពេញព័ត៌មានសុខភាពនៅពេលក្រោយ។',
        'It takes a minute. You can add health details later.',
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: context.t('ឈ្មោះពេញ', 'Full name'),
              ),
              validator: (v) => Validators.name(v) == null
                  ? null
                  : context.t('សូមបញ្ចូលឈ្មោះរបស់អ្នក', 'Enter your full name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.t('អ៊ីមែល', 'Email'),
              ),
              validator: (v) => Validators.email(v) == null
                  ? null
                  : context.t(
                      'សូមបញ្ចូលអ៊ីមែលឱ្យត្រឹមត្រូវ',
                      'Enter a valid email address',
                    ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.t(
                  'ទូរស័ព្ទ (មិនចាំបាច់)',
                  'Phone (optional)',
                ),
              ),
              validator: (v) => Validators.phone(v) == null
                  ? null
                  : context.t(
                      'លេខទូរស័ព្ទមិនត្រឹមត្រូវ',
                      'Enter a valid phone number',
                    ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.t('ពាក្យសម្ងាត់', 'Password'),
                helperText: context.t(
                  'យ៉ាងតិច ១០ តួអក្សរ',
                  'At least 10 characters',
                ),
              ),
              validator: (v) => Validators.password(v) == null
                  ? null
                  : context.t(
                      'ត្រូវការយ៉ាងតិច ១០ តួអក្សរ',
                      'Use at least 10 characters',
                    ),
            ),
            const SizedBox(height: Gap.lg),
            Tap(
              onTap: () => setState(() => _accepted = !_accepted),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: _accepted ? p.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: _accepted ? p.ink : p.muted,
                        width: 1.6,
                      ),
                    ),
                    child: _accepted
                        ? Icon(Icons.check_rounded, size: 17, color: p.paper)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.t(
                        'ខ្ញុំយល់ថាកម្មវិធីនេះរក្សាទុកព័ត៌មានសុខភាពរបស់ខ្ញុំដើម្បីផ្តល់សេវា ហើយវាមិនមែនជាឧបករណ៍វេជ្ជសាស្ត្រទេ។',
                        'I understand this app stores my health information to provide its features, and that it is not a medical device.',
                      ),
                      style: TextStyle(color: p.inkSoft, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.md),
              Notice(_error!, tone: Tone.red),
            ],
            const SizedBox(height: Gap.xl),
            PrimaryButton(
              label: context.t('បង្កើតគណនី', 'Create account'),
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _requested = false;
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (Validators.email(_email.text) != null) {
      setState(() {
        _message = context.t(
          'សូមបញ្ចូលអ៊ីមែលឱ្យត្រឹមត្រូវ។',
          'Enter a valid email address.',
        );
        _isError = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/auth/password-reset',
            body: {'email': _email.text.trim()},
            skipAuth: true,
          );
      setState(() {
        _requested = true;
        _isError = false;
        _message = context.t(
          'ប្រសិនបើមានគណនីសម្រាប់អ៊ីមែលនេះ យើងនឹងផ្ញើកូដទៅអ្នក។ សូមពិនិត្យប្រអប់សំបុត្រ (និង Spam)។',
          'If an account exists for that address, we will email you a code. Check your inbox (and Spam).',
        );
      });
    } on AppException catch (e) {
      setState(() {
        _message = describeError(e);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (Validators.password(_password.text) != null ||
        _token.text.trim().isEmpty) {
      setState(() {
        _message = context.t(
          'សូមបញ្ចូលកូដ និងពាក្យសម្ងាត់ថ្មី (យ៉ាងតិច ១០ តួ)។',
          'Enter the code and a new password (10+ characters).',
        );
        _isError = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/auth/password-reset/confirm',
            body: {'token': _token.text.trim(), 'newPassword': _password.text},
            skipAuth: true,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'បានប្តូរពាក្យសម្ងាត់។ សូមចូលគណនី។',
                'Password updated. Please sign in.',
              ),
            ),
          ),
        );
        context.go('/login');
      }
    } on AppException catch (e) {
      setState(() {
        _message = describeError(e);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    back: true,
    title: context.t('កំណត់ពាក្យសម្ងាត់ឡើងវិញ', 'Reset your\npassword'),
    subtitle: context.t(
      'យើងនឹងផ្ញើកូដមួយទៅអ៊ីមែលរបស់អ្នក។',
      'We will email you a code to set a new one.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: context.t('អ៊ីមែល', 'Email')),
        ),
        const SizedBox(height: Gap.md),
        PrimaryButton(
          label: context.t('ផ្ញើកូដ', 'Send code'),
          busy: _busy && !_requested,
          onPressed: _request,
        ),
        if (_requested) ...[
          const SizedBox(height: Gap.xl),
          TextField(
            controller: _token,
            decoration: InputDecoration(
              labelText: context.t('កូដក្នុងអ៊ីមែល', 'Code from your email'),
            ),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.t('ពាក្យសម្ងាត់ថ្មី', 'New password'),
            ),
          ),
          const SizedBox(height: Gap.md),
          PrimaryButton(
            label: context.t('កំណត់ពាក្យសម្ងាត់ថ្មី', 'Set new password'),
            busy: _busy,
            onPressed: _confirm,
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: Gap.lg),
          Notice(_message!, tone: _isError ? Tone.red : Tone.teal),
        ],
      ],
    ),
  );
}
