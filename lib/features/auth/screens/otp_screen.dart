import 'dart:async';
import 'package:flutter/material.dart';
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

  int _secondsLeft = AppConstants.otpResendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = AppConstants.otpResendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _controllers.map((e) => e.text).join();

    if (otp.length != AppConstants.otpLength) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid OTP')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final error = await auth.verifyOtp(otp: otp);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    switch (auth.status) {
      case AuthStatus.authenticated:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.orders,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account rejected')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final loading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text(
              'Enter Verification Code',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('We sent a 6-digit code to your email'),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                AppConstants.otpLength,
                (i) => _otpBox(i),
              ),
            ),

            const SizedBox(height: 30),

            Text(
              _secondsLeft > 0
                  ? 'Resend OTP in $_secondsLeft sec'
                  : 'Didn’t receive OTP?',
              style: const TextStyle(color: Colors.grey),
            ),

            if (_secondsLeft == 0)
              TextButton(
                onPressed: _startTimer,
                child: const Text('Resend OTP'),
              ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Verify & Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 48,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        controller: _controllers[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }
}
