import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String username;
  final String gender;
  final String dateBirth;
  final double weight;
  final double height;
  final double sleepGoal;

  const OtpScreen({
    super.key,
    required this.email,
    required this.username,
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
              const Icon(Icons.mark_email_read, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              Text(
                "Enter OTP",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                "We have sent a 6-digit code to\n${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              CustomTextField(
                controller: _otpController,
                label: "6-Digit Code",
                keyboardType: TextInputType.number,
                validator: (val) => (val == null || val.length < 6) ? "Enter valid 6-digit code" : null,
              ),

              const SizedBox(height: 16),
              if (viewModel.errorMessage != null)
                Text(
                  viewModel.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 24),

              CustomButton(
                text: "Verify & Register",
                isLoading: viewModel.isLoading,
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final success = await viewModel.verifyOtpAndCompleteRegistration(
                      email: widget.email,
                      token: _otpController.text.trim(),
                      username: widget.username,
                      gender: widget.gender,
                      dateBirth: widget.dateBirth,
                      weight: widget.weight,
                      height: widget.height,
                      sleepGoal: widget.sleepGoal,
                    );

                    // A4.2 (Success) -> Logged in
                    if (success && mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  viewModel.resendOtp(widget.email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("OTP Resent!")),
                  );
                },
                child: const Text("Resend OTP"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}