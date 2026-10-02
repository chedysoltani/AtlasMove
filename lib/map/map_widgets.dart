import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_styles.dart';

/// GoogleMap au style de l'app (clair / sombre #121212) qui ne reconstruit que
/// la carte quand le marqueur chauffeur ou le tracé changent : le reste de
/// l'écran n'est pas rebuildé à chaque frame d'animation.
class BrandedGoogleMap extends StatelessWidget {
  const BrandedGoogleMap({
    super.key,
    required this.initialCameraPosition,
    required this.onMapCreated,
    this.staticMarkers = const <Marker>{},
    this.extraPolylines = const <Polyline>{},
    this.driverMarker,
    this.routePolylines,
    this.padding = EdgeInsets.zero,
    this.onUserGesture,
    this.onCameraMove,
    this.trafficEnabled = false,
    this.tiltGesturesEnabled = true,
    this.rotateGesturesEnabled = true,
    this.styleOverride,
  });

  final CameraPosition initialCameraPosition;
  final MapCreatedCallback onMapCreated;
  final Set<Marker> staticMarkers;
  final Set<Polyline> extraPolylines;
  final ValueListenable<Marker?>? driverMarker;
  final ValueListenable<Set<Polyline>>? routePolylines;
  final EdgeInsets padding;

  /// Appelé au premier contact du doigt : sert à suspendre le suivi caméra.
  final VoidCallback? onUserGesture;
  final CameraPositionCallback? onCameraMove;
  final bool trafficEnabled;
  final bool tiltGesturesEnabled;
  final bool rotateGesturesEnabled;
  final String? styleOverride;

  @override
  Widget build(BuildContext context) {
    final style = styleOverride ??
        MapStyles.forBrightness(Theme.of(context).brightness);
    final listenables = <Listenable>[
      if (driverMarker != null) driverMarker!,
      if (routePolylines != null) routePolylines!,
    ];

    return Listener(
      onPointerDown: (_) => onUserGesture?.call(),
      child: AnimatedBuilder(
        animation: Listenable.merge(listenables),
        builder: (context, _) {
          final driver = driverMarker?.value;
          return GoogleMap(
            initialCameraPosition: initialCameraPosition,
            onMapCreated: onMapCreated,
            style: style,
            markers: {...staticMarkers, if (driver != null) driver},
            polylines: {...extraPolylines, ...?routePolylines?.value},
            onCameraMove: onCameraMove,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: false,
            trafficEnabled: trafficEnabled,
            tiltGesturesEnabled: tiltGesturesEnabled,
            rotateGesturesEnabled: rotateGesturesEnabled,
            padding: padding,
          );
        },
      ),
    );
  }
}

/// Bouton rond flottant au style de la carte (clair / sombre).
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Met l'icône en orange marque (ex. suivi actif).
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final button = Material(
      color: dark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.25),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            size: 22,
            color: active
                ? MapStyles.brandOrange
                : (dark ? Colors.white70 : const Color(0xFF1F2937)),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Boussole : n'apparaît que lorsque la carte est tournée (rotation = -bearing) ;
/// un tap remet le nord en haut.
class MapCompassButton extends StatelessWidget {
  const MapCompassButton({
    super.key,
    required this.bearing,
    required this.onTap,
  });

  final ValueListenable<double> bearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<double>(
      valueListenable: bearing,
      builder: (context, deg, _) {
        final normalized = ((deg % 360) + 360) % 360;
        final visible = normalized > 1 && normalized < 359;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: Material(
              color: dark ? const Color(0xFF1E1E1E) : Colors.white,
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.25),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Transform.rotate(
                    angle: -normalized * math.pi / 180.0,
                    child: const Icon(
                      Icons.navigation_rounded,
                      size: 24,
                      color: MapStyles.brandOrange,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
