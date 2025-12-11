import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:trivve/gamepage.dart'; // REQUIRED: Links to games

// ⚡ TRIVVE SQUAD MODULE 3.0 (ULTRA UI)
// "The Cyberpunk Command Center"

// =============================================================================
// 🎨 1. CUSTOM UI WIDGETS (THE "GLOW UP")
// =============================================================================

class CyberBackground extends StatefulWidget {
  final Widget child;
  const CyberBackground({super.key, required this.child});
  @override
  State<CyberBackground> createState() => _CyberBackgroundState();
}

class _CyberBackgroundState extends State<CyberBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark Base
        Container(color: const Color(0xFF050505)),
        
        // Moving Grid
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: GridPainter(_controller.value),
              child: Container(),
            );
          },
        ),
        
        // Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
            )
          ),
        ),
        
        // Content
        widget.child,
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  final double value;
  GridPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purpleAccent.withOpacity(0.1)
      ..strokeWidth = 1;

    // Vertical Lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal Lines (Moving)
    double offset = value * 40;
    for (double y = offset; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => true;
}

class CyberGlassBox extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final bool glow;

  const CyberGlassBox({super.key, required this.child, this.borderColor = Colors.cyanAccent, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
            boxShadow: glow ? [BoxShadow(color: borderColor.withOpacity(0.2), blurRadius: 15, spreadRadius: 1)] : [],
          ),
          child: child,
        ),
      ),
    );
  }
}

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const NeonButton({super.key, required this.text, required this.onPressed, this.color = Colors.cyanAccent, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: onPressed == null ? Colors.grey[900] : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: onPressed == null ? Colors.grey : color),
          boxShadow: onPressed == null ? [] : [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if(icon != null) ...[Icon(icon, color: onPressed == null ? Colors.grey : color, size: 20), const SizedBox(width: 10)],
            Text(text, style: TextStyle(color: onPressed == null ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. MAIN LOGIC
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

// =============================================================================
// 3. SQUAD DASHBOARD (THE HUB)
// =============================================================================

class SquadDashboard extends StatefulWidget {
  final String squadId;
  const SquadDashboard({super.key, required this.squadId});
  @override
  State<SquadDashboard> createState() => _SquadDashboardState();
}

class _SquadDashboardState extends State<SquadDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _leaveSquad() async {
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({'squadId': null});
    await FirebaseFirestore.instance.collection('squads').doc(widget.squadId).update({'members': FieldValue.arrayRemove([_currentUser!.uid])});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by CyberBackground
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('squads').doc(widget.squadId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text("CONNECTING...");
            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const Text("DISCONNECTED");
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                Text("SECURE CHANNEL: ${data['code']}", style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)),
              ],
            );
          },
        ),
        actions: [IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.redAccent), onPressed: _leaveSquad)],
        bottom: TabBar(
          controller: _tabController,
          indicator: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.cyanAccent, width: 3))),
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [Tab(text: "CHAT"), Tab(text: "AGENTS"), Tab(text: "LOGS"), Tab(text: "RADAR")],
        ),
      ),
      body: CyberBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSquadChat(),
              _buildRoster(),
              _buildBattleLog(),
              _buildSquadMap(),
            ],
          ),
        ),
      ),
    );
  }

  // --- 💬 TAB 1: SQUAD CHAT ---
  Widget _buildSquadChat() {
    final TextEditingController msgCtrl = TextEditingController();

    void sendGameInvite() async {
      String gameId = String.fromCharCodes(Iterable.generate(4, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(32))));
      // Create Game
      await FirebaseFirestore.instance.collection('games').doc(gameId).set({
        'type': 'tictactoe', 'host': _currentUser!.uid, 'hostName': _currentUser!.displayName ?? 'Agent',
        'status': 'waiting', 'created': FieldValue.serverTimestamp(), 'squadId': widget.squadId,
        'state': {'board': List.filled(9, ''), 'turn': _currentUser!.uid}, 'winner': null
      });
      // Send Invite
      await FirebaseFirestore.instance.collection('squads').doc(widget.squadId).collection('messages').add({
        'type': 'invite', 'gameId': gameId, 'gameType': 'tictactoe', 'senderId': _currentUser!.uid,
        'senderName': _currentUser!.displayName ?? 'Agent', 'timestamp': FieldValue.serverTimestamp()
      });
      // Host Enters
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (c) => OnlineGameScreen(gameId: gameId, gameType: 'tictactoe')));
    }

    void sendMessage() {
      if (msgCtrl.text.trim().isEmpty) return;
      FirebaseFirestore.instance.collection('squads').doc(widget.squadId).collection('messages').add({
        'type': 'text', 'text': msgCtrl.text.trim(), 'senderId': _currentUser!.uid,
        'senderName': _currentUser!.displayName ?? 'Agent', 'timestamp': FieldValue.serverTimestamp(),
      });
      msgCtrl.clear();
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('squads').doc(widget.squadId).collection('messages').orderBy('timestamp', descending: true).limit(50).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
              return ListView.builder(
                reverse: true, itemCount: snapshot.data!.docs.length,
                padding: const EdgeInsets.all(15),
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  bool isMe = data['senderId'] == _currentUser!.uid;

                  if (data['type'] == 'invite') {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: CyberGlassBox(
                        borderColor: Colors.purpleAccent,
                        glow: true,
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(children: [
                            Text("⚡ ${data['senderName']} INITIATED A DUEL", style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 10),
                            isMe 
                            ? const Text("WAITING FOR TARGET...", style: TextStyle(color: Colors.grey, fontSize: 10))
                            : NeonButton(
                                text: "ACCEPT CHALLENGE", 
                                color: Colors.purpleAccent,
                                onPressed: () async {
                                   var gameRef = FirebaseFirestore.instance.collection('games').doc(data['gameId']);
                                   await FirebaseFirestore.instance.runTransaction((t) async {
                                     var s = await t.get(gameRef);
                                     if(s.exists && s['status']=='waiting') {
                                       t.update(gameRef, {'player2': _currentUser!.uid, 'player2Name': _currentUser!.displayName??'Challenger', 'status': 'playing'});
                                     }
                                   });
                                   if(mounted) Navigator.push(context, MaterialPageRoute(builder: (c) => OnlineGameScreen(gameId: data['gameId'], gameType: data['gameType'])));
                                }
                              )
                          ]),
                        ),
                      ),
                    );
                  }

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.black54,
                        border: Border.all(color: isMe ? Colors.cyanAccent.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
                          bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                          bottomRight: isMe ? Radius.zero : const Radius.circular(12)
                        )
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if(!isMe) Text(data['senderName'] ?? 'UNKNOWN', style: const TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                        Text(data['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // INPUT BAR
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.black87, border: Border(top: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)))),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.gamepad, color: Colors.purpleAccent), onPressed: sendGameInvite),
            Expanded(child: TextField(
              controller: msgCtrl, 
              style: const TextStyle(color: Colors.white), 
              decoration: const InputDecoration(
                hintText: "TRANSMIT MESSAGE...", hintStyle: TextStyle(color: Colors.grey),
                filled: true, fillColor: Colors.black, contentPadding: EdgeInsets.symmetric(horizontal: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30)), borderSide: BorderSide(color: Colors.white24))
              )
            )),
            const SizedBox(width: 10),
            CircleAvatar(backgroundColor: Colors.cyanAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.black, size: 18), onPressed: sendMessage))
          ]),
        )
      ],
    );
  }

  // --- 🏆 TAB 2: ROSTER ---
  Widget _buildRoster() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('squadId', isEqualTo: widget.squadId).orderBy('wins', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            Color rankColor = index == 0 ? Colors.amber : (index == 1 ? Colors.grey : (index == 2 ? Colors.brown : Colors.cyanAccent.withOpacity(0.3)));
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: CyberGlassBox(
                borderColor: rankColor,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.black,
                    backgroundImage: NetworkImage(data['photoUrl'] ?? 'https://via.placeholder.com/150'),
                    child: Text("#${index+1}", style: TextStyle(color: rankColor, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(data['displayName'] ?? "AGENT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  subtitle: Text("${data['wins'] ?? 0} WINS // ${data['xp'] ?? 0} XP", style: TextStyle(color: rankColor, fontSize: 10)),
                  trailing: Icon(Icons.shield, color: rankColor.withOpacity(0.5)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 📜 TAB 3: BATTLE LOG ---
  Widget _buildBattleLog() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('squads').doc(widget.squadId).collection('history').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("NO COMBAT DATA RECORDED", style: TextStyle(color: Colors.grey, letterSpacing: 2)));
        
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var d = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.redAccent, width: 2)), color: Colors.grey[900]),
              child: ListTile(
                title: Text("${d['winnerName'].toString().toUpperCase()} WON ${d['gameType'].toString().toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                subtitle: const Text("VICTORY ARCHIVED", style: TextStyle(color: Colors.grey, fontSize: 8)),
                trailing: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  // --- 🗺️ TAB 4: RADAR ---
  Widget _buildSquadMap() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('squadId', isEqualTo: widget.squadId).snapshots(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        List<Marker> m = [];
        LatLng c = const LatLng(51.5, -0.09);
        for(var d in snapshot.data!.docs) {
          var data = d.data() as Map<String, dynamic>;
          if(data['lastLat']!=null) {
            c = LatLng(data['lastLat'], data['lastLng']);
            m.add(Marker(point: c, width: 50, height: 50, child: Column(children: [
              Container(decoration: BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.cyanAccent, blurRadius: 10)]), padding: EdgeInsets.all(2), child: Icon(Icons.person, size: 15)),
              Container(color: Colors.black, child: Text(data['displayName']??'AG', style: TextStyle(color: Colors.white, fontSize: 8)))
            ])));
          }
        }
        return FlutterMap(options: MapOptions(initialCenter: c, initialZoom: 12), children: [TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', subdomains: const ['a','b','c']), MarkerLayer(markers: m)]);
      },
    );
  }
}

