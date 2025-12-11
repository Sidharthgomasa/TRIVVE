import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui'; // For ImageFilter blur

// =============================================================================
// 🎨 HARDCODED SHOP DATA 
// =============================================================================
final List<Map<String, dynamic>> shopItems = [
  // --- FRAMES ---
  {
    'id': 'frame_neon_cyan',
    'type': 'frame',
    'name': 'Cyan Glitch Frame',
    'cost': 500,
    'assetUrl': 'https://i.pinimg.com/originals/f9/cb/49/f9cb49321525cb9f69c91766c7504dc8.gif', 
    'color': Colors.cyanAccent,
  },
  {
    'id': 'frame_gold_tier',
    'type': 'frame',
    'name': 'Gold Tier Frame',
    'cost': 2500,
    'assetUrl': 'https://i.gifer.com/origin/4a/4a9c7e53110435434847d7500480159e.gif', 
    'color': Colors.amber,
  },
   {
    'id': 'frame_matrix',
    'type': 'frame',
    'name': 'The Operator',
    'cost': 5000,
    'assetUrl': 'https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExaDNwazl5YnV0cWw4ZnF6d3c3azl6ZzF4d3p6c3c3a3F4a3c3a3F4aiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/AC1HrkBir3a5G/giphy.gif', 
    'color': Colors.green,
  },
  // --- BANNERS ---
  {
    'id': 'banner_cyber_city',
    'type': 'banner',
    'name': 'Neo Tokyo Banner',
    'cost': 1000,
    'assetProvider': const NetworkImage('https://img.freepik.com/free-vector/cyberpunk-city-street-night-with-neon-signs_107791-16735.jpg?w=1380'),
  },
   {
    'id': 'banner_matrix_rain',
    'type': 'banner',
    'name': 'Matrix Rain Banner',
    'cost': 3000,
    'assetProvider': const NetworkImage('https://media.giphy.com/media/sI4jUKZc4b10c/giphy.gif'),
  },
];

class TheYearbookScreen extends StatefulWidget {
  const TheYearbookScreen({super.key});

  @override
  State<TheYearbookScreen> createState() => _TheYearbookScreenState();
}

