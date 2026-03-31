import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/util/app_theme.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  final String email;

  const ResetPasswordOtpScreen({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Timer? _resendTimer;
  bool _canResend = true;
  int _resendCooldown = 0;

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
    _resendTimer?.cancel();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();

    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_resendCooldown > 1) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _resendCooldown = 0;
          _canResend = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AuthViewModel>(context);
    final bgColor = AppTheme.bg(context);
    final textColor = AppTheme.text(context);
    final secondaryTextColor = AppTheme.subText(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Reset Password OTP"),
        backgroundColor: bgColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.lock_reset,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              Text(
                "Verify Reset OTP",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We have sent a reset code to\n${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryTextColor),
              ),
              const SizedBox(height: 32),

              CustomTextField(
                controller: _otpController,
                label: "OTP Code",
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Please enter the OTP code";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _newPasswordController,
                label: "New Password",
                isObscure: true,
                validator: viewModel.validatePassword,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _confirmPasswordController,
                label: "Confirm New Password",
                isObscure: true,
                validator: (val) => viewModel.validateConfirmPassword(
                  val,
                  _newPasswordController.text,
                ),
              ),
              const SizedBox(height: 16),

              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    viewModel.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),

              CustomButton(
                text: "Reset Password",
                isLoading: viewModel.isLoading,
                onPressed: () async {
                  FocusScope.of(context).unfocus();

                  if (!_formKey.currentState!.validate()) return;

                  final success = await viewModel.verifyResetOtpAndUpdatePassword(
                    email: widget.email,
                    token: _otpController.text.trim(),
                    newPassword: _newPasswordController.text.trim(),
                  );

                  if (!mounted) return;

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Password reset successful. Please login again."),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    // 🔴 FIX: Wipe routing history and return to root '/'.
                    // main.dart's StreamBuilder will detect the signOut() and show LoginScreen automatically.
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: _canResend
                    ? () async {
                  await viewModel.resendResetPasswordOtp(widget.email);
                  _startResendCooldown();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Reset OTP resent! Check your email."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                    : null,
                child: Text(
                  _canResend
                      ? "Resend OTP"
                      : "Resend OTP in ${_resendCooldown}s",
                  style: TextStyle(
                    color: _canResend ? Colors.blueAccent : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}