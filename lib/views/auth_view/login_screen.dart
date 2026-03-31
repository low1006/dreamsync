import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/util/app_theme.dart';
import 'package:dreamsync/views/auth_view/reset_password_screen.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthViewModel>().clearError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.bg(context);
    final textColor = AppTheme.text(context);
    final secondaryTextColor = AppTheme.subText(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 24.0,
            ),
            child: Consumer<AuthViewModel>(
              builder: (context, viewModel, child) {
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/icons/dreamSync_icon.png',
                              height: 150,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Welcome Back",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Sign in to continue your sleep journey",
                              style: TextStyle(
                                fontSize: 15,
                                color: secondaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      CustomTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) => viewModel.validateEmail(val),
                      ),
                      const SizedBox(height: 16),

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
                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            viewModel.clearError();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ResetPasswordScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (viewModel.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            viewModel.errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      CustomButton(
                        text: "Login",
                        isLoading: viewModel.isLoading,
                        onPressed: () {
                          FocusScope.of(context).unfocus();

                          if (_formKey.currentState!.validate()) {
                            viewModel.signIn(
                              _emailController.text.trim(),
                              _passwordController.text,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () {
                          viewModel.clearError();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                            ),
                            children: [
                              TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(
                                  color: secondaryTextColor,
                                ),
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
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}