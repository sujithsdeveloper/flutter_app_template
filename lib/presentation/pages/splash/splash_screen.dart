import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/auth/auth_service.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/data/repositories/sync_repository.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/blocs/tree_tasks/tree_tasks_cubit.dart';
import 'package:mess_app/presentation/blocs/workers/workers_cubit.dart';
import 'package:mess_app/presentation/pages/auth/role_selection_screen.dart';
import 'package:mess_app/presentation/pages/home/bottom_nav.dart';
import 'package:mess_app/presentation/pages/worker/worker_bottom_nav.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // Show splash for at least 2 seconds, then check session.
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final session = await getIt<SessionManager>().getSession();
    if (!mounted) return;

    Widget destination;
    if (session == null) {
      destination = const RoleSelectionScreen();
    } else if (session.role == UserRole.volunteer) {
      // Session restore: pull latest region-scoped tasks before showing UI.
      try {
        await getIt<FieldSyncService>().pullAndApply();
        final code = await getIt<SyncRepository>()
            .getMetaValue(DbConstants.metaKeyAuthVolCode);
        if (code != null && code.isNotEmpty) {
          await getIt<AuthService>().cacheVolunteerAccessCode(code);
        }
        if (mounted) {
          context.read<TreeTasksCubit>().load();
          context.read<WorkersCubit>().load();
          context.read<DashboardCubit>().refresh();
        }
      } catch (_) {
        // Offline / token expired — continue with last local SQLite snapshot.
      }
      destination = const BottomNav();
    } else {
      destination = WorkerBottomNav(session: session);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.lightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: ColorConstants.softGreen,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: ColorConstants.forestGreen.withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 64,
                    color: ColorConstants.forestGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  const Text(
                    'OmyEarth',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: ColorConstants.forestGreen,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Growing a Greener Future Together',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: ColorConstants.lightTextSecondary.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 56),
            FadeTransition(
              opacity: _textFade,
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ColorConstants.earthGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
