import 'dart:async';
import 'package:Mowasil/screens/frieght/frieght_page.dart';
import 'package:Mowasil/screens/login/maps/const.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as map;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:page_animation_transition/animations/right_to_left_transition.dart';
import 'package:page_animation_transition/page_animation_transition.dart';
import 'package:permission_handler/permission_handler.dart';

class GoogleMapPage extends StatefulWidget {
  const GoogleMapPage({Key? key}) : super(key: key);

  @override
  _GoogleMapPageState createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  map.GoogleMapController? mapController;
  List<map.Marker> markers = [];
  List<map.Polyline> polylines = [];
  final polylinePoints = PolylinePoints();
  late List<map.LatLng> polylineCoordinates;
  GoogleMapController? myMapController;
  void requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      // Permission granted, proceed with location-related tasks
      _goToCurrentLocation();
    } else {
      // Permission denied, handle accordingly
      print('Location permission denied');
    }
  }

  Future<void> _goToCurrentLocation() async {
    var status = await Permission.location.request();
    if (!status.isGranted) {
      print('Location permission not granted');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15.0,
            ),
          ),
        );
      } else {
        print('Map controller not initialized');
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Map'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(PageAnimationTransition(
                page: const Frieght(),
                pageAnimationType: RightToLeftTransition()));
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchPlace,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: requestLocationPermission,
          ),
        ],
      ),
      body: Stack(
        children: [
          map.GoogleMap(
            initialCameraPosition: const map.CameraPosition(
              target: map.LatLng(31.214606179548785, 29.945679439323985),
              zoom: 15.0,
            ),
            mapType: map.MapType.normal,
            onMapCreated: (map.GoogleMapController controller) {
              mapController = controller;
            },
            onTap: _addMarker,
            markers: Set.from(markers),
            polylines: Set.from(polylines),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: _buildResetButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    if (markers.length >= 2) {
      return FloatingActionButton(
        onPressed: _resetMarkers,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.refresh),
      );
    } else {
      return Container();
    }
  }

  void _addMarker(map.LatLng position) {
    setState(() {
      if (markers.length >= 2) {
        markers.clear();
        polylines.clear();
      }
      markers.add(map.Marker(
        markerId: map.MarkerId(position.toString()),
        position: position,
      ));
      if (markers.length == 2) {
        _getPolyline(markers[0].position, markers[1].position);
      }
    });
  }

  void _resetMarkers() {
    setState(() {
      markers.clear();
      polylines.clear();
    });
  }

  void _getPolyline(map.LatLng origin, map.LatLng destination) async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleMapsApiKey,
      PointLatLng(origin.latitude, origin.longitude),
      PointLatLng(destination.latitude, destination.longitude),
      travelMode: TravelMode.driving,
    );

    if (result.status == 'OK') {
      polylineCoordinates = [];
      for (var point in result.points) {
        polylineCoordinates.add(map.LatLng(point.latitude, point.longitude));
      }

      setState(() {
        polylines.add(map.Polyline(
          polylineId: const map.PolylineId('polyline'),
          color: Colors.blue,
          width: 5,
          points: polylineCoordinates,
        ));
      });
    }
  }

  void _searchPlace() async {
    String? location = await _showLocationInputDialog();
    if (location != null) {
      _updateMap(location);
    }
  }

  Future<String?> _showLocationInputDialog() {
    TextEditingController textFieldController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search Location'),
          content: TextField(
            controller: textFieldController,
            decoration: const InputDecoration(hintText: 'Enter location...'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context, textFieldController.text);
              },
              child: const Text('Search'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _updateMap(String location) async {
    try {
      List<geo.Location> locations = await geo.locationFromAddress(location);
      if (locations.isNotEmpty) {
        mapController!.animateCamera(
          map.CameraUpdate.newCameraPosition(
            map.CameraPosition(
              target: map.LatLng(
                  locations.first.latitude, locations.first.longitude),
              zoom: 15.0, // Adjust the zoom level as needed
            ),
          ),
        );
        setState(() {
          markers.clear();
          markers.add(map.Marker(
            markerId: const map.MarkerId('searched-location'),
            position:
                map.LatLng(locations.first.latitude, locations.first.longitude),
          ));
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location not found!'),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error searching for location!'),
      ));
    }
  }
}
