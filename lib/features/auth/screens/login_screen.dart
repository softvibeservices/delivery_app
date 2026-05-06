// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final error = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error == 'PENDING') {
      _showStatusDialog(
        title: 'Account Pending',
        message: 'Your account is pending admin approval.',
        icon: Icons.hourglass_empty,
        iconColor: Colors.orange,
        actionText: 'View Status',
        actionRoute: AppRoutes.pending,
      );
      return;
    }

    if (error == 'REJECTED') {
      _showStatusDialog(
        title: 'Account Rejected',
        message:
            'Your account has been rejected. Please contact the administrator.',
        icon: Icons.cancel,
        iconColor: Colors.red,
        actionText: 'OK',
      );
      return;
    }

    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }

    Navigator.pushNamed(context, AppRoutes.otp);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showStatusDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required String actionText,
    String? actionRoute,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 20))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (actionRoute != null) {
                Navigator.pushReplacementNamed(context, actionRoute);
              }
            },
            child: Text(
              actionText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Forgot Password ─────────────────────────────────────────────────────

  void _showForgotPasswordSheet(BuildContext context) {
    final emailCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: _ForgotPasswordSheet(
          emailController: emailCtrl,
          onSuccess: () {
            Navigator.pop(ctx);
            _showSnackBar('Password changed successfully! Please login.');
          },
          onError: (msg) {
            // Error is shown inside the sheet itself; nothing to do here.
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.icecream_outlined,
                        size: 36,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Welcome Back!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Login to manage your deliveries',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Email Address'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            context: context,
                            hintText: 'you@example.com',
                            prefixIcon: Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel('Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            context: context,
                            hintText: '••••••',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ── Forgot Password → bottom sheet ──────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showForgotPasswordSheet(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: primary.withValues(
                                alpha: 0.4,
                              ),
                              elevation: 2,
                              shadowColor: primary.withValues(alpha: 0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.register,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: primary,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final primary = Theme.of(context).primaryColor;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(
        prefixIcon,
        color: Colors.grey.shade600,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade500, width: 2),
      ),
    );
  }
}

// ── Forgot Password Bottom Sheet ───────────────────────────────────────────
//
// Two-step flow:
//   Step 1 — User enters email → calls forgotPassword() → gets partnerId back
//   Step 2 — User enters OTP + new password → calls changePassword()

class _ForgotPasswordSheet extends StatefulWidget {
  final TextEditingController emailController;
  final VoidCallback onSuccess;
  final void Function(String error) onError;

  const _ForgotPasswordSheet({
    required this.emailController,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  /// Returned by step 1; required by step 2.
  String? _partnerId;

  /// false = step 1 (email), true = step 2 (OTP + new password).
  bool _step2 = false;

  bool _obscureNewPassword = true;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // ── Step 1: send OTP to email ────────────────────────────────────────────

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final auth = context.read<AuthProvider>();
    final result = await auth.forgotPassword(
      email: widget.emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.error != null) {
      setState(() => _errorText = result.error);
      return;
    }

    // Move to step 2 and store partnerId for the next call.
    setState(() {
      _partnerId = result.partnerId;
      _step2 = true;
    });
  }

  // ── Step 2: verify OTP and set new password ──────────────────────────────

  Future<void> _submitChangePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_partnerId == null) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final auth = context.read<AuthProvider>();
    final error = await auth.changePassword(
      partnerId: _partnerId!,
      otp: _otpController.text.trim(),
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    // Success — close sheet and show snackbar on the login screen.
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle bar ────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Step indicator (only visible in step 2) ───────────────
            if (_step2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () => setState(() {
                                _step2 = false;
                                _errorText = null;
                                _otpController.clear();
                                _newPasswordController.clear();
                              }),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Title ─────────────────────────────────────────────────
            Text(
              _step2 ? 'Enter OTP & New Password' : 'Reset Password',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _step2
                  ? 'We sent a 6-digit OTP to ${widget.emailController.text.trim()}'
                  : "Enter your account email and we'll send you an OTP.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // ══════════════════════════════════════════════════════════
            // STEP 1 — Email field
            // ══════════════════════════════════════════════════════════
            if (!_step2) ...[
              TextFormField(
                controller: widget.emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitEmail(),
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                  final regex =
                      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!regex.hasMatch(v.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade400),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade500, width: 2),
                  ),
                ),
              ),
            ],

            // ══════════════════════════════════════════════════════════
            // STEP 2 — OTP + New password fields
            // ══════════════════════════════════════════════════════════
            if (_step2) ...[
              // OTP field
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().length != 6) {
                    return 'Enter the 6-digit OTP';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: '6-digit OTP',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.pin_outlined,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  counterText: '', // hide the "0/6" counter
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade400),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade500, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // New password field
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitChangePassword(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'New password',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _obscureNewPassword = !_obscureNewPassword,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade400),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade500, width: 2),
                  ),
                ),
              ),
            ],

            // ── Error text ────────────────────────────────────────────
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),

            // ── Submit button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_step2 ? _submitChangePassword : _submitEmail),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primary.withValues(alpha: 0.4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(_step2 ? 'Change Password' : 'Send OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared label widget ────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }
}