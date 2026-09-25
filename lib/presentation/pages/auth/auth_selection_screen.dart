import 'package:flutter/material.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/core/utils/routes/app_routes.dart';
import 'package:mess_app/presentation/pages/auth/login_screen.dart';
import 'package:mess_app/presentation/pages/auth/sign_up_screen.dart';
import 'package:mess_app/presentation/widgets/custom_image.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/social_button.dart';

class AuthSelectionScreen extends StatelessWidget {
  const AuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.lightBackground,
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.42,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomImage(
                  imageUrl: OmyEarthImages.authWelcome,
                  fit: BoxFit.cover,
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 60,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to OmyEarth',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: ColorConstants.forestGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sign in to manage your trees, track environmental impact, and participate in sustainability initiatives.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SocialButton(
                    label: 'Continue with Google',
                    leading: const GoogleGlyph(),
                    onPressed: () {},
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
                  PrimaryButton(
                    label: 'Sign In with Email',
                    icon: Icons.email_outlined,
                    onPressed: () =>
                        AppRoutes.push(context, const LoginScreen()),
                  ),
                  const SizedBox(height: 24),
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
                        onTap: () =>
                            AppRoutes.push(context, const SignUpScreen()),
                        child: const Text(
                          'Create Account',
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
        ],
      ),
    );
  }
}
