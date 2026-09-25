import 'package:flutter/material.dart';
import 'package:mess_app/core/auth/auth_service.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/repositories/worker_repository.dart';
import 'package:mess_app/presentation/pages/auth/role_selection_screen.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key, required this.session});

  final UserSession session;

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  String? _phone;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final worker = await getIt<WorkerRepository>().getById(widget.session.userId);
    if (!mounted) return;
    setState(() {
      _phone = worker?.phone;
      _loading = false;
    });
  }

  Future<void> _logout(AppText t) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          t.logoutConfirm,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t.cancel,
              style: const TextStyle(
                color: ColorConstants.lightTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorConstants.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t.logoutConfirmYes),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await getIt<AuthService>().logout();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (_) => false,
      );
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, lang, _) {
        final t = AppText(lang);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ColorConstants.forestGreen,
                    ),
                  ),
                )
              : SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      omEarthBottomScrollPadding(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.navProfile,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: ColorConstants.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildProfileCard(t),
                        const SizedBox(height: 20),
                        _sectionLabel(t.settings),
                        const SizedBox(height: 10),
                        _buildSettingsCard(t, lang),
                        const SizedBox(height: 20),
                        _sectionLabel(t.appInfo),
                        const SizedBox(height: 10),
                        _buildAppInfoCard(),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            label: Text(
                              t.logout,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => _logout(t),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ColorConstants.errorColor,
                              side: const BorderSide(
                                color: ColorConstants.errorColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
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

  Widget _buildProfileCard(AppText t) {
    final name = widget.session.userName;
    return OmEarthCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Row(
        children: [
          OmEarthAvatar(
            initials: _initials(name),
            size: 64,
            backgroundColor: ColorConstants.softGreen,
            foregroundColor: ColorConstants.forestGreen,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ColorConstants.lightTextPrimary,
                  ),
                ),
                if (_phone != null && _phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _phone!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ColorConstants.softGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.eco_rounded,
                        size: 13,
                        color: ColorConstants.forestGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t.roleVolunteer,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ColorConstants.forestGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(AppText t, AppLanguage lang) {
    return OmEarthCard(
      padding: EdgeInsets.zero,
      radius: 16,
      showShadow: false,
      child: _SettingsTile(
        icon: Icons.translate_rounded,
        iconColor: ColorConstants.infoColor,
        title: t.language,
        trailing: GestureDetector(
          onTap: () {
            LanguageController.language.value =
                lang == AppLanguage.english
                    ? AppLanguage.malayalam
                    : AppLanguage.english;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: ColorConstants.forestGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              lang == AppLanguage.english ? 'മലയാളം' : 'English',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return OmEarthCard(
      padding: EdgeInsets.zero,
      radius: 16,
      showShadow: false,
      child: Column(
        children: [
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: ColorConstants.lightTextSecondary,
            title: 'Version',
            trailing: Text(
              '1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: ColorConstants.lightTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 56,
            color: ColorConstants.borderGrey.withValues(alpha: 0.6),
          ),
          const _SettingsTile(
            icon: Icons.eco_rounded,
            iconColor: ColorConstants.forestGreen,
            title: 'OmyEarth',
            trailing: Text(
              'Field Operations',
              style: TextStyle(
                fontSize: 13,
                color: ColorConstants.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: ColorConstants.lightTextSecondary,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ColorConstants.lightTextPrimary,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