// =============================================================================
// 4. JOIN SCREEN (TERMINAL STYLE)
// =============================================================================

class JoinCreateSquadView extends StatefulWidget {
  const JoinCreateSquadView({super.key});
  @override
  State<JoinCreateSquadView> createState() => _JoinCreateSquadViewState();
}

class _JoinCreateSquadViewState extends State<JoinCreateSquadView> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final q = await FirebaseFirestore.instance.collection('squads').where('code', isEqualTo: _codeCtrl.text.trim().toUpperCase()).get();
      if (q.docs.isEmpty) throw "INVALID FREQUENCY";
      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({'squadId': q.docs.first.id});
      await FirebaseFirestore.instance.collection('squads').doc(q.docs.first.id).update({'members': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid])});
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      String code = String.fromCharCodes(Iterable.generate(6, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(36))));
      String id = "${_nameCtrl.text.trim().toLowerCase()}_$code";
      await FirebaseFirestore.instance.collection('squads').doc(id).set({'name': _nameCtrl.text.trim(), 'code': code, 'leader': FirebaseAuth.instance.currentUser!.uid, 'members': [FirebaseAuth.instance.currentUser!.uid], 'createdAt': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({'squadId': id});
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e"))); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CyberBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 80, color: Colors.cyanAccent),
                  const SizedBox(height: 20),
                  const Text("UPLINK REQUIRED", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
                  const SizedBox(height: 10),
                  const Text("ESTABLISH SQUAD CONNECTION", style: TextStyle(color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 50),
                  
                  // JOIN
                  CyberGlassBox(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        TextField(controller: _codeCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, letterSpacing: 5, fontSize: 20), decoration: const InputDecoration(filled: true, fillColor: Colors.black26, hintText: "ACCESS CODE", hintStyle: TextStyle(color: Colors.grey, fontSize: 12))),
                        const SizedBox(height: 15),
                        NeonButton(text: "INITIATE LINK", onPressed: _busy ? null : _join)
                      ]),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  const Text("- OR -", style: TextStyle(color: Colors.white24)),
                  const SizedBox(height: 30),

                  // CREATE
                  CyberGlassBox(
                    borderColor: Colors.purpleAccent,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        TextField(controller: _nameCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(filled: true, fillColor: Colors.black26, hintText: "NEW PROTOCOL NAME", hintStyle: TextStyle(color: Colors.grey))),
                        const SizedBox(height: 15),
                        NeonButton(text: "ESTABLISH SQUAD", color: Colors.purpleAccent, onPressed: _busy ? null : _create)
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}