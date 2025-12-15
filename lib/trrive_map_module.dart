import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// ==============================================================================
// 1. DATA MODELS
// ==============================================================================

class StaticZone {
  final String id;
  final String title;
  final String description;
  final LatLng location;
  final IconData icon;
  final Color neonColor;
  final VoidCallback onTap;

  StaticZone({
    required this.id, 
    required this.title, 
    required this.description, 
    required this.location, 
    required this.icon, 
    required this.neonColor, 
    required this.onTap
  });
}

// ==============================================================================
// 2. THE LIVE NEON MAP
// ==============================================================================

class TrriveNeonMap extends StatefulWidget {
  final LatLng? focusLocation; 
  const TrriveNeonMap({super.key, this.focusLocation});

  @override
  State<TrriveNeonMap> createState() => _TrriveNeonMapState();
}

class _TrriveNeonMapState extends State<TrriveNeonMap> with TickerProviderStateMixin {
  // Default to London (Safe Fallback)
  LatLng _currentPos = const LatLng(51.5, -0.09); 
  bool _loadingLocation = true; // Start true to trigger loading UI
  
  late final MapController _mapController;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  List<StaticZone> staticZones = [];
  bool _isPickingLocation = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    if (widget.focusLocation != null) {
      _currentPos = widget.focusLocation!;
      _loadingLocation = false;
    } 
    // Note: _locateMe is now called in onMapReady to ensure controller is ready

