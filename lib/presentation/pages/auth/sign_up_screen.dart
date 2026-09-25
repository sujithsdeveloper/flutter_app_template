import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/core/utils/functions/validators.dart';
import 'package:mess_app/core/utils/routes/app_routes.dart';
import 'package:mess_app/presentation/pages/auth/login_screen.dart';
import 'package:mess_app/presentation/pages/auth/success_screen.dart';
import 'package:mess_app/presentation/widgets/custom_checkbox.dart';
import 'package:mess_app/presentation/widgets/custom_textfield.dart';
import 'package:mess_app/presentation/widgets/omy_logo.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';
import 'package:mess_app/presentation/widgets/social_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onCreateAccount() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (!_acceptedTerms) {
      SnackbarHelper.showError(
        context: context,
        message: 'Please accept the Terms & Conditions to continue.',
      );
      return;
    }
    AppRoutes.pushReplacement(context, const SuccessScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.lightBackground,
      appBar: AppBar(
        backgroundColor: ColorConstants.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: ColorConstants.lightTextPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: OmyLogo(iconSize: 30, fontSize: 24)),
                const SizedBox(height: 32),
                const Text(
                  'Create Your Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start your journey towards a greener planet today.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                CustomTextField(
                  labelText: 'Full Name',
                  hintText: 'John Appleseed',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.nameValidator(v, 'Full Name'),
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  labelText: 'Email Address',
                  hintText: 'you@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.emailValidator,
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMail01,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  labelText: 'Mobile Number',
                  hintText: '9876543210',
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.phoneNumberValidator,
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSmartPhone01,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  labelText: 'Password',
                  hintText: 'Create a password',
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: Validators.passwordValidator,
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  controller: _confirmController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => Validators.confirmPasswordValidator(
                    v,
                    _passwordController.text,
                  ),
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CustomCheckbox(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _acceptedTerms = !_acceptedTerms),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: ColorConstants.lightTextSecondary,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: ColorConstants.forestGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: ColorConstants.forestGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Create Account',
                  onPressed: _onCreateAccount,
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider(color: ColorConstants.borderGrey)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: ColorConstants.lightTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: ColorConstants.borderGrey)),
                  ],
                ),
                const SizedBox(height: 24),
                SocialButton(
                  label: 'Continue with Google',
                  leading: const GoogleGlyph(),
                  onPressed: () {},
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => AppRoutes.pushReplacement(
                        context,
                        const LoginScreen(),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: ColorConstants.forestGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
