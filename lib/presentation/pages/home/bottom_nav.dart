import 'package:flutter/material.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/presentation/pages/home/home_screen.dart';
import 'package:mess_app/presentation/pages/plots/plots_screen.dart';
import 'package:mess_app/presentation/pages/profile/volunteer_profile_screen.dart';
import 'package:mess_app/presentation/pages/tasks/tree_tasks_screen.dart';
import 'package:mess_app/presentation/pages/workers/workers_screen.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _index = 0;

  void _openTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onOpenTab: _openTab),
      const PlotsScreen(),
      const WorkersScreen(),
      const TreeTasksScreen(),
      const VolunteerProfileScreen(),
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
                  (icon: Icons.map_outlined, label: t.navPlots),
                  (icon: Icons.people_outline_rounded, label: t.navWorkers),
                  (icon: Icons.assignment_outlined, label: t.navTasks),
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
