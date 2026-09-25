import 'package:flutter/material.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/core/utils/routes/app_routes.dart';
import 'package:mess_app/presentation/pages/home/bottom_nav.dart';
import 'package:mess_app/presentation/widgets/custom_image.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 220,
                width: 220,
                decoration: const BoxDecoration(
                  color: ColorConstants.softGreen,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: CustomImage(
                  imageUrl: OmyEarthImages.success,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: ColorConstants.forestGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to OmyEarth 🌱',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: ColorConstants.forestGreen,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account has been successfully created.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: ColorConstants.lightTextSecondary,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: () =>
                    AppRoutes.pushAndRemoveUntil(context, const BottomNav()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
