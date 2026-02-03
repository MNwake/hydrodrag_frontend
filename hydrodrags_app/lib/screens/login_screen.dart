import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_toggle.dart';
import '../services/auth_service.dart';
import '../services/error_handler_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _emailFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_emailFormKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final email = _emailController.text.trim();
      
      // First, try to authenticate with existing tokens
      final authenticated = await authService.tryAuthenticateWithExistingTokens(email);
      
      if (authenticated && mounted) {
        // Successfully authenticated with existing tokens
        // Navigate based on profile completion status
        if (authService.profileComplete) {
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          Navigator.of(context).pushReplacementNamed('/racer-profile');
        }
        return;
      }
      
      // No valid tokens, proceed with sending code
      await authService.requestVerificationCode(email);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeFormKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.verifyCode(_codeController.text.trim());
      if (success && mounted) {
        // Navigate based on profile completion status
        if (authService.profileComplete) {
          // Profile is complete, go to main screen
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          // Profile is not complete, go to profile screen
          Navigator.of(context).pushReplacementNamed('/racer-profile');
        }
      }
    }
  }

  Future<void> _resendCode() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final email = authService.email;
    if (email == null || email.isEmpty) {
      // No stored email (e.g. user navigated back and forth); go back to email step
      _reset();
      return;
    }
    _codeController.clear();
    await authService.requestVerificationCode(email);
  }

  void _reset() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.reset();
    _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Consumer<AuthService>(
                builder: (context, authService, child) {
                  final status = authService.status;

                  return Form(
                    key: status == AuthStatus.codeSent || status == AuthStatus.verifying
                        ? _codeFormKey
                        : _emailFormKey,
                    child: FocusTraversalGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        const SizedBox(height: 32),
                        
                        // Logo
                        Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // Title based on current step
                        if (status == AuthStatus.codeSent || status == AuthStatus.verifying) ...[
                          Text(
                            l10n.enterCode,
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.enterCodeSubtitle,
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (authService.email != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              authService.email!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ] else ...[
                          Text(
                            l10n.signIn,
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.signInSubtitle,
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                        
                        // Error message display
                        if (authService.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authService.errorMessage!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Success message (code sent)
                        if (status == AuthStatus.codeSent && authService.errorMessage == null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.codeSent,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Email input (step 1)
                        if (status == AuthStatus.unauthenticated) ...[
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _sendCode(),
                            decoration: InputDecoration(
                              labelText: l10n.email,
                              hintText: l10n.emailHint,
                              prefixIcon: const Icon(Icons.email),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.emailRequired;
                              }
                              if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                  .hasMatch(value.trim())) {
                                return l10n.invalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: authService.isLoading ? null : _sendCode,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: authService.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.sendCode),
                              ),
                            ),
                          ),
                        ],
                        
                        // Code input (step 2)
                        if (status == AuthStatus.codeSent || status == AuthStatus.verifying) ...[
                          TextFormField(
                            controller: _codeController,
                            focusNode: _codeFocusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.enterCode,
                              hintText: '123456',
                              prefixIcon: const Icon(Icons.lock_outline),
                              counterText: '',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.codeRequired;
                              }
                              if (value.length != 6) {
                                return l10n.invalidCode;
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (value.length == 6 && mounted) {
                                FocusScope.of(context).unfocus();
                              }
                            },
                            onFieldSubmitted: (_) => _verifyCode(),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: authService.isLoading ? null : _verifyCode,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: authService.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.verify),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.didntReceiveCode,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: authService.isLoading ? null : _resendCode,
                                child: Text(l10n.resendCode),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _reset,
                            child: Text(l10n.cancel),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: theme.colorScheme.outline)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                l10n.or,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: theme.colorScheme.outline)),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Continue as Spectator
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/main');
                          },
                          icon: const Icon(Icons.visibility),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(l10n.continueAsSpectator),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.viewEventsWithoutAccount,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  );
                },
              ),
            ),
            // Language toggle floating in top right
            Positioned(
              top: 8,
              right: 8,
              child: const LanguageToggle(isCompact: true),
            ),
          ],
        ),
      ),
    );
  }
}