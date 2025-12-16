import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:trivve/social/squad_engine.dart';
import 'package:trivve/gamepage.dart';
import 'package:trivve/social/squad_chat.dart'; // <--- NEW IMPORT

class SquadLobbyScreen extends StatefulWidget {
  final String squadId;
  final bool isHost;

  const SquadLobbyScreen({super.key, required this.squadId, required this.isHost});

  @override
  State<SquadLobbyScreen> createState() => _SquadLobbyScreenState();
}

class _SquadLobbyScreenState extends State<SquadLobbyScreen> with SingleTickerProviderStateMixin {
  final SquadEngine _engine = SquadEngine();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('squads').doc(widget.squadId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
          return const Scaffold(backgroundColor: Colors.black);
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        List members = data['members'];
        String hostId = data['hostId'];
        bool amIHost = FirebaseAuth.instance.currentUser!.uid == hostId;

        // Auto-Launch
        if (data['activeGame'] != null) {
          String gameId = data['activeGame']['id'];
          String type = data['activeGame']['type'];
          WidgetsBinding.instance.addPostFrameCallback((_) {
             Navigator.push(context, MaterialPageRoute(builder: (c) => OnlineGameScreen(gameId: gameId, gameType: type)));
          });
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text("SQUAD: ${widget.squadId}", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.cyanAccent,
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.grey,
              tabs: const [Tab(text: "MEMBERS"), Tab(text: "CHAT")],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: widget.squadId)); }),
              IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.red), onPressed: () { _engine.leaveSquad(widget.squadId); Navigator.pop(context); })
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // TAB 1: MEMBERS
                    _buildMembersList(members, hostId),
                    
                    // TAB 2: CHAT (NEW)
                    SquadChatWidget(squadId: widget.squadId),
                  ],
                ),
              ),
              
              // LAUNCHER (Persistent at bottom)
              if (amIHost) _buildHostControls(),
              if (!amIHost) _buildWaitingStatus(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMembersList(List members, String hostId) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: members.length,
      itemBuilder: (ctx, i) {
        var m = members[i];
        bool isLeader = m['uid'] == hostId;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isLeader ? Colors.yellowAccent : Colors.grey[800]!),
          ),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: isLeader ? Colors.yellow : Colors.grey, child: const Icon(Icons.person, color: Colors.black)),
              const SizedBox(width: 15),
              Text(m['name'], style: const TextStyle(color: Colors.white, fontSize: 16)),
              const Spacer(),
              if (isLeader) const Icon(Icons.star, color: Colors.yellowAccent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHostControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Color.fromARGB(255, 33, 33, 33), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("LAUNCH MISSION", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _gameCard("Ludo", "ludo", Icons.grid_view),
                _gameCard("Carrom", "carrom", Icons.circle_outlined),
                _gameCard("Cricket", "cricket", Icons.sports_cricket),
                _gameCard("Snake", "snake", Icons.all_inclusive),
                _gameCard("Typer", "typer", Icons.keyboard),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWaitingStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.grey[900],
      child: const Text("WAITING FOR HOST...", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, letterSpacing: 2)),
    );
  }

  Widget _gameCard(String title, String type, IconData icon) {
    return GestureDetector(
      onTap: () => _engine.launchGame(widget.squadId, type),
      child: Container(
        width: 70, margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white), const SizedBox(height: 5), Text(title, style: const TextStyle(color: Colors.white, fontSize: 10))]),
      ),
    );
  }
}