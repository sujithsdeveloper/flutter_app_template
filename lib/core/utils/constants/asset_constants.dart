class LottieConstants {
  static const String loading = 'assets/lottie/Cosmos.json';
  static const String success = 'assets/lottie/success_yellow.json';
}

class ImageConstants {
  static const String appLogo = 'assets/images/app_logo.png';
  static const String leafSprig = 'assets/images/leaf_sprig.webp';
  static const String matureTree = 'assets/images/mature_tree.webp';
  static const String pendingTask = 'assets/images/pending_task.webp';
  static const String seedling = 'assets/images/seedling.webp';
  static const String volunteerTeam = 'assets/images/volunteer_team.webp';
  static const String wateringSeedling = 'assets/images/watering_seedling.webp';
}

/// Network illustrations used across onboarding & auth screens.
class OmyEarthImages {
  static const String _base = 'https://images.unsplash.com';
  static const String _params = '?auto=format&fit=crop&w=900&q=80';

  // Volunteers planting young trees.
  static const String onboardingPlant =
      '$_base/photo-1542601906990-b4d3fb778b09$_params';

  // Sapling / tracking nature with technology vibe.
  static const String onboardingTrack =
      '$_base/photo-1518531933037-91b2f5f229cc$_params';

  // Seedling growing - representing contribution growth.
  static const String onboardingImpact =
      '$_base/photo-1466692476868-aef1dfb1e735$_params';

  // Thriving forest with sunlight.
  static const String onboardingFuture =
      '$_base/photo-1448375240586-882707db888b$_params';

  // Welcome / auth header - lush green forest community.
  static const String authWelcome =
      '$_base/photo-1441974231531-c6227db76b6e$_params';

  // Secure recovery - calm green leaves.
  static const String forgotPassword =
      '$_base/photo-1490750967868-88aa4486c946$_params';

  // Growing tree success.
  static const String success =
      '$_base/photo-1497250681960-ef046c08a56e$_params';
}
