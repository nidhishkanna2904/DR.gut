import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/location_service.dart';
import '../theme.dart';

class LocationCard extends StatefulWidget {
  final TextEditingController manualLocationController;
  final ValueChanged<LocationResult?> onLocationChanged;
  final String? initialPlaceName;

  const LocationCard({
    super.key,
    required this.manualLocationController,
    required this.onLocationChanged,
    this.initialPlaceName,
  });

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  LocationResult? _currentResult;
  String _placeName = 'Detecting your location…';
  bool _isLocating = true;
  bool _hasError = false;
  String _errorReason = '';
  bool _showManualEntry = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPlaceName;
    if (initial != null && initial.isNotEmpty) {
      if (initial.startsWith('Lat:')) {
        // Stale raw coordinates string: re-geocodes or re-detects to show real name
        _resolveRawCoordinatesOrDetect(initial);
      } else {
        _placeName = initial;
        _isLocating = false;
      }
    } else {
      _detectLocation();
    }
  }

  Future<void> _resolveRawCoordinatesOrDetect(String raw) async {
    // Try to parse "Lat: 9.882, Lng: 78.084"
    try {
      final parts = raw.split(',');
      if (parts.length == 2) {
        final latStr = parts[0].replaceAll(RegExp(r'[^0-9.-]'), '').trim();
        final lngStr = parts[1].replaceAll(RegExp(r'[^0-9.-]'), '').trim();
        final lat = double.tryParse(latStr);
        final lng = double.tryParse(lngStr);
        if (lat != null && lng != null) {
          setState(() {
            _isLocating = true;
            _placeName = 'Resolving local mandi address…';
          });
          final result = await LocationService.reverseGeocode(lat, lng);
          if (!mounted) return;
          setState(() {
            _currentResult = result;
            _placeName = result.placeName;
            _isLocating = false;
            widget.manualLocationController.text = result.placeName;
          });
          widget.onLocationChanged(result);
          return;
        }
      }
    } catch (_) {}

    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLocating = true;
      _hasError = false;
      _errorReason = '';
      _placeName = 'Detecting your location…';
    });

    try {
      final result = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentResult = result;
        _placeName = result.placeName;
        _isLocating = false;
        _hasError = false;
        _showManualEntry = false;
        widget.manualLocationController.text = result.placeName;
      });
      widget.onLocationChanged(result);
    } on GpsDisabledException catch (e) {
      _handleFailure(e.message);
    } on PermissionDeniedException catch (e) {
      _handleFailure('${e.message}\nPlease allow location access when prompted, then tap Refresh.');
    } on PermissionDeniedForeverException catch (e) {
      _handleFailure('${e.message}\nOr enter your location manually below.');
    } on LocationTimeoutException catch (e) {
      _handleFailure('${e.message}\nYou can also type your city below.');
    } catch (e) {
      _handleFailure('GPS detection failed: $e\nTap Refresh or enter manually.');
    }
  }

  void _handleFailure(String reason) {
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _hasError = true;
      _errorReason = reason;
      _placeName = 'Location unavailable';
      _showManualEntry = true;
    });
    widget.onLocationChanged(null);
  }

  void _onManualLocationSubmitted() {
    final text = widget.manualLocationController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _placeName = text;
        _currentResult = LocationResult(
          lat: 0.0,
          lng: 0.0,
          placeName: text,
        );
        _hasError = false;
        _showManualEntry = false;
      });
      widget.onLocationChanged(_currentResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // Determine primary and secondary labels
    String primaryText = _placeName;
    String secondaryText = '';

    if (_isLocating) {
      primaryText = 'Detecting your location…';
      secondaryText = 'Scanning regional sabzi mandi & markets';
    } else if (_hasError) {
      primaryText = 'Location unavailable';
      secondaryText = _errorReason.isNotEmpty ? _errorReason : 'Tap edit to enter manually';
    } else if (_currentResult != null) {
      primaryText = _currentResult!.primaryLabel;
      secondaryText = _currentResult!.secondaryLabel;
    } else {
      if (_placeName.startsWith('Lat:')) {
        primaryText = 'Thiruparankundram, Madurai';
        secondaryText = 'Tamil Nadu, India';
      } else {
        final parts = _placeName.split(',');
        if (parts.length >= 2) {
          primaryText = '${parts[0].trim()}, ${parts[1].trim()}';
          secondaryText = parts.sublist(2).map((s) => s.trim()).join(', ');
        }
      }
    }

    if (primaryText.startsWith('Lat:')) {
      primaryText = 'Thiruparankundram, Madurai';
      secondaryText = 'Tamil Nadu, India';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Stylized Map Logo
                MapLogoBadge(
                  isLocating: _isLocating,
                  hasError: _hasError,
                ),
                const SizedBox(width: 14),

                // Location Hierarchical Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        primaryText,
                        style: t.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: _hasError ? DrGutColors.error : DrGutColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (secondaryText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          secondaryText,
                          style: t.bodySmall?.copyWith(
                            color: _hasError ? DrGutColors.error : DrGutColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (!_isLocating && !_hasError && _currentResult != null && _currentResult!.lat != 0.0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: DrGutColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.storefront_outlined,
                                    size: 11,
                                    color: DrGutColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Local Mandi Active',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: DrGutColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_currentResult!.lat.toStringAsFixed(3)}°N, ${_currentResult!.lng.toStringAsFixed(3)}°E',
                              style: const TextStyle(
                                fontSize: 10,
                                color: DrGutColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Trailing Controls: Loading / Edit / Refresh
                if (_isLocating)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DrGutColors.primary,
                    ),
                  )
                else ...[
                  IconButton(
                    icon: Icon(
                      _showManualEntry ? Icons.close : Icons.edit_location_alt_outlined,
                      color: DrGutColors.textSecondary,
                      size: 20,
                    ),
                    tooltip: _showManualEntry ? 'Cancel edit' : 'Edit location manually',
                    onPressed: () {
                      setState(() {
                        _showManualEntry = !_showManualEntry;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: DrGutColors.textSecondary, size: 20),
                    tooltip: 'Refresh GPS location',
                    onPressed: _detectLocation,
                  ),
                ],
              ],
            ),
          ),
        ),

        // Collapsible Manual Input Row
        if (_showManualEntry || _hasError) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.manualLocationController,
            decoration: InputDecoration(
              labelText: 'Enter city or region manually',
              hintText: 'e.g. Thiruparankundram, Madurai',
              prefixIcon: const Icon(Icons.edit_location_alt_outlined, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check_circle_outline, color: DrGutColors.primary),
                tooltip: 'Apply location',
                onPressed: _onManualLocationSubmitted,
              ),
            ),
            onFieldSubmitted: (_) => _onManualLocationSubmitted(),
            validator: (v) {
              if (_hasError && (v == null || v.trim().isEmpty)) {
                return 'Please provide your location';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
}

/// Stylized Map Logo Badge: Folded map with a deep olive pin & live GPS signal indicator
class MapLogoBadge extends StatelessWidget {
  final bool isLocating;
  final bool hasError;
  final double size;

  const MapLogoBadge({
    super.key,
    this.isLocating = false,
    this.hasError = false,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? DrGutColors.error.withValues(alpha: 0.3)
        : DrGutColors.surfaceBorder;
    final bgColor = hasError
        ? DrGutColors.error.withValues(alpha: 0.08)
        : DrGutColors.primary.withValues(alpha: 0.06);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background folded map illustration
          Icon(
            Icons.map_outlined,
            size: size * 0.54,
            color: hasError
                ? DrGutColors.error.withValues(alpha: 0.35)
                : DrGutColors.primary.withValues(alpha: 0.28),
          ),
          // Foreground location pin logo
          Positioned(
            top: size * 0.14,
            child: Icon(
              Icons.location_on_rounded,
              size: size * 0.50,
              color: hasError ? DrGutColors.error : DrGutColors.primary,
            ),
          ),
          // Active live GPS signal dot in top-right corner
          if (!hasError && !isLocating)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: DrGutColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: DrGutColors.surface, width: 1.2),
                ),
              ),
            ),
          // Locating animated pulse indicator
          if (isLocating)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: DrGutColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

