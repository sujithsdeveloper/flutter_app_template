import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mess_app/core/auth/auth_service.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/database/db_constants.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/repositories/sync_repository.dart';
import 'package:mess_app/presentation/pages/auth/role_selection_screen.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';
import 'package:mess_app/presentation/widgets/volunteer_admin_label.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() =>
      _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  UserSession? _session;
  String? _email;
  String? _accessCode;
  bool _accessCodeVisible = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await getIt<SessionManager>().getSession();
    final sync = getIt<SyncRepository>();
    final email = await sync.getMetaValue(DbConstants.metaKeyAuthVolEmail);
    var code = session?.accessCode;
    if (code == null || code.isEmpty) {
      code = await sync.getMetaValue(DbConstants.metaKeyAuthVolCode);
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _email = email;
      _accessCode = (code != null && code.isNotEmpty) ? code : null;
      _loading = false;
    });

    // Soft-refresh from /auth/me when online so the code stays current.
    _refreshAccessCodeFromMe();
  }

  Future<void> _refreshAccessCodeFromMe() async {
    try {
      final data = await getIt<FieldApiService>().authMe();
      if (data['account'] != 'volunteer') return;
      final volunteer =
          Map<String, dynamic>.from(data['volunteer'] as Map? ?? {});
      final code = volunteer['accessCode'];
      if (code is! String || code.trim().isEmpty) return;
      await getIt<AuthService>().cacheVolunteerAccessCode(code);
      if (!mounted) return;
      setState(() => _accessCode = code.trim());
    } catch (_) {
      // Offline / expired token — keep locally cached code.
    }
  }

  Future<void> _copyAccessCode(AppText t) async {
    final code = _accessCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    SnackbarHelper.showSucces(
      context: context,
      message: t.accessCodeCopied,
    );
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
                        if (_accessCode != null) ...[
                          const SizedBox(height: 20),
                          _sectionLabel(t.workerAccessCode),
                          const SizedBox(height: 10),
                          _buildAccessCodeCard(t),
                        ],
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
    final name = _session?.userName ?? '—';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ColorConstants.softGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ColorConstants.forestGreen,
              ),
            ),
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
                if (_email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _email!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: ColorConstants.softGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.manage_accounts_rounded,
                        size: 13,
                        color: ColorConstants.forestGreen,
                      ),
                      const SizedBox(width: 4),
                      VolunteerAdminLabel(
                        t: t,
                        baseStyle: const TextStyle(
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

  Widget _buildAccessCodeCard(AppText t) {
    final code = _accessCode!;
    final display = _accessCodeVisible
        ? code
        : List.filled(code.length, '•').join();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ColorConstants.forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.key_rounded,
                  size: 18,
                  color: ColorConstants.forestGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  display,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: _accessCodeVisible ? 1.2 : 2.5,
                    color: ColorConstants.lightTextPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: _accessCodeVisible
                    ? t.hideAccessCode
                    : t.showAccessCode,
                onPressed: () {
                  setState(() => _accessCodeVisible = !_accessCodeVisible);
                },
                style: IconButton.styleFrom(
                  backgroundColor: ColorConstants.softGreen,
                  foregroundColor: ColorConstants.forestGreen,
                ),
                icon: Icon(
                  _accessCodeVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: t.accessCodeCopied,
                onPressed: () => _copyAccessCode(t),
                style: IconButton.styleFrom(
                  backgroundColor: ColorConstants.softGreen,
                  foregroundColor: ColorConstants.forestGreen,
                ),
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.workerAccessCodeHint,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: ColorConstants.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(AppText t, AppLanguage lang) {
    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
      child: Column(
        children: [
          _SettingsTile(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
        ],
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorConstants.borderGrey),
      ),
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
          const Divider(
              height: 1, indent: 56, color: ColorConstants.borderGrey),
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