class _TheYearbookScreenState extends State<TheYearbookScreen> with SingleTickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); 
  }

  // ✏️ EDIT PROFILE DIALOG
  void _showEditDialog(String currentBio) {
    TextEditingController bioController = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("UPDATE IDENTITY RECORD", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Modify your public tagline:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: bioController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true, 
                fillColor: Colors.black,
                border: OutlineInputBorder(),
                hintText: "Enter new bio..."
              ),
              maxLength: 40,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () async {
              if (_user != null) {
                await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
                  'bio': bioController.text.trim()
                });
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("SAVE UPDATE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: Text("Login Required")));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("THE YEARBOOK 🆔", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(text: "MY ID"),
            Tab(text: "LEGACY (HISTORY)"), 
            Tab(text: "THE VAULT"),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          var userData = snapshot.data!.data() as Map<String, dynamic>?;

          // Data Extraction
          int aura = userData?['aura'] ?? 0;
          String bio = userData?['bio'] ?? "Cyberpunk Citizen";
          List<dynamic> ownedItems = userData?['ownedItems'] ?? [];
          String equippedFrame = userData?['equippedFrame'] ?? 'default';
          String equippedBanner = userData?['equippedBanner'] ?? 'default';
          List<dynamic> badges = userData?['badges'] ?? [];
          List<dynamic> history = userData?['hostingHistory'] ?? []; 

          // Find visual assets
          var frameData = shopItems.firstWhere((item) => item['id'] == equippedFrame, orElse: () => {'assetUrl': null, 'color': Colors.grey});
          var bannerData = shopItems.firstWhere((item) => item['id'] == equippedBanner, orElse: () => {'assetProvider': null});

          return TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: MY ID CARD (With Edit Button)
              _buildProfileView(userData, aura, bio, badges, frameData, bannerData),
              
              // TAB 2: LEGACY (History)
              _buildHistoryView(history),

              // TAB 3: THE VAULT (SHOP)
              _buildShopView(aura, ownedItems, equippedFrame, equippedBanner),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 🆔 TAB 1: THE HOLOGRAPHIC PROFILE VIEW
  // ===========================================================================
  Widget _buildProfileView(Map<String, dynamic>? userData, int aura, String bio, List<dynamic> badges, Map<String, dynamic> frameData, Map<String, dynamic> bannerData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // --- THE ID CARD ---
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              image: bannerData['assetProvider'] != null 
                ? DecorationImage(image: bannerData['assetProvider'], fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken))
                : null,
              boxShadow: [BoxShadow(color: (frameData['color'] as Color).withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
              border: Border.all(color: (frameData['color'] as Color).withOpacity(0.6), width: 2)
            ),
            child: Stack(
              children: [
                Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5), child: Container(color: Colors.transparent))),
                
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // AVATAR WITH ANIMATED FRAME
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (frameData['assetUrl'] != null)
                            Image.network(frameData['assetUrl'], width: 110, height: 110, fit: BoxFit.cover),
                          
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.black,
                            backgroundImage: NetworkImage(_user!.photoURL ?? "https://i.pravatar.cc/150"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(_user!.displayName ?? "Anonymous", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text(bio, style: TextStyle(color: Colors.grey[400], fontFamily: 'Courier')),
                    ],
                  ),
                ),
                // AURA DISPLAY
                Positioned(
                  top: 15, right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purpleAccent)),
                    child: Row(children: [const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 16), const SizedBox(width: 5), Text("$aura AURA", style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))]),
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- ✏️ EDIT BUTTON (NEW) ---
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditDialog(bio),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.cyanAccent), padding: const EdgeInsets.all(15)),
              icon: const Icon(Icons.edit, color: Colors.cyanAccent),
              label: const Text("EDIT DATA LOG", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 30),

          // --- BADGES SECTION ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("BADGES & ACHIEVEMENTS", style: TextStyle(color: Colors.grey[400], fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 15),
                if (badges.isEmpty)
                   const Padding(padding: EdgeInsets.all(10.0), child: Text("Play games to earn badges.", style: TextStyle(color: Colors.grey)))
                else
                  Wrap(
                    spacing: 10,
                    children: badges.map((badgeId) => _buildBadge(badgeId)).toList(),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBadge(String badgeId) {
    IconData icon = Icons.stars;
    Color color = Colors.grey;
    if (badgeId.contains('win')) { icon = Icons.emoji_events; color = Colors.amber; }
    if (badgeId.contains('series')) { icon = Icons.local_fire_department; color = Colors.redAccent; }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: color)),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // ===========================================================================
  // 📜 TAB 2: LEGACY (HOSTING HISTORY)
  // ===========================================================================
  Widget _buildHistoryView(List<dynamic> history) {
    if (history.isEmpty) {
      return const Center(child: Text("No broadcast history yet.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final event = history[history.length - 1 - index];
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(left: BorderSide(color: _getHistoryColor(event['category']), width: 4)),
            borderRadius: BorderRadius.circular(10)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(event['title'] ?? 'Unknown Event', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(event['date'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.access_time, color: _getHistoryColor(event['category']), size: 14),
                  const SizedBox(width: 5),
                  Text(event['time'] ?? '', style: TextStyle(color: _getHistoryColor(event['category']), fontSize: 12)),
                  const SizedBox(width: 15),
                  const Icon(Icons.location_on, color: Colors.grey, size: 14),
                  const SizedBox(width: 5),
                  Text(event['location'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Color _getHistoryColor(String? cat) {
    if(cat == 'Party') return Colors.pinkAccent;
    if(cat == 'Sports') return Colors.orangeAccent;
    if(cat == 'Food') return Colors.redAccent;
    return Colors.cyanAccent;
  }

  // ===========================================================================
  // 🛒 TAB 3: THE VAULT (SHOP INTERFACE)
  // ===========================================================================
  Widget _buildShopView(int currentAura, List<dynamic> ownedItems, String equippedFrame, String equippedBanner) {
    var frames = shopItems.where((i) => i['type'] == 'frame').toList();
    var banners = shopItems.where((i) => i['type'] == 'banner').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple[900]!, Colors.blue[900]!]), borderRadius: BorderRadius.circular(15)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("YOUR BALANCE:", style: TextStyle(color: Colors.white70)),
              Text("$currentAura AURA ✨", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 20),

          const Text("NEON FRAMES", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: frames.length,
              itemBuilder: (c, i) => _buildShopItemCard(frames[i], currentAura, ownedItems, equippedFrame),
            ),
          ),

          const SizedBox(height: 20),
          const Text("PROFILE BANNERS", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: banners.length,
              itemBuilder: (c, i) => _buildShopItemCard(banners[i], currentAura, ownedItems, equippedBanner),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItemCard(Map<String, dynamic> item, int currentAura, List<dynamic> ownedItems, String equippedId) {
    bool isOwned = ownedItems.contains(item['id']);
    bool isEquipped = equippedId == item['id'];
    bool canAfford = currentAura >= item['cost'];

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isEquipped ? Colors.greenAccent : (isOwned ? Colors.grey : (canAfford ? Colors.cyanAccent : Colors.redAccent))),
        boxShadow: isEquipped ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 10)] : []
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: item['type'] == 'frame' 
               ? Image.network(item['assetUrl'], height: 60, width: 60, fit: BoxFit.cover) 
               : Container(height: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: item['assetProvider'], fit: BoxFit.cover))), 
          ),
          
          Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          
          if (isEquipped)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.green[800], borderRadius: BorderRadius.circular(5)), child: const Text("EQUIPPED", style: TextStyle(fontSize: 10, color: Colors.white)))
          else if (isOwned)
            ElevatedButton(
              onPressed: () => _equipItem(item['type'], item['id']),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white, minimumSize: const Size(80, 30)),
              child: const Text("EQUIP", style: TextStyle(fontSize: 10))
            )
          else
            ElevatedButton(
              onPressed: canAfford ? () => _buyItem(item) : null,
              style: ElevatedButton.styleFrom(backgroundColor: canAfford ? Colors.cyanAccent : Colors.redAccent, foregroundColor: Colors.black, minimumSize: const Size(80, 30)),
              child: Text(canAfford ? "${item['cost']} AURA" : "TOO POOR", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
            )
        ],
      ),
    );
  }

  void _buyItem(Map<String, dynamic> item) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
    await userRef.update({
      'aura': FieldValue.increment(-item['cost']),
      'ownedItems': FieldValue.arrayUnion([item['id']])
    });
    _equipItem(item['type'], item['id']);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Purchased ${item['name']}!"), backgroundColor: Colors.green));
  }

  void _equipItem(String type, String id) async {
    String fieldToUpdate = type == 'frame' ? 'equippedFrame' : 'equippedBanner';
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({ fieldToUpdate: id });
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Equipped successfully!"), backgroundColor: Colors.grey));
  }
}