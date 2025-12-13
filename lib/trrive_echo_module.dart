import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// =============================================================================
// 🗣️ THE ECHO: LOCATION-BASED ANONYMOUS FEED & CHAT
// =============================================================================

class EchoScreen extends StatefulWidget {
  const EchoScreen({super.key});

  @override
  State<EchoScreen> createState() => _EchoScreenState();
}

class _EchoScreenState extends State<EchoScreen> {
  Position? _currentPosition;
  bool _isLoading = true;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() { _isLoading = true; _gpsError = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw "GPS service is disabled.";

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Location permission denied.";
      }
      
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _gpsError = e.toString(); });
    }
  }

  void _openPostDialog() {
    if (_currentPosition == null) {
      _getCurrentLocation(); // Try again
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EchoComposeDialog(initialPos: LatLng(_currentPosition!.latitude, _currentPosition!.longitude)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)));

    if (_currentPosition == null || _gpsError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, color: Colors.red, size: 50),
              const SizedBox(height: 20),
              Text(_gpsError ?? "GPS REQUIRED", style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(onPressed: _getCurrentLocation, child: const Text("RETRY GPS", style: TextStyle(color: Colors.tealAccent)))
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("THE ECHO 📡", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _getCurrentLocation)
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('echoes').orderBy('timestamp', descending: true).limit(100).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error loading echoes: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.teal));

          var allDocs = snapshot.data!.docs;
          
          var nearbyDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['lat'] == null || data['lng'] == null) return false;
            
            double dist = Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude, 
              data['lat'], data['lng']
            );
            return dist <= 500; // 500m Radius
          }).toList();

          if (nearbyDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.spatial_audio_off, size: 80, color: Colors.teal.withOpacity(0.3)),
                  const SizedBox(height: 20),
                  const Text("SILENCE...", style: TextStyle(color: Colors.white54, fontSize: 18, letterSpacing: 5)),
                  const SizedBox(height: 10),
                  const Text("No echoes within 500m.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: nearbyDocs.length,
            itemBuilder: (context, index) {
              var doc = nearbyDocs[index];
              var data = doc.data() as Map<String, dynamic>;
              double dist = Geolocator.distanceBetween(
                _currentPosition!.latitude, _currentPosition!.longitude, 
                data['lat'], data['lng']
              );

              return _EchoCard(
                data: data, 
                docId: doc.id,
                distance: dist
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPostDialog,
        backgroundColor: Colors.tealAccent,
        icon: const Icon(Icons.record_voice_over, color: Colors.black),
        label: const Text("DROP ECHO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// =============================================================================
// 📝 COMPOSE DIALOG (WITH SPINNER)
// =============================================================================

class EchoComposeDialog extends StatefulWidget {
  final LatLng initialPos;
  const EchoComposeDialog({super.key, required this.initialPos});

  @override
  State<EchoComposeDialog> createState() => _EchoComposeDialogState();
}

class _EchoComposeDialogState extends State<EchoComposeDialog> {
  final TextEditingController _textCtrl = TextEditingController();
  String _selectedCategory = "Sigma"; 
  late LatLng _pickedLocation;
  late MapController _mapController;
  bool _gettingLoc = false;
  bool _isPosting = false; // 👈 New loading state

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialPos;
    _mapController = MapController();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _snapToUser() async {
    setState(() => _gettingLoc = true);
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng newPos = LatLng(pos.latitude, pos.longitude);
      setState(() { _pickedLocation = newPos; _gettingLoc = false; });
      _mapController.move(newPos, 16.0); 
    } catch (e) {
      setState(() => _gettingLoc = false);
    }
  }

  void _postEcho() async {
    if (_textCtrl.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isPosting = true); // 👈 Start loading

    try {
      await FirebaseFirestore.instance.collection('echoes').add({
        'text': _textCtrl.text.trim(),
        'category': _selectedCategory,
        'lat': _pickedLocation.latitude,
        'lng': _pickedLocation.longitude,
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to post: $e")));
      }
    }
  }

  Color _getCatColor(String cat) {
    if (cat == "Sigma") return Colors.purpleAccent;
    if (cat == "Alpha") return Colors.redAccent;
    return Colors.orangeAccent; 
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), border: const Border(top: BorderSide(color: Colors.tealAccent, width: 2))),
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("DROP ECHO", style: TextStyle(color: Colors.tealAccent, fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))])),
          Expanded(flex: 4, child: Stack(children: [FlutterMap(mapController: _mapController, options: MapOptions(initialCenter: _pickedLocation, initialZoom: 16, onPositionChanged: (pos, hasGesture) { if (hasGesture) setState(() => _pickedLocation = pos.center); }), children: [TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', subdomains: const ['a','b','c'])]),const Center(child: Icon(Icons.location_on, size: 40, color: Colors.tealAccent)), Positioned(bottom: 20, right: 20, child: FloatingActionButton.small(backgroundColor: Colors.tealAccent, onPressed: _snapToUser, child: _gettingLoc ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.my_location, color: Colors.black)))])),
          Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text("CATEGORY", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ["Sigma", "Alpha", "Only Gossip"].map((cat) => ChoiceChip(label: Text(cat), selected: _selectedCategory == cat, selectedColor: _getCatColor(cat), backgroundColor: Colors.black, labelStyle: TextStyle(color: _selectedCategory == cat ? Colors.black : Colors.white, fontWeight: FontWeight.bold), onSelected: (v) => setState(() => _selectedCategory = cat))).toList()),
            const SizedBox(height: 20),
            TextField(controller: _textCtrl, maxLines: 4, style: const TextStyle(color: Colors.white, fontSize: 18), decoration: InputDecoration(hintText: "What's happening?", hintStyle: TextStyle(color: Colors.grey[600]), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
            const Spacer(),
            SizedBox(
              height: 50, 
              child: ElevatedButton.icon(
                onPressed: _isPosting ? null : _postEcho, // 👈 Disable while posting
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent), 
                icon: _isPosting ? const SizedBox() : const Icon(Icons.send, color: Colors.black), 
                label: _isPosting 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text("BROADCAST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
              )
            )
          ])))
        ],
      ),
    );
  }
}

