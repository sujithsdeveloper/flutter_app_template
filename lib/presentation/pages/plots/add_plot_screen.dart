import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mess_app/core/constants/india_geo_data.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/data/models/plot_model.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/pages/plots/plot_map_picker_screen.dart';
import 'package:mess_app/presentation/widgets/custom_textfield.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';

/// Form for volunteers to edit or end an existing plot.
/// Create mode is not supported — plots are added from the web admin panel.
class AddPlotScreen extends StatefulWidget {
  const AddPlotScreen({
    super.key,
    required this.t,
    required this.cubit,
    required this.existingPlot,
  });

  final AppText t;
  final DashboardCubit cubit;
  final PlotModel existingPlot;

  @override
  State<AddPlotScreen> createState() => _AddPlotScreenState();
}

class _AddPlotScreenState extends State<AddPlotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  Map<String, List<String>> _geo = const {};
  String? _selectedState;
  String? _selectedDistrict;
  String? _placeName;

  double? _latitude;
  double? _longitude;
  bool _saving = false;
  bool _ending = false;
  bool _loadingGps = false;
  bool _loadingGeo = true;

  @override
  void initState() {
    super.initState();
    _prefillFromExisting();
    _loadGeo();
  }

  void _prefillFromExisting() {
    final plot = widget.existingPlot;

    _nameCtrl.text = plot.name;
    if (plot.areaHectares != null) {
      _areaCtrl.text = plot.areaHectares!.toStringAsFixed(
        plot.areaHectares! == plot.areaHectares!.roundToDouble() ? 0 : 2,
      );
    }
    _latitude = plot.latitude;
    _longitude = plot.longitude;
    _selectedDistrict = plot.district;

    final parts = plot.location
        .split('·')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) {
      _selectedState = parts.first;
    }
    if (parts.length >= 2) {
      final second = parts[1];
      if (plot.district != null &&
          second.toLowerCase() == plot.district!.toLowerCase()) {
        _selectedDistrict = plot.district;
      } else if (plot.district == null ||
          second.toLowerCase() != plot.district!.toLowerCase()) {
        _placeName = second;
      }
    }
  }

  Future<void> _loadGeo() async {
    try {
      final data = await IndiaGeoData.load();
      if (!mounted) return;
      setState(() {
        _geo = data;
        _loadingGeo = false;
        _reconcileGeoSelection();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingGeo = false);
    }
  }

  void _reconcileGeoSelection() {
    if (_geo.isEmpty) return;

    if (_selectedState != null && !_geo.containsKey(_selectedState)) {
      String? match;
      for (final s in _geo.keys) {
        if (s.toLowerCase() == _selectedState!.toLowerCase()) {
          match = s;
          break;
        }
      }
      _selectedState = match;
    }

    final districts = IndiaGeoData.districtsFor(_geo, _selectedState);
    if (_selectedDistrict != null && !districts.contains(_selectedDistrict)) {
      String? match;
      for (final d in districts) {
        if (d.toLowerCase() == _selectedDistrict!.toLowerCase()) {
          match = d;
          break;
        }
      }
      _selectedDistrict = match;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  List<String> get _districts =>
      IndiaGeoData.districtsFor(_geo, _selectedState);

  String get _locationLabel {
    final place = _placeName?.trim();
    final state = _selectedState?.trim();
    final district = _selectedDistrict?.trim();

    if (place != null && place.isNotEmpty && state != null) {
      return '$state · $place';
    }
    if (state != null && district != null) {
      return '$state · $district';
    }
    return state ?? district ?? place ?? '';
  }

  Future<void> _captureGps() async {
    setState(() => _loadingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        SnackbarHelper.showError(
          context: context,
          message: 'Location access denied. Open app settings to allow.',
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context: context,
        message: widget.t.gpsRequired,
      );
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<PlotMapSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => PlotMapPickerScreen(
          t: widget.t,
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialPlaceName: _placeName,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      if (result.placeName != null && result.placeName!.trim().isNotEmpty) {
        _placeName = result.placeName!.trim();
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedState == null || _selectedDistrict == null) return;

    setState(() => _saving = true);

    final areaText = _areaCtrl.text.trim();
    final area = areaText.isEmpty ? null : double.tryParse(areaText);

    final success = await widget.cubit.updatePlot(
      plotId: widget.existingPlot.id,
      name: _nameCtrl.text,
      location: _locationLabel,
      district: _selectedDistrict,
      latitude: _latitude,
      longitude: _longitude,
      areaHectares: area,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      SnackbarHelper.showSucces(
        context: context,
        message: widget.t.plotUpdated,
      );
      Navigator.pop(context, true);
    } else {
      SnackbarHelper.showError(
        context: context,
        message: widget.t.plotUpdateFailed,
      );
    }
  }

  Future<void> _confirmEndPlot() async {
    final plot = widget.existingPlot;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.t.endPlot),
        content: Text(widget.t.endPlotConfirm(plot.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: ColorConstants.errorColor,
            ),
            child: Text(widget.t.endPlot),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _ending = true);
    final success = await widget.cubit.endPlot(plot.id);
    if (!mounted) return;
    setState(() => _ending = false);

    if (success) {
      SnackbarHelper.showSucces(
        context: context,
        message: widget.t.plotEnded,
      );
      Navigator.pop(context, true);
    } else {
      SnackbarHelper.showError(
        context: context,
        message: widget.t.plotEndFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final hasGps = _latitude != null && _longitude != null;
    final busy = _saving || _ending;

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
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
        title: Text(
          t.editPlot,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ColorConstants.softGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  size: 36,
                  color: ColorConstants.forestGreen,
                ),
              ),
            ),
            const SizedBox(height: 28),
            CustomTextField(
              controller: _nameCtrl,
              labelText: t.plotName,
              hintText: t.plotNameHint,
              prefixIcon: const Icon(Icons.landscape_outlined, size: 20),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return t.plotNameRequired;
                return null;
              },
            ),
            const SizedBox(height: 16),
            _GeoDropdown(
              label: t.plotState,
              hint: t.plotStateHint,
              icon: Icons.map_outlined,
              value: _selectedState,
              items: _geo.keys.toList(),
              enabled: !_loadingGeo && _geo.isNotEmpty,
              validator: (v) =>
                  v == null || v.isEmpty ? t.plotStateRequired : null,
              onChanged: (value) {
                setState(() {
                  _selectedState = value;
                  _selectedDistrict = null;
                });
              },
            ),
            const SizedBox(height: 16),
            _GeoDropdown(
              label: t.plotDistrict,
              hint: t.plotDistrictHint,
              icon: Icons.location_city_outlined,
              value: _selectedDistrict,
              items: _districts,
              enabled: _selectedState != null && _districts.isNotEmpty,
              validator: (v) =>
                  v == null || v.isEmpty ? t.plotDistrictRequired : null,
              onChanged: (value) {
                setState(() => _selectedDistrict = value);
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _areaCtrl,
              labelText: t.plotArea,
              hintText: t.plotAreaHint,
              prefixIcon: const Icon(Icons.square_foot_outlined, size: 20),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColorConstants.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorConstants.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.gpsLocation,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.tapMapToMark,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColorConstants.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_placeName != null && _placeName!.isNotEmpty) ...[
                    Text(
                      _placeName!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColorConstants.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    hasGps
                        ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                        : t.gpsNotCaptured,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasGps
                          ? ColorConstants.forestGreen
                          : ColorConstants.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _openMapPicker,
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: Text(hasGps ? t.changeOnMap : t.openMapPicker),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorConstants.forestGreen,
                        side: const BorderSide(
                          color: ColorConstants.forestGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy || _loadingGps ? null : _captureGps,
                      icon: _loadingGps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              hasGps
                                  ? Icons.refresh_rounded
                                  : Icons.my_location_rounded,
                              size: 18,
                            ),
                      label: Text(hasGps ? t.retryGps : t.captureGps),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorConstants.forestGreen,
                        side: const BorderSide(
                          color: ColorConstants.forestGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: t.saveChanges,
              icon: Icons.check_rounded,
              isLoading: _saving,
              onPressed: busy ? null : _submit,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _confirmEndPlot,
                icon: _ending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_outlined, size: 18),
                label: Text(t.endPlot),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorConstants.errorColor,
                  side: const BorderSide(color: ColorConstants.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeoDropdown extends StatelessWidget {
  const _GeoDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.validator,
  });

  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use — value is still the stable API on this SDK
          value: value != null && items.contains(value) ? value : null,
          isExpanded: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: enabled
                ? ColorConstants.inputFill
                : ColorConstants.inputFill.withValues(alpha: 0.6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: ColorConstants.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: ColorConstants.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: ColorConstants.forestGreen,
                width: 1.4,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: ColorConstants.border.withValues(alpha: 0.6),
              ),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}
