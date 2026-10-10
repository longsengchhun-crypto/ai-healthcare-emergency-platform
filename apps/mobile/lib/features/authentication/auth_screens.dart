import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/providers.dart';
import '../../core/theme/app_theme.dart';
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

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'HealthResponse',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = ref.watch(authControllerProvider).sessionExpired;
    return _AuthScaffold(
      title: 'Welcome back',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expired)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Your session expired. Please sign in again.'),
                ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: Validators.email,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
              TextButton(
                onPressed: () => context.push('/reset'),
                child: const Text('Forgot password?'),
              ),
              OutlinedButton(
                onPressed: () => context.push('/register'),
                child: const Text('Create an account'),
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
      setState(() => _error = 'Please accept the privacy notice to continue.');
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
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Create your account',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: Validators.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: Validators.email,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
            validator: Validators.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              helperText: 'At least 10 characters',
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I understand this app stores my profile and health information '
              'to provide its features, and that it is not a medical device.',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
        ],
      ),
    ),
  );
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

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (Validators.email(_email.text) != null) {
      setState(() => _message = 'Enter a valid email address.');
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
        _message = 'If an account exists for that address, reset instructions will be sent.';
      });
    } on AppException catch (e) {
      setState(() => _message = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (Validators.password(_password.text) != null ||
        _token.text.trim().isEmpty) {
      setState(
        () => _message =
            'Enter the reset code and a new password (10+ characters).',
      );
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
          const SnackBar(content: Text('Password updated. Please sign in.')),
        );
        context.go('/login');
      }
    } on AppException catch (e) {
      setState(() => _message = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Reset password',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _request,
          child: const Text('Send reset instructions'),
        ),
        if (_requested) ...[
          const SizedBox(height: 24),
          TextField(
            controller: _token,
            decoration: const InputDecoration(labelText: 'Reset code'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: const Text('Set new password'),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_message!),
          ),
      ],
    ),
  );
}
