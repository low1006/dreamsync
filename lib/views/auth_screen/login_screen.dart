import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      body: ChangeNotifierProvider(
        create: (_) => AuthViewModel(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints:
                  BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Consumer<AuthViewModel>(
                      builder: (context, viewModel, child) {
                        return Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                "Welcome Back",
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 40),

                              // --- Email Field ---
                              CustomTextField(
                                controller: _emailController,
                                label: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) =>
                                    viewModel.validateEmail(val),
                              ),
                              const SizedBox(height: 16),

                              // --- Password Field ---
                              CustomTextField(
                                controller: _passwordController,
                                label: 'Password',
                                isObscure: true,
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // --- Error Message ---
                              if (viewModel.errorMessage != null)
                                Padding(
                                  padding:
                                  const EdgeInsets.only(bottom: 16.0),
                                  child: Text(
                                    viewModel.errorMessage!,
                                    style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              // --- Login Button ---
                              CustomButton(
                                text: "Login",
                                isLoading: viewModel.isLoading,
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    viewModel.signIn(
                                      _emailController.text,
                                      _passwordController.text,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // --- Navigation to Register ---
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                        const RegisterScreen()),
                                  );
                                },
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                        fontFamily: 'Roboto', fontSize: 15),
                                    children: [
                                      TextSpan(
                                        text: "Don't have an account? ",
                                        style: TextStyle(
                                            color: secondaryTextColor),
                                      ),
                                      TextSpan(
                                        text: "Sign Up",
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}