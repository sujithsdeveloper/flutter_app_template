import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        LottieConstants.loading,

        width: 90,
        height: 90,
        fit: BoxFit.cover,
      ),
    );
  }
}
