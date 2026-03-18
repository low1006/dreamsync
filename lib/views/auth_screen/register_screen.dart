import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_dropdown.dart';
import 'package:dreamsync/widget/custom/custom_slider.dart';
import 'package:dreamsync/views/auth_screen/otp_screen.dart';

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
                    validator: (val) => viewModel.validateConfirmPassword(
                      val,
                      _passwordController.text,
                    ),
                  ),
                  const SizedBox(height: 16),

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

                  CustomSlider(
                    label: "Weight",
                    value: viewModel.weight,
                    min: 30,
                    max: 150,
                    unit: "kg",
                    onChanged: (val) =>
                        viewModel.updateAttribute('weight', val),
                  ),
                  CustomSlider(
                    label: "Height",
                    value: viewModel.height,
                    min: 100,
                    max: 250,
                    unit: "cm",
                    onChanged: (val) =>
                        viewModel.updateAttribute('height', val),
                  ),

                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Default Sleep Goal: 8 hours",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (viewModel.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        viewModel.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  CustomButton(
                    text: "Next",
                    isLoading: viewModel.isLoading,
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final otpSent = await viewModel.sendVerificationOtp(
                          _emailController.text.trim(),
                        );

                        if (otpSent && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OtpScreen(
                                email: _emailController.text.trim(),
                                password: _passwordController.text.trim(),
                                username: _usernameController.text.trim(),
                                gender: _gender!,
                                dateBirth: _dateBirthController.text,
                                weight: viewModel.weight,
                                height: viewModel.height,
                                sleepGoal: 8.0,
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