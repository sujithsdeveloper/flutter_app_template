import 'package:flutter/material.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

import 'worker_home_screen.dart';
import 'worker_profile_screen.dart';
import 'worker_trees_screen.dart';

/// Bottom navigation for field volunteers — same botanical shell as admin,
/// with a reduced tab set (home, my trees, profile).
class WorkerBottomNav extends StatefulWidget {
  const WorkerBottomNav({super.key, required this.session});
  final UserSession session;

  @override
  State<WorkerBottomNav> createState() => _WorkerBottomNavState();
}

class _WorkerBottomNavState extends State<WorkerBottomNav> {
  int _index = 0;
  final _homeKey = GlobalKey<WorkerHomeScreenState>();

  void _openTab(int i) => setState(() => _index = i);

  void _scrollHomeToTasks() {
    setState(() => _index = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.scrollToTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      WorkerHomeScreen(
        key: _homeKey,
        session: widget.session,
        onViewAllTasks: _scrollHomeToTasks,
      ),
      WorkerTreesScreen(session: widget.session),
      WorkerProfileScreen(session: widget.session),
    ];

    return OmEarthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageController.language,
          builder: (context, lang, _) {
            final t = AppText(lang);
            return SafeArea(
              top: false,
              child: OmEarthFloatingNavBar(
                index: _index,
                onTap: _openTab,
                items: [
                  (icon: Icons.home_rounded, label: t.navHome),
                  (icon: Icons.park_rounded, label: t.navMyTrees),
                  (icon: Icons.person_outline_rounded, label: t.navProfile),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
