import 'package:flutter/material.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';

/// Multi-select list of plots for assigning to a field volunteer.
class PlotAssignmentPicker extends StatelessWidget {
  const PlotAssignmentPicker({
    super.key,
    required this.t,
    required this.plots,
    required this.selectedPlotIds,
    required this.onChanged,
  });

  final AppText t;
  final List<PlotModel> plots;
  final Set<String> selectedPlotIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (plots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColorConstants.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorConstants.borderGrey),
        ),
        child: Text(
          t.noPlots,
          style: const TextStyle(
            fontSize: 13,
            color: ColorConstants.lightTextSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.selectPlots,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...plots.map((plot) {
          final selected = selectedPlotIds.contains(plot.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected
                  ? ColorConstants.softGreen
                  : ColorConstants.lightCard,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  final next = Set<String>.from(selectedPlotIds);
                  if (selected) {
                    next.remove(plot.id);
                  } else {
                    next.add(plot.id);
                  }
                  onChanged(next);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? ColorConstants.forestGreen
                          : ColorConstants.borderGrey,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 22,
                        color: selected
                            ? ColorConstants.forestGreen
                            : ColorConstants.lightTextSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plot.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorConstants.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plot.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: ColorConstants.lightTextSecondary,
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
        }),
      ],
    );
  }
}
