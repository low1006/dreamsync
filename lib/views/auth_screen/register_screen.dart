import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/widget/custom/custom_text_field.dart';
import 'package:dreamsync/widget/custom/custom_slider.dart';
import 'package:dreamsync/widget/custom/custom_button.dart';
import 'package:dreamsync/widget/custom/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dateBirthController = TextEditingController();
  String? _selectedGender;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dateBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dateBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Your Profile')),
      body: ChangeNotifierProvider(
        create: (_) => AuthViewModel(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Consumer<AuthViewModel>(
                      builder: (context, viewModel, child) {
                        return Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                              const SizedBox(height: 16),

                              // --- 1. Username (Standardized) ---
                              CustomTextField(
                                controller: _usernameController,
                                label: 'Username',
                                validator: (val) => viewModel.validateUsername(val),
                              ),
                              const SizedBox(height: 16),

                              // --- 2. Email (Standardized) ---
                              CustomTextField(
                                controller: _emailController,
                                label: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) => viewModel.validateEmail(val),
                              ),
                              const SizedBox(height: 16),

                              // --- 3. Password (Standardized) ---
                              CustomTextField(
                                controller: _passwordController,
                                label: 'Password',
                                isObscure: true,
                                validator: (val) => viewModel.validatePassword(val),
                              ),
                              const SizedBox(height: 16),

                              // --- 4. Confirm Password (Standardized) ---
                              CustomTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                isObscure: true,
                                // Pass the original password to the ViewModel for comparison
                                validator: (val) => viewModel.validateConfirmPassword(val, _passwordController.text),
                              ),
                              const SizedBox(height: 16),

                              const Divider(),
                              const SizedBox(height: 16),

                              // --- Gender Dropdown ---
                              CustomDropdown(
                                label: 'Gender',
                                value: _selectedGender,
                                items: const ['Male', 'Female'],
                                onChanged: (val) => setState(() => _selectedGender = val),
                                validator: (val) => viewModel.validateGender(val),
                              ),
                              const SizedBox(height: 16),

                              // --- Date Picker ---
                              GestureDetector(
                                onTap: _selectDate, // Ensures the whole box is clickable
                                child: AbsorbPointer( // Prevents the keyboard from opening
                                  child: CustomTextField(
                                    controller: _dateBirthController,
                                    label: 'Date of Birth',
                                    validator: (val) => viewModel.validateDateBirth(val),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // --- Sliders ---
                              CustomSlider(
                                label: "Weight",
                                value: viewModel.weight,
                                min: 30.0,
                                max: 150.0,
                                unit: "kg",
                                onChanged: (val) => viewModel.updateAttribute('weight', val),
                              ),
                              CustomSlider(
                                label: "Height",
                                value: viewModel.height,
                                min: 100.0,
                                max: 220.0,
                                unit: "cm",
                                onChanged: (val) => viewModel.updateAttribute('height', val),
                              ),
                              CustomSlider(
                                label: "Sleep Goal",
                                value: viewModel.sleepGoal,
                                min: 4.0,
                                max: 12.0,
                                unit: "hrs",
                                onChanged: (val) => viewModel.updateAttribute('sleepGoal', val),
                              ),

                              const Spacer(),
                              const SizedBox(height: 24),

                              if (viewModel.errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Text(
                                    viewModel.errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                CustomButton(
                                  text: 'Register',
                                  isLoading: viewModel.isLoading,
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      viewModel.signUp(
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                        username: _usernameController.text,
                                        gender: _selectedGender!,
                                        dateBirth: _dateBirthController.text,
                                        weight: viewModel.weight,
                                        height: viewModel.height,
                                        sleepGoal: viewModel.sleepGoal,
                                      );
                                    }
                                  },

                                ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 15),
                                    children: [
                                      TextSpan(
                                        text: "Already have an account? ",
                                        style: TextStyle(color: secondaryTextColor),
                                      ),
                                      TextSpan(
                                        text: "Log In",
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