// =============================================================================
// 🃏 ECHO CARD
// =============================================================================

class _EchoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final double distance;

  const _EchoCard({required this.data, required this.docId, required this.distance});

  Color _getBorderColor(String cat) {
    if (cat == "Sigma") return Colors.purpleAccent;
    if (cat == "Alpha") return Colors.redAccent;
    return Colors.orangeAccent;
  }

  void _deleteEcho(BuildContext context) async {
    bool confirm = await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("DELETE SIGNAL?", style: TextStyle(color: Colors.redAccent)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("CANCEL")),
          TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('echoes').doc(docId).delete();
    }
  }

  void _openChat(BuildContext context, Color theme) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EchoChatScreen(echoId: docId, title: data['text'], themeColor: theme)));
  }

  @override
  Widget build(BuildContext context) {
    String cat = data['category'] ?? "Gossip";
    Color theme = _getBorderColor(cat);
    DateTime time = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    bool isMine = data['uid'] == FirebaseAuth.instance.currentUser?.uid;

    return GestureDetector(
      onTap: () => _openChat(context, theme), 
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15), border: Border(left: BorderSide(color: theme, width: 4)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(cat.toUpperCase(), style: TextStyle(color: theme, fontWeight: FontWeight.bold, fontSize: 10))),
                    const SizedBox(width: 8),
                    Text("${distance.toStringAsFixed(0)}m away", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
                if (isMine) InkWell(onTap: () => _deleteEcho(context), child: const Icon(Icons.delete, color: Colors.redAccent, size: 18))
            ]),
            const SizedBox(height: 12),
            Text(data['text'], style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(timeago.format(time), style: TextStyle(color: Colors.grey[700], fontSize: 10)),
                Row(children: [Text("JOIN CHAT", style: TextStyle(color: theme, fontWeight: FontWeight.bold, fontSize: 10)), Icon(Icons.arrow_forward_ios, color: theme, size: 10)])
            ])
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 💬 ECHO CHAT SCREEN
// =============================================================================

class EchoChatScreen extends StatefulWidget {
  final String echoId;
  final String title;
  final Color themeColor;

  const EchoChatScreen({super.key, required this.echoId, required this.title, required this.themeColor});

  @override
  State<EchoChatScreen> createState() => _EchoChatScreenState();
}

class _EchoChatScreenState extends State<EchoChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    
    setState(() => _isSending = true); // 👈 Show loading on button

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Auth Error: Re-login required")));
      }
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('echoes').doc(widget.echoId).collection('messages').add({
        'text': _msgCtrl.text.trim(),
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if(mounted) {
        _msgCtrl.clear();
        setState(() => _isSending = false);
      }
    } catch (e) {
      if(mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("ECHO CHANNEL", style: TextStyle(color: Colors.white, fontSize: 12)),
            Text(widget.title, style: TextStyle(color: widget.themeColor, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('echoes').doc(widget.echoId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Be the first to reply...", style: TextStyle(color: Colors.grey)));

                final currentUser = FirebaseAuth.instance.currentUser;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var d = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    bool isMe = currentUser != null && d['uid'] == currentUser.uid;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? widget.themeColor.withOpacity(0.2) : Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isMe ? widget.themeColor.withOpacity(0.5) : Colors.transparent)
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
            padding: const EdgeInsets.all(10),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Reply anonymously...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: widget.themeColor),
                  onPressed: _isSending ? null : _sendMessage, 
                  icon: _isSending 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                    : const Icon(Icons.send, color: Colors.black, size: 18)
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}