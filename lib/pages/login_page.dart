import 'package:chat_app/components/my_button.dart';
import 'package:chat_app/components/my_textfields.dart';
import 'package:chat_app/services/auth/auth.dart';
import 'package:chat_app/utils/dialogs.dart';
import 'package:chat_app/utils/validators.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap;

  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );
      // On success AuthGate swaps this page out automatically.
    } catch (e) {
      if (mounted) await showMessageDialog(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailError = Validators.email(_emailController.text);
    if (emailError != null) {
      await showMessageDialog(
        context,
        'Enter your email address above first, then tap "Forgot password?".',
      );
      return;
    }
    try {
      await _authService.sendPasswordReset(_emailController.text);
      if (mounted) {
        await showMessageDialog(
          context,
          'If an account exists for ${_emailController.text.trim()}, '
          'a password reset link has been sent.',
          title: 'Check your email',
        );
      }
    } catch (e) {
      if (mounted) await showMessageDialog(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message, size: 60, color: scheme.primary),
                const SizedBox(height: 50),
                Text(
                  "Welcome back you've been missed!",
                  style: TextStyle(color: scheme.inversePrimary, fontSize: 16),
                ),
                const SizedBox(height: 25),
                MyTextfields(
                  hintText: 'Email',
                  obscureText: false,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                ),
                const SizedBox(height: 10),
                MyTextfields(
                  hintText: 'Password',
                  obscureText: true,
                  controller: _passwordController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  validator: Validators.requiredPassword,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 25, top: 8),
                    child: GestureDetector(
                      onTap: _forgotPassword,
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(color: scheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                MyButton(text: 'Login', onTap: _login, isLoading: _isLoading),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Not a member? ',
                      style: TextStyle(color: scheme.primary),
                    ),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Text(
                        'Register now',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
