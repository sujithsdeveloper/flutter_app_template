import 'package:flutter/material.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/core/utils/routes/app_routes.dart';
import 'package:mess_app/presentation/pages/auth/auth_selection_screen.dart';
import 'package:mess_app/presentation/widgets/custom_image.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';

class _OnboardData {
  const _OnboardData({
    required this.image,
    required this.title,
    required this.description,
  });

  final String image;
  final String title;
  final String description;
}

const List<_OnboardData> _pages = [
  _OnboardData(
    image: OmyEarthImages.onboardingPlant,
    title: 'Plant Trees. Create Impact.',
    description:
        'Join a movement that helps restore nature while creating measurable environmental impact.',
  ),
  _OnboardData(
    image: OmyEarthImages.onboardingTrack,
    title: 'Track Every Tree',
    description:
        'Monitor planted trees with GPS locations, photos, growth updates, and survival tracking.',
  ),
  _OnboardData(
    image: OmyEarthImages.onboardingImpact,
    title: 'See Your Contribution Grow',
    description:
        'Track carbon sequestration, tree growth, and environmental benefits in real time.',
  ),
  _OnboardData(
    image: OmyEarthImages.onboardingFuture,
    title: 'Together We Build a Sustainable Future',
    description:
        'Adopt trees, support conservation efforts, and contribute to a greener planet.',
  ),
];

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToAuth() {
    AppRoutes.pushReplacement(context, const AuthSelectionScreen());
  }

  void _onNext() {
    if (_isLast) {
      _goToAuth();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: TextButton(
                  onPressed: _isLast ? null : _goToAuth,
                  style: TextButton.styleFrom(
                    foregroundColor: ColorConstants.lightTextSecondary,
                  ),
                  child: Opacity(
                    opacity: _isLast ? 0 : 1,
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _OnboardPage(data: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: i == _index ? 26 : 8,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? ColorConstants.forestGreen
                              : ColorConstants.borderGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: _isLast ? 'Get Started' : 'Next',
                    onPressed: _onNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({required this.data});

  final _OnboardData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ColorConstants.softGreen,
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomImage(imageUrl: data.image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ColorConstants.lightTextPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: ColorConstants.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
