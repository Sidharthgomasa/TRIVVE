import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

// ⚡ TRIVVE ECHO MODULE
// Handles geo-locked anonymous messaging ("Digital Graffiti")

class EchoScreen extends StatefulWidget {
  const EchoScreen({super.key});

  @override
  State<EchoScreen> createState() => _EchoScreenState();
}

class _EchoScreenState extends State<EchoScreen> {
  final TextEditingController _messageController = TextEditingController();
  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 📍 Get User Location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
    }
  }

  // 🚀 Post a new Echo
  Future<void> _dropEcho() async {
    if (_messageController.text.isEmpty || _currentPosition == null) return;

    await FirebaseFirestore.instance.collection('echoes').add({
      'text': _messageController.text.trim(),
      'lat': _currentPosition!.latitude,
      'lng': _currentPosition!.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'whisper', // future: 'shout', 'scream'
    });

    _messageController.clear();
    FocusScope.of(context).unfocus();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("👻 Echo dropped. It will haunt this location."),
        backgroundColor: Colors.tealAccent,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  // 📏 Calculate Distance (Haversine simplified)
  double _getDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // Returns meters
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("THE ECHO", style: TextStyle(letterSpacing: 3, color: Colors.tealAccent)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.tealAccent),
      ),
      body: Column(
        children: [
          // 📡 Radar Status
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.teal.withOpacity(0.1),
            width: double.infinity,
            child: _isLoading 
                ? const Center(child: Text("TRIANGULATING POSITION...", style: TextStyle(color: Colors.tealAccent, fontSize: 10)))
                : Text(
                    _currentPosition != null 
                        ? "📍 LOCATION LOCKED: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}\n📡 SCAN RADIUS: 500m"
                        : "⚠️ GPS SIGNAL LOST",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontFamily: 'Courier'),
                  ),
          ),

          // 👻 Echo Stream
          Expanded(
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('echoes')
                        .orderBy('timestamp', descending: true)
                        .limit(50) // Optimization: Get last 50 global, filter local
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.teal));

                      var allDocs = snapshot.data!.docs;
                      // Client-side Filtering
                      var localEchoes = allDocs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        double dist = _getDistance(
                          _currentPosition!.latitude, 
                          _currentPosition!.longitude, 
                          data['lat'], 
                          data['lng']
                        );
                        return dist <= 500; // Only show within 500m
                      }).toList();

                      if (localEchoes.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.spatial_audio_off, size: 60, color: Colors.grey[800]),
                              const SizedBox(height: 20),
                              const Text("No echoes here.\nBe the first to haunt this spot.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: localEchoes.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          var data = localEchoes[index].data() as Map<String, dynamic>;
                          Timestamp? ts = data['timestamp'];
                          String time = ts != null 
                              ? DateFormat('HH:mm').format(ts.toDate()) 
                              : "Just now";

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              border: Border(left: BorderSide(color: Colors.tealAccent.withOpacity(0.5), width: 4)),
                              borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
                              boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 10)]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['text'], style: const TextStyle(color: Colors.white, fontSize: 16)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          // 📝 Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Colors.grey[800]!))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.tealAccent),
                    decoration: InputDecoration(
                      hintText: "Leave a trace...",
                      hintStyle: TextStyle(color: Colors.teal.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20)
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _dropEcho, 
                  icon: const Icon(Icons.waves), 
                  style: IconButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black)
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}