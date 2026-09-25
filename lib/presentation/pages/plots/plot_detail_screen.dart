import 'package:flutter/material.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/asset_constants.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/presentation/widgets/om_earth_ui.dart';

/// Read-only plot details for volunteer admins.
/// Plot create/edit/end is staff-only via the web admin panel.
class PlotDetailScreen extends StatelessWidget {
  const PlotDetailScreen({
    super.key,
    required this.plot,
    required this.t,
  });

  final PlotModel plot;
  final AppText t;

  @override
  Widget build(BuildContext context) {
    final status = switch (plot.status) {
      PlotStatus.healthy => (t.statusHealthy, ColorConstants.successColor),
      PlotStatus.needsCheck => (t.statusNeedsCheck, ColorConstants.warningColor),
      PlotStatus.inspectionDue => (
          t.statusInspectionDue,
          ColorConstants.infoColor,
        ),
    };

    return Scaffold(
      backgroundColor: ColorConstants.lightBackgroundSecondary,
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
        title: Text(
          t.plotDetails,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: OmEarthStatusChip(label: status.$1, color: status.$2),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ColorConstants.forestGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    ImageConstants.matureTree,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plot.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plot.id,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: t.plotLocation,
            icon: Icons.map_outlined,
            children: [
              _DetailRow(label: t.plotLocation, value: plot.location),
              if (plot.district != null && plot.district!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailRow(label: t.plotDistrict, value: plot.district!),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _DetailCard(
            title: t.plotArea,
            icon: Icons.straighten_rounded,
            children: [
              _DetailRow(
                label: t.plotArea,
                value: plot.areaHectares != null
                    ? '${plot.areaHectares!.toStringAsFixed(2)} ha'
                    : '—',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                label: t.treesLabel,
                value: t.treesCount(plot.treeCount),
              ),
            ],
          ),
          if (plot.latitude != null && plot.longitude != null) ...[
            const SizedBox(height: 12),
            _DetailCard(
              title: t.targetLocation,
              icon: Icons.my_location_rounded,
              children: [
                _DetailRow(
                  label: 'Lat',
                  value: plot.latitude!.toStringAsFixed(6),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Lon',
                  value: plot.longitude!.toStringAsFixed(6),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            t.plotViewOnlyHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: ColorConstants.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 16, color: ColorConstants.forestGreen),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColorConstants.lightTextSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ColorConstants.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}
