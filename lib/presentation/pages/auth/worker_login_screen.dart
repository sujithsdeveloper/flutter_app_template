import 'package:flutter/material.dart';
import 'package:mess_app/core/auth/auth_service.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/presentation/widgets/custom_textfield.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';

import '../worker/worker_bottom_nav.dart';

/// Worker (planter) login screen.
///
/// Workers authenticate with:
/// 1. Their registered phone number.
/// 2. The volunteer's access code (shared by the volunteer).
///
/// The app verifies the phone is in the [workers] table and the code
/// matches [DbConstants.metaKeyAuthVolCode] stored in sync_meta.
class WorkerLoginScreen extends StatefulWidget {
  const WorkerLoginScreen({super.key});

  @override
  State<WorkerLoginScreen> createState() => _WorkerLoginScreenState();
}

class _WorkerLoginScreenState extends State<WorkerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  final _auth = getIt<AuthService>();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppText t) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    final result = await _auth.loginWorker(
      _phoneCtrl.text.trim(),
      _codeCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      final session = result.session!;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WorkerBottomNav(session: session),
        ),
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
                        color: ColorConstants.primaryOrange
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.agriculture_rounded,
                        size: 32,
                        color: ColorConstants.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t.workerLogin,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: ColorConstants.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.workerLoginHint,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: ColorConstants.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Phone number ──────────────────────────────────
                    CustomTextField(
                      controller: _phoneCtrl,
                      labelText: t.phoneLabel,
                      hintText: t.phoneHint,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        size: 20,
                        color: ColorConstants.lightTextSecondary,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? t.phoneRequired
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Volunteer code ────────────────────────────────
                    CustomTextField(
                      controller: _codeCtrl,
                      labelText: t.volunteerCodeLabel,
                      hintText: t.volunteerCodeHint,
                      obscureText: true,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(
                        Icons.vpn_key_outlined,
                        size: 20,
                        color: ColorConstants.lightTextSecondary,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? t.codeRequired
                              : null,
                    ),
                    const SizedBox(height: 32),

                    // ── Login button ──────────────────────────────────
                    PrimaryButton(
                      label: t.loginButton,
                      icon: Icons.login_rounded,
                      backgroundColor: ColorConstants.primaryOrange,
                      isLoading: _loading,
                      onPressed: _loading ? null : () => _submit(t),
                    ),
                    const SizedBox(height: 24),

                    // ── Demo hint ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ColorConstants.primaryOrange
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: ColorConstants.primaryOrange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.demoWorkerHint,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: ColorConstants.primaryOrange,
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
