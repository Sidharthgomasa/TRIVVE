import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class TheHuntScreen extends StatefulWidget {
  const TheHuntScreen({super.key});

  @override
  State<TheHuntScreen> createState() => _TheHuntScreenState();
}

class _TheHuntScreenState extends State<TheHuntScreen> {
  // -- State Variables --
  GoogleMapController? _mapController;
  Position? _myPosition;
  DocumentSnapshot? _targetUser;
  bool _isInRange = false;
  StreamSubscription<Position>? _positionStream;

  // -- Constants --
  final double _killRadius = 15.0; // Meters to enable kill
  final double _targetFuzzRadius = 50.0; // Meters for the red circle

  // -- THE DARK THEME JSON --
  final String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#242f3e"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#746855"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#242f3e"}]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#d59563"}]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#d59563"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [{"color": "#263c3f"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#6b9a76"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#38414e"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#212a37"}]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#9ca5b3"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#17263c"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _startHunting();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // 1. START THE HUNT (Get Permission & Stream Location)
  Future<void> _startHunting() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      setState(() {
        _myPosition = position;
      });
      _checkDistance();
    });
  }

  // 2. CHECK DISTANCE TO TARGET
  void _checkDistance() {
    if (_myPosition == null || _targetUser == null) return;
    
    Map<String, dynamic> data = _targetUser!.data() as Map<String, dynamic>;
    if (!data.containsKey('lastLat') || !data.containsKey('lastLng')) return;

    double targetLat = data['lastLat'];
    double targetLng = data['lastLng'];

    double distanceInMeters = Geolocator.distanceBetween(
      _myPosition!.latitude,
      _myPosition!.longitude,
      targetLat,
      targetLng,
    );

    setState(() {
      _isInRange = distanceInMeters < _killRadius;
    });
  }

  // 3. THE KILL ACTION
  Future<void> _eliminateTarget() async {
    if (_targetUser == null) return;
    
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final targetUid = _targetUser!.id;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
        DocumentReference targetRef = FirebaseFirestore.instance.collection('users').doc(targetUid);

        DocumentSnapshot mySnap = await transaction.get(myRef);
        DocumentSnapshot targetSnap = await transaction.get(targetRef);

        int targetAura = (targetSnap.data() as Map<String, dynamic>)['aura'] ?? 0;
        int stolenAura = (targetAura * 0.2).floor();
        
        transaction.update(myRef, {
          'aura': ((mySnap.data() as Map<String, dynamic>)['aura'] ?? 0) + stolenAura + 100,
          'wins': ((mySnap.data() as Map<String, dynamic>)['wins'] ?? 0) + 1,
          'targetUid': FieldValue.delete(),
        });

        transaction.update(targetRef, {
          'aura': targetAura - stolenAura,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("TARGET ELIMINATED. AURA STOLEN. 💀"), backgroundColor: Colors.red),
      );
      setState(() {
        _targetUser = null;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kill Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        String? currentTargetId = userData['targetUid'];

        if (currentTargetId == null) {
          return _buildNoTargetView();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentTargetId).snapshots(),
          builder: (context, targetSnap) {
            if (!targetSnap.hasData) return const Center(child: CircularProgressIndicator());
            
            _targetUser = targetSnap.data;
            var targetData = _targetUser!.data() as Map<String, dynamic>;
            
            double? tLat = targetData['lastLat'];
            double? tLng = targetData['lastLng'];
            
            return Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  if (tLat != null && tLng != null)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: LatLng(tLat, tLng), zoom: 17),
                      // ✅ FIX: Use normal map type + custom dark style
                      mapType: MapType.normal, 
                      myLocationEnabled: true,
                      circles: {
                        Circle(
                          circleId: const CircleId('targetZone'),
                          center: LatLng(tLat, tLng),
                          radius: _targetFuzzRadius, 
                          fillColor: Colors.red.withOpacity(0.3),
                          strokeColor: Colors.red,
                          strokeWidth: 2,
                        ),
                      },
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        // ✅ APPLY DARK MODE STYLE HERE
                        controller.setMapStyle(_darkMapStyle);
                      },
                    )
                  else
                    const Center(child: Text("Target is off the grid...", style: TextStyle(color: Colors.grey))),

                  Positioned(
                    top: 50, left: 20, right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        border: Border.all(color: Colors.redAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(targetData['photoUrl'] ?? ""),
                            radius: 25,
                            backgroundColor: Colors.grey,
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TARGET: ${targetData['username'] ?? 'Unknown'}", 
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                              const Text("Find them in the Red Zone", 
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 40, left: 20, right: 20,
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isInRange ? Colors.red : Colors.grey[900],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          shadowColor: Colors.redAccent,
                          elevation: _isInRange ? 20 : 0,
                        ),
                        onPressed: _isInRange ? _eliminateTarget : null,
                        child: Text(
                          _isInRange ? "⚠️ ELIMINATE TARGET ⚠️" : "TARGET OUT OF RANGE",
                          style: TextStyle(
                            color: _isInRange ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold, 
                            fontSize: 18,
                            letterSpacing: 2
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoTargetView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_searching, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("NO ACTIVE CONTRACT", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Join the lobby to get a target.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Logic to assign a random target
              }, 
              child: const Text("ENTER THE HUNT"),
            )
          ],
        ),
      ),
    );
  }
}