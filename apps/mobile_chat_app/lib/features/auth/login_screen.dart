import 'package:flutter/material.dart';
import '../chat/chat_screen.dart';
import 'auth_service.dart';
import 'github_oauth.dart';
import 'oauth_callback.dart';

/// Login screen with GitHub and Apple sign-in options.
///
/// GitHub sign-in is active; Apple sign-in is disabled and labelled
/// "Coming Soon" until the Apple Developer account is ready.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _AppLogo(),
                const SizedBox(height: 48),
                _GitHubSignInButton(
                  onSuccess: () => _onSignInSuccess(context),
                ),
                if (AuthService.getInjectedTestToken() != null) ...[
                  const SizedBox(height: 12),
                  _TestQuickLoginButton(
                    onSuccess: () => _onSignInSuccess(context),
                  ),
                ],
                const SizedBox(height: 16),
                const _AppleSignInButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSignInSuccess(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.layers_rounded,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Bricks',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
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
        widget.onSuccess();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub sign-in was not completed.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is GitHubOAuthException
          ? e.message
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
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _signIn,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.code),
        label: const Text('Continue with GitHub'),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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
      final testToken = AuthService.getInjectedTestToken();
      if (testToken == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test token missing. Pass BRICKS_TEST_TOKEN via --dart-define.',
            ),
          ),
        );
        return;
      }

      await AuthService.saveToken(testToken);
      widget.onSuccess();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _quickLogin,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bolt),
        label: const Text('Quick Login (Test)'),
      ),
    );
  }
}

/// Apple Sign In button – shown in a disabled state until the Apple
/// Developer account is provisioned.
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Coming Soon',
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.apple),
          label: const Text('Continue with Apple'),
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            disabledForegroundColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
