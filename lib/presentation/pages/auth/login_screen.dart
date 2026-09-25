import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/core/utils/functions/validators.dart';
import 'package:mess_app/core/utils/routes/app_routes.dart';
import 'package:mess_app/presentation/pages/auth/forgot_password_screen.dart';
import 'package:mess_app/presentation/pages/auth/sign_up_screen.dart';
import 'package:mess_app/presentation/pages/auth/success_screen.dart';
import 'package:mess_app/presentation/widgets/custom_checkbox.dart';
import 'package:mess_app/presentation/widgets/custom_textfield.dart';
import 'package:mess_app/presentation/widgets/omy_logo.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/social_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      AppRoutes.push(context, const SuccessScreen());
    }
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
                const SizedBox(height: 36),
                const Text(
                  'Login to Your Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Welcome back! Please enter your details to continue.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 20),
                CustomTextField(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Password is required'
                      : null,
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CustomCheckbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v),
                    ),
                    const Text(
                      'Remember me',
                      style: TextStyle(
                        color: ColorConstants.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => AppRoutes.push(
                        context,
                        const ForgotPasswordScreen(),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: ColorConstants.forestGreen,
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Login', onPressed: _onLogin),
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
                      "Don't have an account? ",
                      style: TextStyle(
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => AppRoutes.pushReplacement(
                        context,
                        const SignUpScreen(),
                      ),
                      child: const Text(
                        'Sign Up',
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
