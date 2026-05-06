// lib/features/auth/screens/otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../config/constants.dart';
import '../../../config/routes.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    AppConstants.otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    AppConstants.otpLength,
    (_) => FocusNode(),
  );

  int _secondsLeft = AppConstants.otpResendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConstants.otpResendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
        if (mounted) setState(() {});
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _controllers.map((e) => e.text).join();

    if (otp.length != AppConstants.otpLength) {
      _showSnackBar('Please enter the complete OTP', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final error = await auth.verifyOtp(otp: otp);

    if (!mounted) return;

    if (error != null) {
      _showSnackBar(error, isError: true);
      _clearOtp();
      return;
    }

    switch (auth.status) {
      case AuthStatus.authenticated:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.main,
          (_) => false,
        );
        break;
      case AuthStatus.pending:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.pending,
          (_) => false,
        );
        break;
      default:
        _showSnackBar('Account rejected. Contact admin.', isError: true);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        );
    }
  }

  // ── Resend OTP with improved error handling ──────────────────────────────

  Future<void> _resendOtp() async {
    final auth = context.read<AuthProvider>();

    // Guard: if there's no active session, redirect to login immediately
    if (auth.partnerId == null) {
      _showSnackBar(
        'Session expired. Please login again.',
        isError: true,
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
      return;
    }

    _showSnackBar('Sending new OTP...');

    final error = await auth.resendOtp();

    if (!mounted) return;

    if (error != null) {
      _showSnackBar(error, isError: true);

      // If the session is fully expired, bounce back to login after a brief delay
      if (error.toLowerCase().contains('session expired') ||
          error.toLowerCase().contains('login again')) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      }
      return;
    }

    _startTimer();
    _clearOtp();
    _showSnackBar('New OTP sent to your email');
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < AppConstants.otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
  }

  void _onOtpKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace &&
          _controllers[index].text.isEmpty &&
          index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
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
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 36,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verification Code',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit code to your email',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // OTP Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      AppConstants.otpLength,
                      (i) => _OtpBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        onChanged: (v) => _onOtpChanged(i, v),
                        onKeyEvent: (e) => _onOtpKeyEvent(i, e),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Timer / Resend
                  if (_secondsLeft > 0)
                    Text(
                      'Resend OTP in $_secondsLeft sec',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: isLoading ? null : _resendOtp,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            primary.withValues(alpha: 0.4),
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
                            : const Text('Verify & Continue'),
                      ),
                    ),
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
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 48,
        height: 56,
        child: Focus(
          onKeyEvent: (_, event) {
            onKeyEvent(event);
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 2),
              ),
            ),
            onChanged: onChanged,
            onTap: () => controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            ),
          ),
        ),
      ),
    );
  }
}