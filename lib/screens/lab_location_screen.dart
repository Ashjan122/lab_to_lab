import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LabLocationScreen extends StatefulWidget {
  final String labName;
  final String labId;
  const LabLocationScreen({
    super.key,
    required this.labName,
    required this.labId,
  });

  @override
  State<LabLocationScreen> createState() => _LabLocationScreenState();
}

class _LabLocationScreenState extends State<LabLocationScreen> {
  GoogleMapController? _mapController;
  LatLng? selectedLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simple initialization without delay
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load saved location from Firestore
      await _loadSavedLocation();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Location initialization error: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedLocation() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .doc(widget.labId)
              .get();

      if (doc.exists) {
        final data = doc.data();
        final location = data?['location'];

        if (location != null) {
          final lat = location['lat'] as double?;
          final lng = location['lng'] as double?;

          if (lat != null && lng != null) {
            setState(() {
              selectedLocation = LatLng(lat, lng);
            });
          }
        }
      }
    } catch (e) {
      print("Error loading saved location: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Simple location request
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          selectedLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(selectedLocation!),
        );
      }
    } catch (e) {
      print("Error getting current location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("خطأ في الحصول على الموقع"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    if (selectedLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("الرجاء اختيار موقع أولاً"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('labToLap')
          .doc(widget.labId)
          .set({
            "location": {
              "lat": selectedLocation!.latitude,
              "lng": selectedLocation!.longitude,
            },
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم حفظ الموقع بنجاح"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error saving location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("خطأ في حفظ الموقع"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openInGoogleMaps(double lat, double lng) async {
    final Uri googleMapUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    if (await canLaunchUrl(googleMapUrl)) {
      await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن فتح تطبيق الخرائط'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'موقع ${widget.labName}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body: SafeArea(
          child:
              _isLoading
                  ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("جاري تحميل الخريطة..."),
                      ],
                    ),
                  )
                  : Column(
                    children: [
                      Expanded(
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target:
                                selectedLocation ??
                                const LatLng(15.5007, 32.5599),
                            zoom: 12,
                          ),
                          onMapCreated: (GoogleMapController controller) {
                            _mapController = controller;
                            // Move camera to saved location if available
                            if (selectedLocation != null) {
                              controller.animateCamera(
                                CameraUpdate.newLatLng(selectedLocation!),
                              );
                            }
                          },
                          onTap: (LatLng position) {
                            if (mounted) {
                              setState(() {
                                selectedLocation = position;
                              });
                            }
                          },
                          markers:
                              selectedLocation != null
                                  ? {
                                    Marker(
                                      markerId: const MarkerId("LabLocation"),
                                      position: selectedLocation!,
                                      infoWindow: const InfoWindow(
                                        title: "اضغط للذهاب",
                                        snippet: "افتح في خرائط Google",
                                      ),
                                      onTap: () {
                                        _openInGoogleMaps(
                                          selectedLocation!.latitude,
                                          selectedLocation!.longitude,
                                        );
                                      },
                                    ),
                                  }
                                  : {},
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _getCurrentLocation,
                              label: const Text("موقعي الحالي"),
                              icon: const Icon(Icons.my_location),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF673AB7),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _saveLocation,
                              label: const Text("حفظ الموقع"),
                              icon: const Icon(Icons.save),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
