import 'package:chat_app/components/my_button.dart';
import 'package:chat_app/components/my_textfields.dart';
import 'package:chat_app/services/auth/auth.dart';
import 'package:chat_app/utils/dialogs.dart';
import 'package:chat_app/utils/roles.dart';
import 'package:chat_app/utils/validators.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  String _role = UserRole.customer;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signUpWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
        displayName: _nameController.text,
        role: _role,
      );
      // On success AuthGate swaps this page out automatically.
    } catch (e) {
      if (mounted) await showMessageDialog(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                const SizedBox(height: 40),
                Text(
                  "Let's get you registered!",
                  style: TextStyle(color: scheme.inversePrimary, fontSize: 16),
                ),
                const SizedBox(height: 25),

                // Account type
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.customer,
                          label: Text('Customer'),
                          icon: Icon(Icons.person_outline),
                        ),
                        ButtonSegment(
                          value: UserRole.business,
                          label: Text('Business'),
                          icon: Icon(Icons.storefront_outlined),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged:
                          (selection) =>
                              setState(() => _role = selection.first),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                MyTextfields(
                  hintText:
                      _role == UserRole.business
                          ? 'Business name'
                          : 'Display name',
                  obscureText: false,
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.displayName,
                ),
                const SizedBox(height: 10),
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
                  textInputAction: TextInputAction.next,
                  validator: Validators.newPassword,
                ),
                const SizedBox(height: 10),
                MyTextfields(
                  hintText: 'Confirm Password',
                  obscureText: true,
                  controller: _confirmController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  validator:
                      (value) => Validators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                ),
                const SizedBox(height: 25),
                MyButton(
                  text: 'Register',
                  onTap: _register,
                  isLoading: _isLoading,
                  color: Colors.black,
                  textColor: Colors.white,
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: scheme.primary),
                    ),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Text(
                        'Login now',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
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
    );
  }
}
