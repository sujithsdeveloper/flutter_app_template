import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/utils/constants/color_constants.dart';
import 'package:mess_app/presentation/widgets/primary_button.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';

/// Result returned when the volunteer confirms a map selection.
class PlotMapSelection {
  const PlotMapSelection({
    required this.latitude,
    required this.longitude,
    this.placeName,
  });

  final double latitude;
  final double longitude;
  final String? placeName;
}

class _SearchHit {
  const _SearchHit({
    required this.label,
    required this.point,
  });

  final String label;
  final LatLng point;
}

/// Full-screen OpenStreetMap picker with Nominatim search and a draggable mark.
class PlotMapPickerScreen extends StatefulWidget {
  const PlotMapPickerScreen({
    super.key,
    required this.t,
    this.initialLatitude,
    this.initialLongitude,
    this.initialPlaceName,
  });

  final AppText t;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialPlaceName;

  @override
  State<PlotMapPickerScreen> createState() => _PlotMapPickerScreenState();
}

class _PlotMapPickerScreenState extends State<PlotMapPickerScreen> {
  static const _indiaCenter = LatLng(20.5937, 78.9629);
  static const _nominatimUserAgent = 'OmyEarth/1.0 (plot-picker; contact@omyearth.in)';

  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  late LatLng _marker;
  String? _placeName;
  bool _searching = false;
  bool _locating = false;
  List<_SearchHit> _hits = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    _marker = (lat != null && lng != null) ? LatLng(lat, lng) : _indiaCenter;
    _placeName = widget.initialPlaceName;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _hits = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'addressdetails': '0',
        'limit': '6',
        'countrycodes': 'in',
      });
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _nominatimUserAgent,
          'Accept-Language': 'en',
        },
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _hits = const [];
          _searching = false;
        });
        return;
      }

      final list = jsonDecode(response.body);
      if (list is! List) {
        setState(() {
          _hits = const [];
          _searching = false;
        });
        return;
      }

      final hits = <_SearchHit>[];
      for (final item in list) {
        if (item is! Map) continue;
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        final label = (item['display_name'] as String?)?.trim();
        if (lat == null || lon == null || label == null || label.isEmpty) {
          continue;
        }
        hits.add(_SearchHit(label: label, point: LatLng(lat, lon)));
      }

      setState(() {
        _hits = hits;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hits = const [];
        _searching = false;
      });
      SnackbarHelper.showError(
        context: context,
        message: widget.t.mapSearchFailed,
      );
    }
  }

  void _selectHit(_SearchHit hit) {
    setState(() {
      _marker = hit.point;
      _placeName = hit.label.split(',').first.trim();
      _hits = const [];
      _searchCtrl.text = _placeName ?? hit.label;
    });
    _mapController.move(hit.point, 14);
    FocusScope.of(context).unfocus();
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _marker = point;
      // Keep last place name until reverse-geocode or confirm; clear stale label.
      _placeName = null;
    });
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
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
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _marker = point;
        _placeName = null;
      });
      _mapController.move(point, 15);
    } catch (_) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context: context,
        message: widget.t.gpsRequired,
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      PlotMapSelection(
        latitude: _marker.latitude,
        longitude: _marker.longitude,
        placeName: _placeName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;

    return Scaffold(
      backgroundColor: ColorConstants.lightBackground,
      appBar: AppBar(
        backgroundColor: ColorConstants.lightBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: ColorConstants.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t.pickOnMap,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorConstants.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _locating ? null : _goToMyLocation,
            tooltip: t.useMyLocation,
            icon: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: ColorConstants.forestGreen,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: t.searchPlaceHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _hits = const []);
                                },
                              )),
                    filled: true,
                    fillColor: ColorConstants.inputFill,
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
                  ),
                ),
                if (_hits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: ColorConstants.lightCard,
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _hits.length,
                        separatorBuilder: (_, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final hit = _hits[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.place_outlined,
                              color: ColorConstants.forestGreen,
                              size: 20,
                            ),
                            title: Text(
                              hit.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () => _selectHit(hit),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _marker,
                    initialZoom: widget.initialLatitude != null ? 14 : 5,
                    onTap: _onMapTap,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.omyearth.app',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _marker,
                          width: 48,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 48,
                            color: ColorConstants.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ColorConstants.lightCard.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ColorConstants.border),
                        ),
                        child: Text(
                          _placeName?.isNotEmpty == true
                              ? _placeName!
                              : '${_marker.latitude.toStringAsFixed(5)}, ${_marker.longitude.toStringAsFixed(5)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ColorConstants.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label: t.confirmLocation,
                        icon: Icons.check_rounded,
                        onPressed: _confirm,
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
}
