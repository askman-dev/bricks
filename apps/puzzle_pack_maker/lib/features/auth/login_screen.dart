import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../home/puzzle_pack_home_screen.dart';
import 'auth_service.dart';
import 'github_oauth.dart';
import 'oauth_callback.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.extension_rounded,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Puzzle Pack Maker',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to start building printable puzzle packs.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  _GitHubSignInButton(
                    onSuccess: () => _openHome(context),
                  ),
                  if (AuthService.getInjectedTestToken() != null) ...[
                    const SizedBox(height: 12),
                    _TestQuickLoginButton(onSuccess: () => _openHome(context)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const PuzzlePackHomeScreen(),
      ),
    );
  }
}

class _GitHubSignInButton extends StatefulWidget {
  const _GitHubSignInButton({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<_GitHubSignInButton> createState() => _GitHubSignInButtonState();
}

class _GitHubSignInButtonState extends State<_GitHubSignInButton> {
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final token = await performGitHubOAuth();
      if (token != null) {
        await AuthService.saveToken(token);
        if (mounted) widget.onSuccess();
      } else if (mounted && !kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub sign-in was not completed.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is GitHubOAuthException
          ? error.message
          : 'GitHub sign-in failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _signIn,
        icon: _isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.code_rounded),
        label: const Text('Continue with GitHub'),
      ),
    );
  }
}

class _TestQuickLoginButton extends StatefulWidget {
  const _TestQuickLoginButton({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<_TestQuickLoginButton> createState() => _TestQuickLoginButtonState();
}

class _TestQuickLoginButtonState extends State<_TestQuickLoginButton> {
  bool _isLoading = false;

  Future<void> _quickLogin() async {
    setState(() => _isLoading = true);
    try {
      final token = AuthService.getInjectedTestToken();
      if (token == null) return;
      await AuthService.saveToken(token);
      if (mounted) widget.onSuccess();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _quickLogin,
        icon: _isLoading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bolt_rounded),
        label: const Text('Quick Login (Test)'),
      ),
    );
  }
}
