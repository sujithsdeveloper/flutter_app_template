import 'package:flutter/material.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';

/// Height of the floating bottom nav bar (excluding safe area).
const double kOmEarthNavBarHeight = 70.0;

/// Bottom margin under [OmEarthFloatingNavBar] inside its SafeArea wrapper.
const double kOmEarthNavBarBottomMargin = 14.0;

/// Bottom scroll padding = nav height + safe area + extra breathing room.
double omEarthBottomScrollPadding(BuildContext context) {
  final bottomSafe = MediaQuery.paddingOf(context).bottom;
  return kOmEarthNavBarHeight + bottomSafe + 24;
}

/// Extra FAB lift so nested-tab FABs clear the floating nav.
///
/// Parent [BottomNav] uses `extendBody: true`, so child scaffolds do not
/// reserve space for the bar. Safe-area inset is already applied by Scaffold.
double omEarthFabBottomOffset(BuildContext context) {
  return kOmEarthNavBarHeight + kOmEarthNavBarBottomMargin + 28;
}

// ── Background ────────────────────────────────────────────────────────────────

class OmEarthBackground extends StatelessWidget {
  const OmEarthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: ColorConstants.botanicalGradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -30,
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                ImageConstants.leafSprig,
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: Opacity(
              opacity: 0.25,
              child: Transform.rotate(
                angle: -0.4,
                child: Image.asset(
                  ImageConstants.leafSprig,
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorConstants.radialGlow.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorConstants.radialGlow.withValues(alpha: 0.2),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Card decoration helper ────────────────────────────────────────────────────

BoxDecoration omEarthCardDecoration({
  Color? color,
  double radius = 22,
  bool showShadow = true,
}) {
  return BoxDecoration(
    color: color ?? ColorConstants.cardSurface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: ColorConstants.cardBorder, width: 0.7),
    boxShadow: showShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ]
        : null,
  );
}

class OmEarthCard extends StatelessWidget {
  const OmEarthCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 22,
    this.color,
    this.onTap,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: omEarthCardDecoration(
        color: color,
        radius: radius,
        showShadow: showShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }
    return content;
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class OmEarthSectionHeader extends StatelessWidget {
  const OmEarthSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.showLeafIcon = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final bool showLeafIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showLeafIcon) ...[
          Image.asset(
            ImageConstants.leafSprig,
            width: 22,
            height: 22,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ColorConstants.primaryText,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing != null)
          trailing!
        else if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorConstants.forestGreen,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ColorConstants.forestGreen,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class OmEarthStatusChip extends StatelessWidget {
  const OmEarthStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Overview metric card ──────────────────────────────────────────────────────

class OmEarthOverviewMetricCard extends StatelessWidget {
  const OmEarthOverviewMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.illustrationAsset,
    this.accentColor,
  });

  /// Illustration footprint in the bottom-right corner.
  static const double illustrationSize = 60;

  /// Right inset so labels wrap clear of the illustration.
  static const double textRightInset = 54;

  final String value;
  final String label;
  final String? illustrationAsset;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tint = accentColor ?? ColorConstants.forestGreen;
    final hasIllustration = illustrationAsset != null;

    return OmEarthCard(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                10,
                10,
                hasIllustration ? textRightInset : 10,
                hasIllustration ? illustrationSize * 0.35 : 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.primaryText,
                        height: 1,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: tint.withValues(alpha: 0.8),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasIllustration)
            Positioned(
              right: 4,
              bottom: 4,
              width: illustrationSize,
              height: illustrationSize,
              child: Image.asset(
                illustrationAsset!,
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Metric ────────────────────────────────────────────────────────────────────

class OmEarthMetric extends StatelessWidget {
  const OmEarthMetric({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OmEarthIconBadge(icon: icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ColorConstants.primaryText,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ColorConstants.mutedText,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class OmEarthAvatar extends StatelessWidget {
  const OmEarthAvatar({
    super.key,
    required this.initials,
    this.size = 48,
    this.backgroundColor,
    this.foregroundColor,
    this.showOnlineDot = false,
  });

  final String initials;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? ColorConstants.veryPaleGreen,
            borderRadius: BorderRadius.circular(size * 0.3),
            border: Border.all(
              color: ColorConstants.border.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.33,
              fontWeight: FontWeight.w700,
              color: foregroundColor ?? ColorConstants.forestGreen,
            ),
          ),
        ),
        if (showOnlineDot)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: ColorConstants.successColor,
                shape: BoxShape.circle,
                border: Border.all(color: ColorConstants.cardSurface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Icon badge ────────────────────────────────────────────────────────────────

class OmEarthIconBadge extends StatelessWidget {
  const OmEarthIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: color),
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────────

class OmEarthPrimaryButton extends StatelessWidget {
  const OmEarthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.compact = false,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool compact;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? ColorConstants.forestGreen;
    final disabled = onPressed == null || isLoading;

    return Material(
      color: disabled ? bg.withValues(alpha: 0.5) : bg,
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        child: Container(
          height: compact ? 36 : 52,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ColorConstants.cream,
                    ),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: ColorConstants.cream,
                    fontSize: compact ? 12.5 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Floating bottom nav ───────────────────────────────────────────────────────

typedef OmEarthNavItem = ({IconData icon, String label});

class OmEarthFloatingNavBar extends StatelessWidget {
  const OmEarthFloatingNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<OmEarthNavItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kOmEarthNavBarHeight,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, kOmEarthNavBarBottomMargin),
      decoration: BoxDecoration(
        color: ColorConstants.navBarSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: ColorConstants.cardBorder.withValues(alpha: 0.8),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: ColorConstants.forestGreen.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: _NavItem(
                item: items[i],
                selected: i == index,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OmEarthNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? ColorConstants.navSelected
        : ColorConstants.navUnselected;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? ColorConstants.navSelectedBg
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(item.icon, size: 22, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
