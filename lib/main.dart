import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mess_app/core/database/app_database.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/configs/app_configs.dart';
import 'package:mess_app/core/utils/configs/providers.dart';
import 'package:mess_app/core/utils/theme/app_theme.dart';
import 'package:mess_app/presentation/pages/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load BASE_URL before DI so ApiClient points at the same Go API as the web app.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fall back to resolveApiBaseUrl() default when .env is missing.
  }

  // DB must be open before DI setup so repositories can be registered.
  await AppDatabase.instance.init();

  DependencyInjection.setupDependencyInjection();

  await Future.wait([
    AppConfigs.setOrentation(),
    if (Platform.isAndroid) ...[AppConfigs.setHighestRefreshRate()],
  ]);

  runApp(const OmyEarthApp());
}

class OmyEarthApp extends StatelessWidget {
  const OmyEarthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: Providers.providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Omy Earth',
        themeMode: ThemeMode.light,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
