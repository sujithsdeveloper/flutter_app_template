import 'package:flutter/material.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';

/// OmyEarth wordmark: a rounded leaf badge beside the brand name.
class OmyLogo extends StatelessWidget {
  const OmyLogo({
    super.key,
    this.iconSize = 28,
    this.fontSize = 22,
    this.showText = true,
    this.color = ColorConstants.forestGreen,
  });

  final double iconSize;
  final double fontSize;
  final bool showText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: EdgeInsets.all(iconSize * 0.32),
      decoration: BoxDecoration(
        color: ColorConstants.softGreen,
        borderRadius: BorderRadius.circular(iconSize * 0.5),
      ),
      child: Icon(Icons.eco_rounded, size: iconSize, color: color),
    );

    if (!showText) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 10),
        Text(
          'OmyEarth',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
