import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/core/utils/functions/validators.dart';
import 'package:mess_app/presentation/widgets/custom_image.dart';
import 'package:mess_app/presentation/widgets/custom_textfield.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSend() {
    if (_formKey.currentState?.validate() ?? false) {
      SnackbarHelper.showSucces(
        context: context,
        message: 'Reset instructions sent to ${_emailController.text.trim()}',
      );
      Navigator.of(context).pop();
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
                Center(
                  child: Container(
                    height: 200,
                    width: 200,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: ColorConstants.softGreen,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomImage(
                      imageUrl: OmyEarthImages.forgotPassword,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Enter your registered email address and we'll send password reset instructions.",
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
                  textInputAction: TextInputAction.done,
                  validator: Validators.emailValidator,
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMail01,
                    color: ColorConstants.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(label: 'Send Reset Link', onPressed: _onSend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