    staticZones = [
      StaticZone(
        id: "cricket_stadium",
        title: "Trivve Stadium",
        description: "Official Cricket Arcade",
        location: const LatLng(12.9750, 77.6000), 
        icon: Icons.sports_cricket,
        neonColor: Colors.cyanAccent,
        onTap: () {}, 
      ),
      StaticZone(
        id: "loot_drop",
        title: "Mystery Crate",
        description: "Contains 500 Coins",
        location: const LatLng(12.9680, 77.5900),
        icon: Icons.inventory_2,
        neonColor: Colors.purpleAccent,
        onTap: () => _showLootDialog(),
      ),
    ];
  }

  // 🛑 FIXED LOCATION FUNCTION
  Future<void> _locateMe() async {
    if (!mounted) return;
    setState(() => _loadingLocation = true);
    
    try {
      // 1. Check Service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw "GPS is disabled. Please turn it on.";
      }

      // 2. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw "Location permission denied.";
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw "Location permanently denied. Check settings.";
      }
      
      // 3. Get Position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      LatLng newPos = LatLng(position.latitude, position.longitude);

      if(mounted) {
        setState(() {
          _currentPos = newPos;
          _loadingLocation = false;
        });
        
        // 4. Move Map (Safe Move)
        _mapController.move(_currentPos, 16.0);
        
        // 5. Update Database
        if (_currentUser != null) {
          FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
            'lastLat': position.latitude,
            'lastLng': position.longitude
          });
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() => _loadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("GPS Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Sports': return Colors.orangeAccent;
      case 'Food': return Colors.redAccent;
      case 'Party': return Colors.pinkAccent;
      case 'Work': return Colors.blueAccent;
      default: return Colors.greenAccent;
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Sports': return Icons.sports_basketball;
      case 'Food': return Icons.fastfood;
      case 'Party': return Icons.music_note;
      case 'Work': return Icons.laptop_chromebook;
      default: return Icons.location_on;
    }
  }

  void _showHostDialog(LatLng pickedLocation) {
    TextEditingController titleCtrl = TextEditingController();
    String selectedCategory = 'Party';
    TimeOfDay selectedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(25)), border: const Border(top: BorderSide(color: Colors.cyanAccent, width: 2))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("BROADCAST SIGNAL 📡", style: TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "EVENT TITLE", labelStyle: TextStyle(color: Colors.grey), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)), prefixIcon: Icon(Icons.flash_on, color: Colors.cyanAccent))),
                const SizedBox(height: 20),
                
                const Text("CATEGORY SIGNAL", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, children: ["Party", "Sports", "Food", "Work"].map((cat) => ChoiceChip(label: Text(cat), selected: selectedCategory == cat, selectedColor: _getCategoryColor(cat), backgroundColor: Colors.black, labelStyle: TextStyle(color: selectedCategory == cat ? Colors.black : Colors.white), onSelected: (val) => setModalState(() => selectedCategory = cat))).toList()),
                
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                    onPressed: () async {
                      if(titleCtrl.text.isEmpty) return;
                      
                      var userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
                      String? mySquadId = userDoc.data()?['squadId'];

                      final now = DateTime.now();
                      final startDateTime = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute);
                      final adjustedStart = startDateTime.isBefore(now.subtract(const Duration(minutes: 15))) ? startDateTime.add(const Duration(days: 1)) : startDateTime;
                      final expiryDateTime = adjustedStart.add(const Duration(minutes: 30));

                      await FirebaseFirestore.instance.collection('rallies').add({
                        'title': titleCtrl.text,
                        'category': selectedCategory,
                        'lat': pickedLocation.latitude,
                        'lng': pickedLocation.longitude,
                        'hostId': _currentUser?.uid,
                        'hostName': _currentUser?.displayName ?? 'Anon',
                        'hostPhoto': _currentUser?.photoURL,
                        'squadId': mySquadId, 
                        'attendees': [_currentUser?.uid], 
                        'timestamp': Timestamp.fromDate(adjustedStart), 
                        'expiry': Timestamp.fromDate(expiryDateTime), 
                      });

                      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
                        'hostingHistory': FieldValue.arrayUnion([{
                          'title': titleCtrl.text,
                          'time': "${selectedTime.format(context)} - ${TimeOfDay.fromDateTime(expiryDateTime).format(context)}",
                          'date': "${now.day}/${now.month}/${now.year}",
                          'location': "${pickedLocation.latitude.toStringAsFixed(3)}, ${pickedLocation.longitude.toStringAsFixed(3)}",
                          'category': selectedCategory
                        }])
                      });
                      
                      if(context.mounted) {
                        Navigator.pop(context); 
                        setState(() => _isPickingLocation = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signal Broadcasted! 📡"), backgroundColor: Colors.cyan));
                      }
                    },
                    child: const Text("GO LIVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                )
              ],
            ),
          );
        }
      )
    );
  }

  void _handleEventTap(Map<String, dynamic> data, String docId) {
    bool isJoined = (data['attendees'] as List).contains(_currentUser?.uid);
    Color themeColor = _getCategoryColor(data['category'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: themeColor)),
        title: Row(
          children: [
            Icon(_getCategoryIcon(data['category']), color: themeColor),
            const SizedBox(width: 10),
            Expanded(child: Text(data['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${(data['attendees'] as List).length} people are here.", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            if (isJoined)
              const Text("You are part of this event.", style: TextStyle(color: Colors.greenAccent))
            else
              const Text("Do you want to join this event?", style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx); 
              
              if (!isJoined) {
                await FirebaseFirestore.instance.collection('rallies').doc(docId).update({
                  'attendees': FieldValue.arrayUnion([_currentUser!.uid])
                });
              }
              
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EventChatScreen(
                    rallyId: docId, 
                    title: data['title'], 
                    color: themeColor
                  )),
                );
              }
            },
            child: Text(isJoined ? "ENTER CHAT" : "JOIN & CHAT", style: const TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showLootDialog() {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.purpleAccent)),
        title: const Text("LOOT FOUND!", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond, size: 60, color: Colors.cyan),
            const SizedBox(height: 20),
            const Text("You found a Rare Crate!", style: TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CLAIM", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rallies')
                .where('expiry', isGreaterThan: Timestamp.now()) 
                .snapshots(),
            builder: (context, snapshot) {
              List<Marker> allMarkers = [];

              // User Location Marker
              allMarkers.add(Marker(
                point: _currentPos,
                width: 80, height: 80,
                child: const PulsingAvatarMarker(),
              ));

              // Static Zones
              for (var zone in staticZones) {
                allMarkers.add(Marker(
                  point: zone.location,
                  width: 60, height: 60,
                  child: GestureDetector(
                    onTap: zone.onTap,
                    child: NeonLocationMarker(icon: zone.icon, color: zone.neonColor, isStatic: true),
                  ),
                ));
              }

              // Dynamic Events from Firestore
              if (snapshot.hasData && !_isPickingLocation) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['lat'] != null && data['lng'] != null) {
                    allMarkers.add(Marker(
                      point: LatLng(data['lat'], data['lng']),
                      width: 50, height: 50,
                      child: GestureDetector(
                        onTap: () => _handleEventTap(data, doc.id),
                        child: NeonLocationMarker(
                          icon: _getCategoryIcon(data['category'] ?? ''), 
                          color: _getCategoryColor(data['category'] ?? ''),
                          isStatic: false
                        ),
                      ),
                    ));
                  }
                }
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPos, 
                  initialZoom: 15.5,
                  // 🛑 FIXED: Calls locateMe when map is actually ready
                  onMapReady: () {
                    if (widget.focusLocation == null) {
                       _locateMe();
                    }
                  }
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),
                  MarkerLayer(markers: allMarkers),
                ],
              );
            }
          ),

          if (!_isPickingLocation)
            Positioned(
              top: 40, left: 20, right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), border: Border.all(color: Colors.white24)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(children: [
                            CircleAvatar(backgroundColor: Colors.cyanAccent, radius: 15, child: Icon(Icons.public, size: 20, color: Colors.black)),
                            SizedBox(width: 10),
                            Text("TRIVVE WORLD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2))
                        ]),
                        Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: _loadingLocation ? Colors.orange : Colors.greenAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(_loadingLocation ? "SCANNING..." : "GPS LOCKED", style: TextStyle(color: _loadingLocation ? Colors.orange : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                        ])
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_isPickingLocation)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 50, color: Colors.cyanAccent),
                  Container(width: 4, height: 40, color: Colors.cyanAccent),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2))),
                ],
              ),
            ),

          if (_isPickingLocation)
             Positioned(
               top: 50, left: 0, right: 0,
               child: Center(
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                   decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.cyanAccent)),
                   child: const Text("DRAG MAP TO SET LOCATION", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                 ),
               ),
             ),

          Positioned(
            bottom: 30, right: 20, left: 20,
            child: _isPickingLocation 
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: "cancel",
                      backgroundColor: Colors.redAccent,
                      label: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)),
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _isPickingLocation = false),
                    ),
                    const SizedBox(width: 20),
                    FloatingActionButton.extended(
                      heroTag: "confirm",
                      backgroundColor: Colors.cyanAccent,
                      label: const Text("SET TIME & HOST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      icon: const Icon(Icons.access_time, color: Colors.black),
                      onPressed: () => _showHostDialog(_mapController.camera.center),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                      FloatingActionButton.small(
                      heroTag: "center",
                      backgroundColor: Colors.grey[900],
                      onPressed: _locateMe,
                      child: const Icon(Icons.my_location, color: Colors.white), 
                    ),
                    const SizedBox(width: 15),
                    FloatingActionButton.extended(
                      heroTag: "host",
                      backgroundColor: Colors.cyanAccent,
                      label: const Text("HOST EVENT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      icon: const Icon(Icons.add_location_alt, color: Colors.black),
                      onPressed: () => setState(() => _isPickingLocation = true),
                    ),
                  ],
                ),
          )
        ],
      ),
    );
  }
}

