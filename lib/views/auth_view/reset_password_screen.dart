import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/util/app_theme.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';
import 'package:dreamsync/views/auth_view/reset_password_otp_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.bg(context);
    final textColor = AppTheme.text(context);
    final secondaryTextColor = AppTheme.subText(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Reset Password"),
        backgroundColor: bgColor,
        elevation: 0,
      ),
      body: Consumer<AuthViewModel>(
        builder: (context, viewModel, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Forgot Password?",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your email and we will send you an OTP to reset your password.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  const SizedBox(height: 32),

                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: viewModel.validateEmail,
                  ),
                  const SizedBox(height: 16),

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
                    text: "Send Reset OTP",
                    isLoading: viewModel.isLoading,
                    onPressed: () async {
                      FocusScope.of(context).unfocus();

                      if (!_formKey.currentState!.validate()) return;

                      final email = _emailController.text.trim();
                      final success = await viewModel.sendResetPasswordOtp(email);

                      if (!mounted) return;

                      if (success) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: viewModel,
                              child: ResetPasswordOtpScreen(email: email),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}