import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';
import 'package:dreamsync/util/app_theme.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String username;
  final String password;
  final String gender;
  final String dateBirth;
  final double weight;
  final double height;
  final double sleepGoal;

  const OtpScreen({
    super.key,
    required this.email,
    required this.username,
    required this.password,
    required this.gender,
    required this.dateBirth,
    required this.weight,
    required this.height,
    required this.sleepGoal,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
        title: const Text("Verify Email"),
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
                Icons.mark_email_read,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              Text(
                "Enter OTP",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We have sent a verification code to\n${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryTextColor,
                ),
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
                text: "Verify & Register",
                isLoading: viewModel.isLoading,
                onPressed: () async {
                  FocusScope.of(context).unfocus();

                  if (!_formKey.currentState!.validate()) return;

                  final success = await viewModel.verifyOtpAndRegister(
                    email: widget.email,
                    token: _otpController.text.trim(),
                    password: widget.password,
                    username: widget.username,
                    gender: widget.gender,
                    dateBirth: widget.dateBirth,
                    weight: widget.weight,
                    height: widget.height,
                    sleepGoal: widget.sleepGoal,
                  );

                  if (!mounted) return;

                  if (success) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: _canResend
                    ? () async {
                  await viewModel.resendOtp(widget.email);
                  _startResendCooldown();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("OTP resent! Check your email."),
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