class EventChatScreen extends StatefulWidget {
  final String rallyId;
  final String title;
  final Color color;

  const EventChatScreen({super.key, required this.rallyId, required this.title, required this.color});

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final User? _user = FirebaseAuth.instance.currentUser;

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    FirebaseFirestore.instance.collection('rallies').doc(widget.rallyId).collection('messages').add({
      'text': _msgCtrl.text.trim(),
      'senderId': _user!.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _msgCtrl.clear();
  }

  void _leaveEvent() {
    FirebaseFirestore.instance.collection('rallies').doc(widget.rallyId).update({
      'attendees': FieldValue.arrayRemove([_user!.uid])
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _leaveEvent, icon: const Icon(Icons.exit_to_app, color: Colors.redAccent))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rallies').doc(widget.rallyId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var d = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    bool isMe = d['senderId'] == _user!.uid;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? widget.color.withOpacity(0.2) : Colors.grey[800],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: isMe ? widget.color.withOpacity(0.5) : Colors.transparent)
                        ),
                        child: Text(d['text'] ?? "", style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: widget.color,
                  child: IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send, color: Colors.black, size: 20)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class PulsingAvatarMarker extends StatefulWidget {
  const PulsingAvatarMarker({super.key});
  @override
  State<PulsingAvatarMarker> createState() => _PulsingAvatarMarkerState();
}

class _PulsingAvatarMarkerState extends State<PulsingAvatarMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80 * _animation.value, height: 80 * _animation.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyanAccent.withOpacity(0.3 * (1 - _animation.value)), border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1)),
            ),
            const CircleAvatar(radius: 20, backgroundColor: Colors.black, child: Icon(Icons.person_pin_circle, color: Colors.cyanAccent, size: 30))
          ],
        );
      },
    );
  }
}

class NeonLocationMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isStatic;

  const NeonLocationMarker({super.key, required this.icon, required this.color, this.isStatic = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isStatic ? 8 : 6),
          decoration: BoxDecoration(
            color: Colors.black, shape: BoxShape.circle,
            border: Border.all(color: color, width: isStatic ? 2 : 1),
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: isStatic ? 15 : 8, spreadRadius: 1)]
          ),
          child: Icon(icon, color: color, size: isStatic ? 24 : 18),
        ),
        Container(height: isStatic ? 10 : 6, width: 2, color: color)
      ],
    );
  }
}