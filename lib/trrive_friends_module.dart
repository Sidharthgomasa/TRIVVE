import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trivve/trivve_college_spaces.dart';

// =============================================================================
// ⚡ TRIVVE FRIENDS & LEGACY MODULE
// =============================================================================

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("SOCIAL UPLINK", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.purpleAccent),
            onPressed: () => showSearch(context: context, delegate: UserSearchDelegate()),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "MY FRIENDS"),
            Tab(text: "REQUESTS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
        ],
      ),
    );
  }
  

  // --- TAB 1: FRIENDS LIST (With Profile Access) ---
 // --- TAB 1: FRIENDS LIST (Clean Version) ---
  Widget _buildFriendsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('friends')
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("NO ALLIES FOUND", style: TextStyle(color: Colors.grey, letterSpacing: 2)));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: const EdgeInsets.all(15),
          itemBuilder: (context, index) {
            var friendLink = snapshot.data!.docs[index];
            String friendUid = friendLink.id;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(friendUid).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox();
                var user = userSnap.data!.data() as Map<String, dynamic>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    onTap: () => _showFriendProfile(context, friendUid, user),
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user['photoUrl'] ?? ''),
                      backgroundColor: Colors.black,
                    ),
                    title: Text(user['displayName'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${user['wins'] ?? 0} Global Wins", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    trailing: IconButton(
                      icon: const Icon(Icons.visibility, size: 16, color: Colors.purpleAccent),
                      onPressed: () => _showFriendProfile(context, friendUid, user),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  // --- TAB 2: REQUESTS ---
  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('friends')
          .where('status', isEqualTo: 'pending') 
          .where('type', isEqualTo: 'incoming') 
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("NO PENDING SIGNALS", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var req = snapshot.data!.docs[index];
            return ListTile(
              title: const Text("Incoming Signal", style: TextStyle(color: Colors.cyanAccent)),
              subtitle: Text("User ID: ${req.id}", style: const TextStyle(color: Colors.grey)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                    onPressed: () => _acceptFriend(req.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => _removeFriend(req.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _acceptFriend(String friendUid) async {
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('friends').doc(friendUid).update({'status': 'accepted'});
    await FirebaseFirestore.instance.collection('users').doc(friendUid).collection('friends').doc(_currentUser!.uid).update({'status': 'accepted'});
  }

  Future<void> _removeFriend(String friendUid) async {
    await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('friends').doc(friendUid).delete();
    await FirebaseFirestore.instance.collection('users').doc(friendUid).collection('friends').doc(_currentUser!.uid).delete();
  }

  // --- 📊 THE NEW PROFILE SHEET (RIVALRY + LEGACY) ---
  void _showFriendProfile(BuildContext context, String friendUid, Map<String, dynamic> friendData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: 600,
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            border: const Border(top: BorderSide(color: Colors.cyanAccent, width: 2)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 20)]
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const SizedBox(height: 10),
                // HEADER
                ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(friendData['photoUrl'] ?? ''),
                  ),
                  title: Text(friendData['displayName'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  subtitle: Text(friendData['bio'] ?? "No Bio Data", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                
                // TABS
                const TabBar(
                  indicatorColor: Colors.purpleAccent,
                  labelColor: Colors.purpleAccent,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: "RIVALRY STATS"),
                    Tab(text: "LEGACY (HISTORY)"), // 👈 NEW TAB
                  ]
                ),
                const Divider(height: 1, color: Colors.white12),

                // TAB CONTENT
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildRivalryTab(friendUid),
                      _buildLegacyTab(friendData['hostingHistory']), // 👈 PASSING HISTORY
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 1: RIVALRY STATS ---
  Widget _buildRivalryTab(String friendUid) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('games')
          .where('recorded', isEqualTo: true)
          .get(), 
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));

        int myWins = 0;
        int friendWins = 0;
        int totalGames = 0;

        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String host = data['host'];
          String? player2 = data['player2'];
          String? winner = data['winner'];

          bool isMatch = (host == _currentUser!.uid && player2 == friendUid) || 
                         (host == friendUid && player2 == _currentUser!.uid);
          
          if (isMatch) {
            totalGames++;
            if (winner == _currentUser!.uid) myWins++;
            if (winner == friendUid) friendWins++;
          }
        }

        if (totalGames == 0) {
          return const Center(child: Text("NO COMBAT HISTORY YET", style: TextStyle(color: Colors.grey)));
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox("YOU", myWins, Colors.cyanAccent),
                const Text("VS", style: TextStyle(color: Colors.white24, fontSize: 30, fontWeight: FontWeight.bold)),
                _buildStatBox("THEM", friendWins, Colors.redAccent),
              ],
            ),
            const SizedBox(height: 30),
            Text("TOTAL MATCHES: $totalGames", style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Expanded(flex: myWins == 0 ? 1 : myWins, child: Container(height: 10, color: Colors.cyanAccent)),
                    Expanded(flex: friendWins == 0 ? 1 : friendWins, child: Container(height: 10, color: Colors.redAccent)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 2: LEGACY (HISTORY) ---
  Widget _buildLegacyTab(List<dynamic>? history) {
    if (history == null || history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, color: Colors.grey, size: 50),
            SizedBox(height: 10),
            Text("NO RECORDED EVENTS", style: TextStyle(color: Colors.grey, letterSpacing: 2)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: history.length,
      itemBuilder: (context, index) {
        // Reverse order to show newest first
        final event = history[history.length - 1 - index];
        
        Color catColor = Colors.cyanAccent;
        if(event['category'] == 'Party') catColor = Colors.pinkAccent;
        if(event['category'] == 'Sports') catColor = Colors.orangeAccent;
        if(event['category'] == 'Food') catColor = Colors.redAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(left: BorderSide(color: catColor, width: 4)),
            borderRadius: BorderRadius.circular(10)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(event['title'] ?? 'Unknown Event', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: catColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text(event['category'] ?? 'General', style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600], size: 14),
                  const SizedBox(width: 5),
                  Text("${event['date']} • ${event['time']}", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 14),
                  const SizedBox(width: 5),
                  Expanded(child: Text(event['location'] ?? 'Unknown Location', style: TextStyle(color: Colors.grey[400], fontSize: 12), overflow: TextOverflow.ellipsis)),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBox(String label, int value, Color color) {
    return Column(
      children: [
        Text("$value", style: TextStyle(color: color, fontSize: 50, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// =============================================================================
// SEARCH DELEGATE
// =============================================================================

class UserSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      scaffoldBackgroundColor: Colors.black,
      inputDecorationTheme: const InputDecorationTheme(hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
    );
  }

  @override List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear, color: Colors.cyanAccent), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        
        var myUid = FirebaseAuth.instance.currentUser!.uid;
        var results = snapshot.data!.docs.where((doc) {
          if (doc.id == myUid) return false;
          var data = doc.data() as Map<String, dynamic>;
          String username = (data['username'] ?? '').toString().toLowerCase();
          String displayName = (data['displayName'] ?? '').toString().toLowerCase();
          String search = query.toLowerCase().trim();
          if (search.startsWith('@')) search = search.substring(1);
          return username.contains(search) || displayName.contains(search);
        }).toList();

        if (results.isEmpty) return Center(child: Text("NO AGENT FOUND: @$query", style: const TextStyle(color: Colors.grey)));

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            var user = results[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(user['photoUrl'] ?? 'https://via.placeholder.com/150'), backgroundColor: Colors.grey[900]),
              title: Text(user['displayName'] ?? "Agent", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text("@${user['username'] ?? 'unknown'}", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.person_add, color: Colors.purpleAccent), onPressed: () => _sendRequest(context, results[index].id)),
            );
          },
        );
      },
    );
  }

  @override Widget buildSuggestions(BuildContext context) { if (query.isEmpty) return const Center(child: Text("Search by @username", style: TextStyle(color: Colors.grey))); return buildResults(context); }

  void _sendRequest(BuildContext context, String targetUid) {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance.collection('users').doc(myUid).collection('friends').doc(targetUid).set({'status': 'pending', 'type': 'outgoing', 'timestamp': FieldValue.serverTimestamp()});
    FirebaseFirestore.instance.collection('users').doc(targetUid).collection('friends').doc(myUid).set({'status': 'pending', 'type': 'incoming', 'timestamp': FieldValue.serverTimestamp()});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("FRIEND REQUEST SENT")));
  }
}