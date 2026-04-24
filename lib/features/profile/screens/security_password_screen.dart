// lib/features/profile/screens/security_password_screen.dart
// Refactored: Two-step visual flow, step indicators, skeleton loading,
// disabled states, and form validation.

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../config/api_endpoints.dart';

class SecurityPasswordScreen extends StatefulWidget {
  const SecurityPasswordScreen({super.key});

  @override
  State<SecurityPasswordScreen> createState() => _SecurityPasswordScreenState();
}

class _SecurityPasswordScreenState extends State<SecurityPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  String? _partnerId;
  bool _isRequestingOtp = false;
  bool _otpSent = false;
  bool _isChangingPassword = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadPartnerId();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _loadPartnerId() {
    setState(() {
      _partnerId = StorageService.getPartnerId();
      _isLoading = false;
    });
  }

  Future<void> _requestOtp() async {
    if (_partnerId == null) {
      _showSnack('Partner ID not found', isError: true);
      return;
    }

    try {
      setState(() => _isRequestingOtp = true);
      final response = await ApiService().dio.post(
        ApiEndpoints.requestPasswordOtp,
        data: {'partnerId': _partnerId},
      );

      if (response.statusCode == 200 && mounted) {
        setState(() => _otpSent = true);
        _showSnack('OTP sent to your email');
      }
    } on DioException catch (e) {
      _showSnack(e.response?.data['error'] ?? 'Failed to send OTP', isError: true);
    } finally {
      if (mounted) setState(() => _isRequestingOtp = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_partnerId == null) return;

    try {
      setState(() => _isChangingPassword = true);
      final response = await ApiService().dio.patch(
        ApiEndpoints.changePassword,
        data: {
          'partnerId': _partnerId,
          'otp': _otpController.text.trim(),
          'newPassword': _newPasswordController.text.trim(),
        },
      );

      if (response.statusCode == 200 && mounted) {
        _showSnack('Password changed successfully');
        _otpController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() => _otpSent = false);

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } on DioException catch (e) {
      _showSnack(e.response?.data['error'] ?? 'Failed to change password', isError: true);
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Security & Password',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFDBE0E6)),
        ),
      ),
      body: _isLoading
          ? const _SecuritySkeleton()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildStep1(),
                    const SizedBox(height: 16),
                    _buildStep2(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change Your Password',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'We\'ll send an OTP to your registered email. Use it to verify and change your password.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return _StepCard(
      step: 1,
      title: 'Request OTP',
      isComplete: _otpSent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Click the button below to receive a one-time password via email.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _otpSent || _isRequestingOtp ? null : _requestOtp,
              icon: _isRequestingOtp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.mail_outline),
              label: Text(
                _otpSent ? 'OTP Sent' : 'Send OTP to Email',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _otpSent ? Colors.green : const Color(0xFF2B8CEE),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return AnimatedOpacity(
      opacity: _otpSent ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: _StepCard(
        step: 2,
        title: 'Enter OTP & New Password',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'OTP Code',
              child: TextFormField(
                controller: _otpController,
                enabled: _otpSent,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: _inputDecoration(
                  hint: 'Enter 6-digit OTP',
                  icon: Icons.password,
                  enabled: _otpSent,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'OTP is required';
                  if (v.length != 6) return 'OTP must be 6 digits';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'New Password',
              child: TextFormField(
                controller: _newPasswordController,
                enabled: _otpSent,
                obscureText: _obscureNew,
                decoration: _inputDecoration(
                  hint: 'Enter new password',
                  icon: Icons.lock_outline,
                  enabled: _otpSent,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Confirm New Password',
              child: TextFormField(
                controller: _confirmPasswordController,
                enabled: _otpSent,
                obscureText: _obscureConfirm,
                decoration: _inputDecoration(
                  hint: 'Re-enter new password',
                  icon: Icons.lock_outline,
                  enabled: _otpSent,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please confirm';
                  if (v != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _otpSent && !_isChangingPassword ? _changePassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isChangingPassword
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Change Password',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool enabled,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade100,
      counterText: '',
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
        borderSide: const BorderSide(color: Color(0xFF2B8CEE), width: 2),
      ),
    );
  }
}

// ─── WIDGETS ────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
    this.isComplete = false,
  });

  final int step;
  final String title;
  final Widget child;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBE0E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isComplete
                      ? Colors.green.shade100
                      : const Color(0xFF2B8CEE).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isComplete
                      ? Icon(Icons.check, color: Colors.green.shade700, size: 20)
                      : Text(
                          '$step',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B8CEE),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF617589),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SecuritySkeleton extends StatelessWidget {
  const _SecuritySkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SkeletonBox(height: 100, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 16),
          _SkeletonBox(height: 180, borderRadius: BorderRadius.circular(16)),
          const SizedBox(height: 16),
          _SkeletonBox(height: 320, borderRadius: BorderRadius.circular(16)),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, required this.borderRadius});

  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: borderRadius,
      ),
    );
  }
}