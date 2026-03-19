import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';

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

  // Resend cooldown timer
  bool _canResend = true;
  int _resendCooldown = 0;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // Start a 60 second cooldown after resend
  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) {
        setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<AuthViewModel>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Verify Email")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Icon
              const Icon(
                Icons.mark_email_read,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                "Enter OTP",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                "We have sent a 8-digit code to\n${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // OTP Input
              CustomTextField(
                controller: _otpController,
                label: "8-Digit Code",
                keyboardType: TextInputType.number,
                validator: (val) =>
                (val == null || val.trim().length < 8)
                    ? "Enter a valid 8-character code"
                    : null,
              ),
              const SizedBox(height: 16),

              // Error Message
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

              // Verify Button
              CustomButton(
                text: "Verify & Register",
                isLoading: viewModel.isLoading,
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
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

                    if (success && mounted) {
                      // Navigate to home and clear all previous routes
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),

              // Resend OTP Button with cooldown
              TextButton(
                onPressed: _canResend
                    ? () async {
                  await viewModel.resendOtp(widget.email);
                  _startResendCooldown();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("OTP resent! Check your email."),
                      ),
                    );
                  }
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