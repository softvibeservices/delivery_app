import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _adminEmail = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _adminEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final error = await auth.register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      adminEmail: _adminEmail.text.trim(),
      password: _password.text,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final loading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Registration'),
        leading: BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Icon(Icons.icecream, size: 72, color: primary),
                const SizedBox(height: 12),
                Text(
                  'Join the Scoop Team',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                _field('Full Name', _name),
                _field('Email', _email, TextInputType.emailAddress),
                _field('Phone (+91)', _phone, TextInputType.phone),
                _field('Admin Email', _adminEmail,
                    TextInputType.emailAddress),
                _passwordField(),

                const SizedBox(height: 12),
                Text(
                  'Your account requires admin approval before login.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Register as Partner',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                        context, AppRoutes.login);
                  },
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      [TextInputType? type]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        validator: (v) =>
            v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _password,
        obscureText: _obscure,
        validator: (v) =>
            v != null && v.length >= 6 ? null : 'Min 6 chars',
        decoration: InputDecoration(
          labelText: 'Password',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() => _obscure = !_obscure);
            },
          ),
        ),
      ),
    );
  }
}