import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/auth/auth_service.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/blocs/tree_tasks/tree_tasks_cubit.dart';
import 'package:mess_app/presentation/blocs/workers/workers_cubit.dart';
import 'package:mess_app/presentation/pages/home/bottom_nav.dart';
import 'package:mess_app/presentation/widgets/volunteer_admin_label.dart';
import 'package:mess_app/presentation/widgets/custom_textfield.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';

/// Volunteer email + password login screen.
///
/// Credentials are validated offline against values stored in sync_meta
/// (seeded by the admin panel). On success the session is saved and the
/// app navigates to [BottomNav] (the full volunteer app), clearing the
/// entire back-stack.
class VolunteerLoginScreen extends StatefulWidget {
  const VolunteerLoginScreen({super.key});

  @override
  State<VolunteerLoginScreen> createState() => _VolunteerLoginScreenState();
}

class _VolunteerLoginScreenState extends State<VolunteerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  final _auth = getIt<AuthService>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppText t) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    final result = await _auth.loginVolunteer(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      // AuthService already pulled /field/sync; refresh app-root cubits that
      // may still hold a pre-login SQLite snapshot.
      context.read<TreeTasksCubit>().load();
      context.read<WorkersCubit>().load();
      context.read<DashboardCubit>().refresh();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BottomNav()),
        (_) => false,
      );
    } else {
      SnackbarHelper.showError(
        context: context,
        message: result.errorMessage ?? t.loginFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, lang, _) {
        final t = AppText(lang);
        return Scaffold(
          backgroundColor: ColorConstants.lightBackground,
          appBar: AppBar(
            backgroundColor: ColorConstants.lightBackground,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: ColorConstants.lightTextPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────────
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: ColorConstants.softGreen,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.manage_accounts_rounded,
                        size: 32,
                        color: ColorConstants.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 20),
                    VolunteerAdminLabel(
                      t: t,
                      suffix: ' ${t.volunteerLogin}',
                      baseStyle: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: ColorConstants.lightTextPrimary,
                      ),
                      suffixStyle: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: ColorConstants.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.roleVolunteerDesc,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Email ─────────────────────────────────────────
                    CustomTextField(
                      controller: _emailCtrl,
                      labelText: t.emailLabel,
                      hintText: t.emailHint,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        size: 20,
                        color: ColorConstants.lightTextSecondary,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return t.invalidEmail;
                        }
                        if (!v.contains('@')) {
                          return t.invalidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Password ──────────────────────────────────────
                    CustomTextField(
                      controller: _passCtrl,
                      labelText: t.passwordLabel,
                      hintText: t.passwordHint,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: ColorConstants.lightTextSecondary,
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? t.passwordRequired : null,
                    ),
                    const SizedBox(height: 32),

                    // ── Login button ──────────────────────────────────
                    PrimaryButton(
                      label: t.loginButton,
                      icon: Icons.login_rounded,
                      isLoading: _loading,
                      onPressed: _loading ? null : () => _submit(t),
                    ),
                    const SizedBox(height: 24),

                    // ── Demo hint ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ColorConstants.softGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: ColorConstants.forestGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.demoHint,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: ColorConstants.forestGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
