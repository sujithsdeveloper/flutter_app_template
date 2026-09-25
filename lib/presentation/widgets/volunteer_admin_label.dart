import 'package:flutter/material.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/core/localization/app_language.dart';

class VolunteerAdminLabel extends StatelessWidget {
  const VolunteerAdminLabel({
    super.key,
    required this.t,
    this.baseStyle,
    this.adminStyle,
    this.suffix,
    this.suffixStyle,
    this.maxLines,
    this.overflow,
  });

  final AppText t;
  final TextStyle? baseStyle;
  final TextStyle? adminStyle;
  final String? suffix;
  final TextStyle? suffixStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = baseStyle ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        );
    final adminSize = (base.fontSize ?? 14) * 0.78;
    final adminColor = ColorConstants.errorColor;

    return Text.rich(
      maxLines: maxLines,
      overflow: overflow,
      TextSpan(
        children: [
          TextSpan(text: t.volunteerLabel, style: base),
          TextSpan(
            text: ' ${t.adminBracket}',
            style: adminStyle ??
                base.copyWith(
                  fontSize: adminSize,
                  fontWeight: FontWeight.w600,
                  color: adminColor,
                ),
          ),
          if (suffix != null)
            TextSpan(text: suffix, style: suffixStyle ?? base),
        ],
      ),
    );
  }
}
