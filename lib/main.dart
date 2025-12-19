import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/utils/configs/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    AppConfigs.setOrentation(),
    AppConfigs.setHighestRefreshRate(),
  ]);
  final String? token = await AppUtils.getToken();
  runApp(WorkersApp(token: token));
}

class WorkersApp extends StatelessWidget {
  const WorkersApp({super.key, this.token});
  final String? token;
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: Providers.providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'template',
        themeMode: ThemeMode.dark,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: token == null || token!.isEmpty
            ? const OnBoardScreen()
            : BottomNav(),
      ),
    );
  }
}
