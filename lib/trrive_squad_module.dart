import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trivve/gamepage.dart'; 
import 'package:trivve/trrive_map_module.dart'; // ✅ REQUIRED FOR MAP LINK

// =============================================================================
// ⚡ TRIVVE SQUAD HUB 5.0 (GPS FIXED)
// =============================================================================

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});
  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _squadId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snapshot) {
        if (mounted) setState(() { _squadId = snapshot.data()?['squadId']; _isLoading = false; });
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
    if (_squadId != null && _squadId!.isNotEmpty) return SquadDashboard(squadId: _squadId!);
    return const JoinCreateSquadView();
  }
}

class SquadDashboard extends StatefulWidget {
  final String squadId;
  const SquadDashboard({super.key, required this.squadId});
  @override
  State<SquadDashboard> createState() => _SquadDashboardState();
}

class _SquadDashboardState extends State<SquadDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _revealCode = false;
  final TextEditingController _chatMsgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _updateMySquadLocation(); 
  }

  @override
  void dispose() {
    _chatMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateMySquadLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
          'lastLat': position.latitude, 'lastLng': position.longitude, 'lastActive': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) { print("SQUAD GPS ERROR: $e"); }
  }

  void _leaveSquad() async {
    bool confirm = await _showConfirmDialog("ABORT MISSION?", "Leave this squad? You will need a code to rejoin.");
    if (!confirm) return;
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({'squadId': null});
    await FirebaseFirestore.instance.collection('squads').doc(widget.squadId).update({'members': FieldValue.arrayRemove([_currentUser!.uid])});
  }

  void _kickMember(String targetUid, String targetName) async {
    bool confirm = await _showConfirmDialog("KICK MEMBER?", "Remove $targetName from the squad?");
    if (!confirm) return;
    await FirebaseFirestore.instance.collection('squads').doc(widget.squadId).update({'members': FieldValue.arrayRemove([targetUid])});
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({'squadId': null});
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$targetName WAS REMOVED")));
  }

  Future<bool> _showConfirmDialog(String title, String body) async {
    return await showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: Colors.grey[900], title: Text(title, style: const TextStyle(color: Colors.redAccent)), content: Text(body, style: const TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("CONFIRM"))])) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8), elevation: 0,
        flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('squads').doc(widget.squadId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text("LOADING...");
            var data = snapshot.data!.data() as Map<String, dynamic>;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)), GestureDetector(onTap: () => setState(() => _revealCode = !_revealCode), child: Text(_revealCode ? "CODE: ${data['code']}" : "CODE: ****** (TAP)", style: TextStyle(color: _revealCode ? Colors.white : Colors.grey, fontSize: 10)))]);
          },
        ),
        actions: [IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.redAccent), onPressed: _leaveSquad)],
        bottom: TabBar(
          controller: _tabController, isScrollable: true, indicatorColor: Colors.cyanAccent, labelColor: Colors.cyanAccent, unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: "CHAT", icon: Icon(Icons.chat_bubble_outline, size: 18)), Tab(text: "DUEL", icon: Icon(Icons.sports_kabaddi, size: 18)), Tab(text: "RANK", icon: Icon(Icons.leaderboard, size: 18)), Tab(text: "MAP", icon: Icon(Icons.map, size: 18)), Tab(text: "EVENTS", icon: Icon(Icons.event, size: 18))],
        ),
      ),
      body: CyberBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildChatSection(),
              _buildChallengeSection(),
              _buildDualLeaderboard(),
              _buildSquadMap(), 
              _buildEventsFeed(),
            ],
          ),
        ),
      ),
    );
  }

  // --- SQUAD MAP ---
  Widget _buildSquadMap() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('squadId', isEqualTo: widget.squadId).snapshots(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        List<Marker> markers = []; LatLng center = const LatLng(20.5937, 78.9629); bool hasMyLoc = false;
        for(var doc in snapshot.data!.docs) {
          var u = doc.data() as Map<String, dynamic>;
          if(u['lastLat'] != null && u['lastLng'] != null) {
            double lat = (u['lastLat'] is int) ? (u['lastLat'] as int).toDouble() : u['lastLat'];
            double lng = (u['lastLng'] is int) ? (u['lastLng'] as int).toDouble() : u['lastLng'];
            LatLng pos = LatLng(lat, lng);
            if(doc.id == _currentUser!.uid) { center = pos; hasMyLoc = true; }
            markers.add(Marker(point: pos, width: 70, height: 70, child: Column(children: [Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: doc.id == _currentUser!.uid ? Colors.greenAccent : Colors.cyanAccent, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 5)]), child: CircleAvatar(radius: 18, backgroundImage: (u['photoUrl'] != null && u['photoUrl'].toString().isNotEmpty) ? NetworkImage(u['photoUrl']) : null, child: u['photoUrl'] == null ? const Icon(Icons.person, size: 15) : null)), Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: Text(u['displayName']??'Agent', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))])));
          }
        }
        if (markers.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.satellite_alt, color: Colors.grey, size: 50), const SizedBox(height: 10), const Text("NO SQUAD SIGNALS DETECTED", style: TextStyle(color: Colors.grey)), TextButton(onPressed: _updateMySquadLocation, child: const Text("BROADCAST MY SIGNAL", style: TextStyle(color: Colors.cyanAccent)))]));
        return FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: hasMyLoc ? 14 : 4), 
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', 
              subdomains: const ['a','b','c'],
              retinaMode: RetinaMode.isHighDensity(context), // ✅ FIXED HERE
            ), 
            MarkerLayer(markers: markers)
          ]
        );
      },
    );
  }

  // --- EVENTS FEED ---
  Widget _buildEventsFeed() {
    return Column(children: [
      Container(padding: const EdgeInsets.all(15), alignment: Alignment.centerLeft, child: const Text("SQUAD ACTIVITY FEED", style: TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold))),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rallies').where('squadId', isEqualTo: widget.squadId).where('expiry', isGreaterThan: Timestamp.now()).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("DATABASE ERROR: ${snapshot.error}", style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)); 
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("NO ACTIVE SIGNALS", style: TextStyle(color: Colors.grey)));
          
          return ListView.builder(padding: const EdgeInsets.all(15), itemCount: snapshot.data!.docs.length, itemBuilder: (context, index) {
            var event = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String? photo = event['hostPhoto'];
            
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TrriveNeonMap(focusLocation: LatLng(event['lat'], event['lng'])))),
              child: CyberGlassBox(borderColor: Colors.pinkAccent, glow: true, child: Padding(padding: const EdgeInsets.all(15.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.satellite_alt, color: Colors.pinkAccent), const SizedBox(width: 10), Expanded(child: Text(event['title'] ?? "OP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(5)), child: const Text("LIVE NOW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]), const SizedBox(height: 10), Row(children: [CircleAvatar(radius: 10, backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null, child: (photo == null || photo.isEmpty) ? const Icon(Icons.person, size: 10) : null), const SizedBox(width: 5), Text("Signal Source: ${event['hostName']}", style: const TextStyle(color: Colors.grey, fontSize: 12))]), const SizedBox(height: 10), const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text("TAP TO LOCATE ON MAP  >>", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 1))])])))
            );
          });
        }
      ))
    ]);
  }

  Map<String, dynamic> _getInitialState(String type, String uid) {
    if(type == 'cricket') return {'p1Score': -1, 'p2Score': -1};
    if(type == 'snake') return {'p1Score': -1, 'p2Score': -1};
    if(type == 'tictactoe') return {'board': List.filled(9, ''), 'turn': uid};
    if(type == 'rps') return {'p1Move': '', 'p2Move': ''};
    return {};
  }

  // --- CHAT & CHALLENGE (FIXED) ---
  Widget _buildChatSection() {
    void sendMessage() { 
      if (_chatMsgCtrl.text.trim().isEmpty) return; 
      FirebaseFirestore.instance.collection('squads').doc(widget.squadId).collection('messages').add({ 'type': 'text', 'text': _chatMsgCtrl.text.trim(), 'senderId': _currentUser!.uid, 'senderName': _currentUser!.displayName ?? 'Agent', 'timestamp': FieldValue.serverTimestamp() }); 
      _chatMsgCtrl.clear(); 
    }
    return Column(children: [
      Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('squads').doc(widget.squadId).collection('messages').orderBy('timestamp', descending: true).limit(50).snapshots(), builder: (context, snapshot) { 
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)); 
        return ListView.builder(reverse: true, itemCount: snapshot.data!.docs.length, padding: const EdgeInsets.all(15), itemBuilder: (context, index) { 
          var data = snapshot.data!.docs[index].data() as Map<String, dynamic>; bool isMe = data['senderId'] == _currentUser!.uid; 
          if(data['type'] == 'invite') return _buildInviteCard(data, isMe); 
          return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: isMe ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if(!isMe) Text(data['senderName'], style: const TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold)), Text(data['text'] ?? '', style: const TextStyle(color: Colors.white))]))); }); 
      })), 
      Container(padding: const EdgeInsets.all(10), color: Colors.black87, child: Row(children: [Expanded(child: TextField(controller: _chatMsgCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "SQUAD COMMS...", filled: true, fillColor: Colors.grey[900], border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))), IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: sendMessage)]))]);
  }

  Widget _buildInviteCard(Map<String, dynamic> data, bool isMe) { return Container(margin: const EdgeInsets.symmetric(vertical: 10), child: CyberGlassBox(borderColor: Colors.purpleAccent, glow: true, child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [Text("⚔️ ${data['senderName']} WANTS TO FIGHT", style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text("GAME: ${data['gameType'].toString().toUpperCase()}", style: const TextStyle(color: Colors.white70, fontSize: 10)), const SizedBox(height: 10), if(!isMe) NeonButton(text: "ACCEPT DUEL", color: Colors.purpleAccent, onPressed: () async { await FirebaseFirestore.instance.collection('games').doc(data['gameId']).update({'player2': _currentUser!.uid, 'player2Name': _currentUser!.displayName, 'status': 'playing'}); if(mounted) Navigator.push(context, MaterialPageRoute(builder: (c) => OnlineGameScreen(gameId: data['gameId'], gameType: data['gameType']))); }) else const Text("INVITE SENT", style: TextStyle(color: Colors.grey, fontSize: 10))])))); }

  Widget _buildChallengeSection() { return Column(children: [const Padding(padding: EdgeInsets.all(20), child: Text("SELECT A TARGET", style: TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold))), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').where('squadId', isEqualTo: widget.squadId).snapshots(), builder: (context, snapshot) { if(!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)); var members = snapshot.data!.docs.where((d) => d.id != _currentUser!.uid).toList(); if(members.isEmpty) return const Center(child: Text("NO OTHER AGENTS ONLINE", style: TextStyle(color: Colors.grey))); return ListView.builder(itemCount: members.length, padding: const EdgeInsets.symmetric(horizontal: 20), itemBuilder: (context, index) { var user = members[index].data() as Map<String, dynamic>; return Card(color: Colors.grey[900], margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.purpleAccent, width: 1)), child: ListTile(leading: CircleAvatar(backgroundImage: (user['photoUrl']!=null && user['photoUrl'].toString().isNotEmpty)?NetworkImage(user['photoUrl']):null, backgroundColor: Colors.black, child: user['photoUrl']==null?const Icon(Icons.person):null), title: Text(user['displayName']??'Agent', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent), child: const Text("FIGHT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), onPressed: () => _showGamePicker(members[index].id, user['displayName'])))); }); }))]); }
  void _showGamePicker(String opponentId, String opponentName) { showModalBottomSheet(context: context, backgroundColor: Colors.black, builder: (c) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Text("CHALLENGE $opponentName", style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 20), Wrap(spacing: 10, runSpacing: 10, children: [_gameOption("tictactoe", "Tic Tac Toe"), _gameOption("cricket", "Super Over"), _gameOption("snake", "Cyber Snake"), _gameOption("rps", "RPS")])]))); }
  Widget _gameOption(String type, String label) => ActionChip(backgroundColor: Colors.grey[900], label: Text(label, style: const TextStyle(color: Colors.white)), onPressed: () => _sendInvite(type));
  void _sendInvite(String type) async { Navigator.pop(context); String gameId = String.fromCharCodes(Iterable.generate(4, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(32)))); await FirebaseFirestore.instance.collection('games').doc(gameId).set({'type': type, 'host': _currentUser!.uid, 'hostName': _currentUser!.displayName, 'status': 'waiting', 'squadId': widget.squadId, 'state': _getInitialState(type, _currentUser!.uid), 'winner': null}); await FirebaseFirestore.instance.collection('squads').doc(widget.squadId).collection('messages').add({'type': 'invite', 'gameId': gameId, 'gameType': type, 'senderId': _currentUser!.uid, 'senderName': _currentUser!.displayName, 'timestamp': FieldValue.serverTimestamp()}); _tabController.animateTo(0); }

  Widget _buildDualLeaderboard() { return DefaultTabController(length: 2, child: Column(children: [Container(color: Colors.black54, child: const TabBar(indicatorColor: Colors.amber, labelColor: Colors.amber, unselectedLabelColor: Colors.grey, tabs: [Tab(text: "GLOBAL STATS"), Tab(text: "SQUAD WARS")])), Expanded(child: TabBarView(children: [_buildRankList(fieldWin: 'wins', fieldAura: 'aura', color: Colors.cyanAccent), _buildRankList(fieldWin: 'squadWins', fieldAura: 'squadAura', color: Colors.amber)]))])); }
  Widget _buildRankList({required String fieldWin, required String fieldAura, required Color color}) { return StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('squads').doc(widget.squadId).snapshots(), builder: (context, squadSnap) { if(!squadSnap.hasData) return const SizedBox(); String leaderId = squadSnap.data!['leader']; return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').where('squadId', isEqualTo: widget.squadId).orderBy(fieldWin, descending: true).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); return ListView.builder(padding: const EdgeInsets.all(15), itemCount: snapshot.data!.docs.length, itemBuilder: (context, index) { var doc = snapshot.data!.docs[index]; var user = doc.data() as Map<String, dynamic>; bool isLeader = doc.id == leaderId; return CyberGlassBox(borderColor: color.withOpacity(0.5), child: ListTile(leading: Text("#${index+1}", style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)), title: Row(children: [Text(user['displayName']??'Agent', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), if(isLeader) const Padding(padding: EdgeInsets.only(left:5), child: Icon(Icons.star, size: 12, color: Colors.purpleAccent))]), subtitle: Text("${user[fieldAura]??0} AURA POINTS", style: TextStyle(color: color, fontSize: 10)), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("${user[fieldWin]??0}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const Text("WINS", style: TextStyle(color: Colors.grey, fontSize: 8))]), onLongPress: (isLeader && _currentUser!.uid == leaderId && doc.id != _currentUser!.uid) ? () => _kickMember(doc.id, user['displayName']) : null)); }); }); }); }
}

class JoinCreateSquadView extends StatefulWidget { const JoinCreateSquadView({super.key}); @override State<JoinCreateSquadView> createState() => _JoinCreateSquadViewState(); }
class _JoinCreateSquadViewState extends State<JoinCreateSquadView> { final _codeCtrl = TextEditingController(); final _nameCtrl = TextEditingController(); bool _busy = false; Future<void> _join() async { setState(() => _busy = true); try { final q = await FirebaseFirestore.instance.collection('squads').where('code', isEqualTo: _codeCtrl.text.trim().toUpperCase()).get(); if (q.docs.isEmpty) throw "INVALID FREQUENCY"; await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({'squadId': q.docs.first.id}); await FirebaseFirestore.instance.collection('squads').doc(q.docs.first.id).update({'members': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid])}); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))); } if (mounted) setState(() => _busy = false); } Future<void> _create() async { setState(() => _busy = true); try { String code = String.fromCharCodes(Iterable.generate(6, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(36)))); String id = "${_nameCtrl.text.trim().toLowerCase()}_$code"; await FirebaseFirestore.instance.collection('squads').doc(id).set({'name': _nameCtrl.text.trim(), 'code': code, 'leader': FirebaseAuth.instance.currentUser!.uid, 'members': [FirebaseAuth.instance.currentUser!.uid], 'createdAt': FieldValue.serverTimestamp()}); await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({'squadId': id}); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))); } if (mounted) setState(() => _busy = false); } @override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.black, body: CyberBackground(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: SingleChildScrollView(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.security, size: 80, color: Colors.cyanAccent), const SizedBox(height: 20), const Text("UPLINK REQUIRED", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)), const SizedBox(height: 10), const Text("ESTABLISH SQUAD CONNECTION", style: TextStyle(color: Colors.grey, letterSpacing: 1)), const SizedBox(height: 50), CyberGlassBox(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [TextField(controller: _codeCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, letterSpacing: 5, fontSize: 20), decoration: const InputDecoration(filled: true, fillColor: Colors.black26, hintText: "ACCESS CODE", hintStyle: TextStyle(color: Colors.grey, fontSize: 12))), const SizedBox(height: 15), NeonButton(text: "INITIATE LINK", onPressed: _busy ? null : _join)]))), const SizedBox(height: 30), const Text("- OR -", style: TextStyle(color: Colors.white24)), const SizedBox(height: 30), CyberGlassBox(borderColor: Colors.purpleAccent, child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [TextField(controller: _nameCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(filled: true, fillColor: Colors.black26, hintText: "NEW PROTOCOL NAME", hintStyle: TextStyle(color: Colors.grey))), const SizedBox(height: 15), NeonButton(text: "ESTABLISH SQUAD", color: Colors.purpleAccent, onPressed: _busy ? null : _create)])))])))))); } }

