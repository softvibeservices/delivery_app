//lib\features\auth\screens\login_screen.dart
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
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final error = await auth.login(
      email: _email.text.trim(),
      password: _password.text,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.pushNamed(context, AppRoutes.otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final loading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 30),

                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primary, primary.withOpacity(0.6)],
                    ),
                  ),
                  child: const Icon(Icons.icecream,
                      color: Colors.white, size: 40),
                ),

                const SizedBox(height: 20),
                Text(
                  'Welcome Back!',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Login to manage your deliveries',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                _field(
                  label: 'Email Address',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  icon: Icons.mail,
                ),

                _passwordField(),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                        context, AppRoutes.register);
                  },
                  child: const Text("Don't have an account? Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (v) =>
            v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _password,
        obscureText: _obscure,
        validator: (v) =>
            v != null && v.length >= 6 ? null : 'Min 6 characters',
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(
                _obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() => _obscure = !_obscure);
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
