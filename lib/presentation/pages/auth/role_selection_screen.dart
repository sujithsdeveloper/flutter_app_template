import 'package:flutter/material.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';

import 'package:mess_app/presentation/widgets/volunteer_admin_label.dart';

import 'volunteer_login_screen.dart';
import 'worker_login_screen.dart';

/// Lets the user pick volunteer (admin) or field volunteer login.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, lang, _) {
        final t = AppText(lang);
        return Scaffold(
          backgroundColor: ColorConstants.lightBackground,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  // ── Brand ──────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: ColorConstants.softGreen,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            size: 44,
                            color: ColorConstants.forestGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'OmyEarth',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: ColorConstants.forestGreen,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.chooseRole,
                          style: const TextStyle(
                            fontSize: 16,
                            color: ColorConstants.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // ── Role cards ────────────────────────────────────
                  _RoleCard(
                    icon: Icons.manage_accounts_rounded,
                    iconBg: ColorConstants.forestGreen,
                    title: VolunteerAdminLabel(
                      t: t,
                      baseStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.lightTextPrimary,
                      ),
                    ),
                    description: t.roleVolunteerDesc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VolunteerLoginScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.agriculture_rounded,
                    iconBg: ColorConstants.primaryOrange,
                    title: Text(
                      t.roleWorker,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.lightTextPrimary,
                      ),
                    ),
                    description: t.roleWorkerDesc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkerLoginScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // ── Language toggle ───────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        LanguageController.language.value =
                            lang == AppLanguage.english
                                ? AppLanguage.malayalam
                                : AppLanguage.english;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: ColorConstants.lightCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ColorConstants.borderGrey),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.translate_rounded,
                              size: 16,
                              color: ColorConstants.lightTextSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lang == AppLanguage.english
                                  ? 'മലയാളം'
                                  : 'English',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ColorConstants.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Widget title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorConstants.lightCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ColorConstants.borderGrey),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 30, color: iconBg),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: ColorConstants.lightTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
