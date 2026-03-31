import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_dropdown.dart';
import 'package:dreamsync/widget/custom/custom_slider.dart';
import 'package:dreamsync/views/auth_view/otp_screen.dart';
import 'package:dreamsync/util/app_theme.dart';

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
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dateBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
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
    final bgColor = AppTheme.bg(context);
    final textColor = AppTheme.text(context);
    final secondaryTextColor = AppTheme.subText(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Sign Up"),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/icons/dreamSync_icon.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Start your sleep journey with DreamSync",
                          style: TextStyle(
                            fontSize: 15,
                            color: secondaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
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
                    onChanged: (val) => viewModel.updateAttribute('weight', val),
                  ),
                  const SizedBox(height: 12),

                  CustomSlider(
                    label: "Height",
                    value: viewModel.height,
                    min: 100,
                    max: 250,
                    unit: "cm",
                    onChanged: (val) => viewModel.updateAttribute('height', val),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Default Sleep Goal: 8 hours",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

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
                    text: "Next",
                    isLoading: viewModel.isLoading,
                    onPressed: () async {
                      FocusScope.of(context).unfocus();

                      if (!_formKey.currentState!.validate()) return;

                      // FIX IMPLEMENTED HERE: pass both email and password
                      // so Supabase can register the user securely upfront.
                      final otpSent = await viewModel.sendVerificationOtp(
                        email: _emailController.text.trim(),
                        password: _passwordController.text,
                      );

                      if (!mounted) return;

                      if (otpSent) {
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
                    },
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                        ),
                        children: [
                          TextSpan(
                            text: "Already have an account? ",
                            style: TextStyle(
                              color: secondaryTextColor,
                            ),
                          ),
                          TextSpan(
                            text: "Login",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
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