// --- UI COMPONENTS ---
class CyberBackground extends StatefulWidget { final Widget child; const CyberBackground({super.key, required this.child}); @override State<CyberBackground> createState() => _CyberBackgroundState(); }
class _CyberBackgroundState extends State<CyberBackground> with SingleTickerProviderStateMixin { late AnimationController _controller; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return Stack(children: [Container(color: const Color(0xFF050505)), AnimatedBuilder(animation: _controller, builder: (context, child) => CustomPaint(painter: GridPainter(_controller.value), child: Container())), Container(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.center, radius: 1.5, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))), widget.child]); } }
class GridPainter extends CustomPainter { final double value; GridPainter(this.value); @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = Colors.purpleAccent.withOpacity(0.1)..strokeWidth = 1; for (double x = 0; x < size.width; x += 40) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint); } double offset = value * 40; for (double y = offset; y < size.height; y += 40) { canvas.drawLine(Offset(0, y), Offset(size.width, y), paint); } } @override bool shouldRepaint(covariant GridPainter oldDelegate) => true; }
class CyberGlassBox extends StatelessWidget { final Widget child; final Color borderColor; final bool glow; const CyberGlassBox({super.key, required this.child, this.borderColor = Colors.cyanAccent, this.glow = false}); @override Widget build(BuildContext context) { return ClipRRect(borderRadius: BorderRadius.circular(15), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5), boxShadow: glow ? [BoxShadow(color: borderColor.withOpacity(0.2), blurRadius: 15, spreadRadius: 1)] : []), child: child))); } }
class NeonButton extends StatelessWidget { final String text; final VoidCallback? onPressed; final Color color; final IconData? icon; const NeonButton({super.key, required this.text, required this.onPressed, this.color = Colors.cyanAccent, this.icon}); @override Widget build(BuildContext context) { return GestureDetector(onTap: onPressed, child: Container(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20), decoration: BoxDecoration(color: onPressed == null ? Colors.grey[900] : color.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: onPressed == null ? Colors.grey : color), boxShadow: onPressed == null ? [] : [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if(icon != null) ...[Icon(icon, color: onPressed == null ? Colors.grey : color, size: 20), const SizedBox(width: 10)], Text(text, style: TextStyle(color: onPressed == null ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5))]))); } }