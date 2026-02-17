import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_dropdown.dart';
import 'package:dreamsync/widget/custom/custom_slider.dart';
import 'package:dreamsync/views/auth_screen/otp_screen.dart'; // Import OTP Screen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dateBirthController = TextEditingController();

  String? _gender;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dateBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 12)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateBirthController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  // --- Huawei Health Authorization Dialog ---
  Future<bool> _showHuaweiAuthDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Huawei Health"),
          ],
        ),
        content: const Text(
            "Allow DreamSync to access your Huawei Health data for better sleep tracking analysis?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Skip"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Authorize"),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Consumer<AuthViewModel>(
        builder: (context, viewModel, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    validator: viewModel.validateEmail,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _usernameController,
                    label: 'Username',
                    validator: viewModel.validateUsername,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    isObscure: true,
                    validator: viewModel.validatePassword,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    isObscure: true,
                    validator: (val) => viewModel.validateConfirmPassword(val, _passwordController.text),
                  ),
                  const SizedBox(height: 16),

                  // Gender & Date of Birth Row
                  Row(
                    children: [
                      Expanded(
                        child: CustomDropdown(
                          label: "Gender",
                          value: _gender,
                          items: const ["Male", "Female"],
                          onChanged: (val) => setState(() => _gender = val),
                          validator: viewModel.validateGender,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: CustomTextField(
                              controller: _dateBirthController,
                              label: 'Date of Birth',
                              validator: viewModel.validateDateBirth,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sliders
                  CustomSlider(
                    label: "Weight",
                    value: viewModel.weight,
                    min: 30, max: 150,
                    unit: "kg",
                    onChanged: (val) => viewModel.updateAttribute('weight', val),
                  ),
                  CustomSlider(
                    label: "Height",
                    value: viewModel.height,
                    min: 100, max: 250,
                    unit: "cm",
                    onChanged: (val) => viewModel.updateAttribute('height', val),
                  ),
                  CustomSlider(
                    label: "Sleep Goal",
                    value: viewModel.sleepGoal,
                    min: 4, max: 12,
                    unit: "hours",
                    onChanged: (val) => viewModel.updateAttribute('sleepGoal', val),
                  ),
                  const SizedBox(height: 24),

                  if (viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),

                  CustomButton(
                    text: "Next",
                    isLoading: viewModel.isLoading,
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {

                        // 1. Show Huawei Dialog [Step 6]
                        await _showHuaweiAuthDialog();

                        // 2. Start Registration (Send OTP) [Step 8]
                        final otpSent = await viewModel.startRegistration(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim(),
                        );

                        // 3. Navigate to OTP Screen [Step 9]
                        if (otpSent && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OtpScreen(
                                email: _emailController.text.trim(),
                                username: _usernameController.text.trim(),
                                gender: _gender!,
                                dateBirth: _dateBirthController.text,
                                weight: viewModel.weight,
                                height: viewModel.height,
                                sleepGoal: viewModel.sleepGoal,
                              ),
                            ),
                          );
                        }
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