import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LiveMapWidget extends StatefulWidget {
  const LiveMapWidget({super.key});

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _initialPos = CameraPosition(
    target: LatLng(37.4279, -122.0857),
    zoom: 14.5,
  );

  // This JSON defines the "Dark Mode" look
  final String _lightMapStyle = '''
[
  { "elementType": "geometry", "stylers": [ { "color": "#f5f5f5" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#ffffff" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#e9e9e9" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#dadada" } ] }
]
''';
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GoogleMap(
          mapType: MapType.normal, // Use normal, then style it below
          initialCameraPosition: _initialPos,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
            // APPLY THE DARK STYLE HERE
            controller.setMapStyle(_lightMapStyle);
            _listenToLocation();
          },
        ),
      ),
    );
  }

  void _listenToLocation() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    });
  }
}
