import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trivve/login_screen.dart'; 

// =============================================================================
// 🎨 SHOP DATA (Stable URLs)
// =============================================================================
final List<Map<String, dynamic>> shopItems = [
  {
    'id': 'frame_neon_cyan',
    'type': 'frame',
    'name': 'Cyan Glitch',
    'cost': 500,
    'assetUrl': 'https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3R6eWx6eHl6eHl6eHl6eHl6eHl6eHl6eHl6eHl6eHl6/3o7TKSjRrfIPjeiVyM/giphy.gif', 
    'color': Colors.cyanAccent,
  },
  {
    'id': 'frame_gold_tier',
    'type': 'frame',
    'name': 'Gold Prestige',
    'cost': 2500,
    'assetUrl': 'https://media.giphy.com/media/l41YtZOb9EUABfdq8/giphy.gif', 
    'color': Colors.amber,
  },
   {
    'id': 'frame_matrix',
    'type': 'frame',
    'name': 'Matrix Code',
    'cost': 1500,
    'assetUrl': 'https://media.giphy.com/media/A06UFEx8jxEwU/giphy.gif',
    'color': Colors.greenAccent,
  },
  {
    'id': 'banner_cyber_city',
    'type': 'banner',
    'name': 'Night City',
    'cost': 1000,
    'assetUrl': 'https://media.giphy.com/media/u49M5PH131RLe/giphy.gif',
    'color': Colors.purpleAccent,
  },
  {
    'id': 'banner_space_void',
    'type': 'banner',
    'name': 'Deep Space',
    'cost': 2000,
    'assetUrl': 'https://media.giphy.com/media/U3qYN8S0j3bpK/giphy.gif',
    'color': Colors.blueAccent,
  },
];

class TheYearbookScreen extends StatefulWidget {
  const TheYearbookScreen({super.key});
  @override
  State<TheYearbookScreen> createState() => _TheYearbookScreenState();
}

class _TheYearbookScreenState extends State<TheYearbookScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: Text("ACCESS DENIED")));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("AGENT PROFILE", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontSize: 16)),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          
          var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          int aura = data['aura'] ?? 0;
          List<dynamic> owned = data['ownedItems'] ?? [];
          String? currentFrame = data['equippedFrame'];
          String? currentBanner = data['equippedBanner'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIDCard(data, currentFrame, currentBanner),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("INVENTORY & DATA", style: TextStyle(color: Colors.grey, letterSpacing: 1)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber)),
                      child: Row(children: [const Icon(Icons.bolt, color: Colors.amber, size: 16), const SizedBox(width: 5), Text("$aura AURA", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))]),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        indicatorColor: Colors.cyanAccent,
                        labelColor: Colors.cyanAccent,
                        unselectedLabelColor: Colors.grey,
                        tabs: [Tab(text: "CYBER SHOP"), Tab(text: "MY GEAR")]
                      ),
                      SizedBox(
                        height: 400, 
                        child: TabBarView(
                          children: [
                            _buildShop(aura, owned),
                            _buildInventory(owned, currentFrame, currentBanner),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildSettingsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIDCard(Map<String, dynamic> user, String? frameId, String? bannerId) {
    String? bannerUrl;
    String? frameUrl;
    Color frameColor = Colors.transparent;

    if (bannerId != null) {
      var item = shopItems.firstWhere((e) => e['id'] == bannerId, orElse: () => {});
      if (item.isNotEmpty) bannerUrl = item['assetUrl'];
    }
    if (frameId != null) {
      var item = shopItems.firstWhere((e) => e['id'] == frameId, orElse: () => {});
      if (item.isNotEmpty) {
        frameUrl = item['assetUrl'];
        frameColor = item['color'];
      }
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
        image: bannerUrl != null ? DecorationImage(
          image: NetworkImage(bannerUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
          onError: (e, s) {} 
        ) : null,
        boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20)]
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20, left: 20,
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.black,
                      backgroundImage: user['photoUrl'] != null ? NetworkImage(user['photoUrl']) : null,
                      child: user['photoUrl'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    if (frameUrl != null)
                       SizedBox(
                        width: 90, height: 90, 
                        child: Image.network(
                          frameUrl,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: frameColor, width: 3)),
                          ),
                        )
                      )
                  ],
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['displayName']?.toString().toUpperCase() ?? "AGENT", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text("@${user['username'] ?? 'unknown'}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    const SizedBox(height: 5),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)), child: Text("LEVEL ${(user['xp'] ?? 0) ~/ 500 + 1}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
                  ],
                )
              ],
            ),
          ),
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _idStat("WINS", "${user['wins'] ?? 0}"),
                _idStat("MATCHES", "${user['gamesPlayed'] ?? 0}"),
                _idStat("JOINED", "2025"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _idStat(String label, String val) {
    return Column(children: [Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10))]);
  }

  Widget _buildShop(int userAura, List<dynamic> ownedIds) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8),
      itemCount: shopItems.length,
      itemBuilder: (context, index) {
        var item = shopItems[index];
        bool isOwned = ownedIds.contains(item['id']);
        return _shopCard(item, isOwned, userAura >= (item['cost'] as int));
      },
    );
  }

  Widget _buildInventory(List<dynamic> ownedIds, String? currentFrame, String? currentBanner) {
    var myItems = shopItems.where((i) => ownedIds.contains(i['id'])).toList();
    if (myItems.isEmpty) return const Center(child: Text("INVENTORY EMPTY", style: TextStyle(color: Colors.grey)));

    return GridView.builder(
      padding: const EdgeInsets.only(top: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8),
      itemCount: myItems.length,
      itemBuilder: (context, index) {
        var item = myItems[index];
        bool isEquipped = (item['type'] == 'frame' && currentFrame == item['id']) || (item['type'] == 'banner' && currentBanner == item['id']);
        return Container(
          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15), border: Border.all(color: isEquipped ? Colors.greenAccent : Colors.white10)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: _buildSafeImage(item))),
              Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 5),
              if (isEquipped)
                const Padding(padding: EdgeInsets.only(bottom: 10), child: Text("EQUIPPED", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)))
              else
                Padding(padding: const EdgeInsets.only(bottom: 10), child: ElevatedButton(
                  onPressed: () => _equipItem(item['type'], item['id']),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, minimumSize: const Size(80, 30)),
                  child: const Text("EQUIP", style: TextStyle(fontSize: 10))
                ))
            ],
          ),
        );
      },
    );
  }

  Widget _buildSafeImage(Map<String, dynamic> item) {
    // ✅ FIX: No complex loading math, just simple loading and error handling
    return Image.network(
      item['assetUrl'],
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(color: item['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: item['color'].withOpacity(0.5))),
          child: Center(child: Icon(item['type'] == 'frame' ? Icons.border_style : Icons.image, color: item['color'], size: 30)),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(child: CircularProgressIndicator(color: item['color']));
      },
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text("SYSTEM CONFIG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          leading: const Icon(Icons.settings, color: Colors.cyanAccent),
          childrenPadding: const EdgeInsets.all(20),
          children: [
            _buildSwitch("AUDIO FX", Icons.volume_up, _soundEnabled, (v) => setState(() => _soundEnabled = v)),
            const SizedBox(height: 10),
            _buildSwitch("HAPTIC FEEDBACK", Icons.vibration, _hapticsEnabled, (v) => setState(() => _hapticsEnabled = v)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.2), foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                onPressed: _logout,
                icon: const Icon(Icons.power_settings_new),
                label: const Text("TERMINATE SESSION")
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        secondary: Icon(icon, color: Colors.grey, size: 20),
        value: value,
        activeThumbColor: Colors.cyanAccent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        onChanged: onChanged,
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  Widget _shopCard(Map<String, dynamic> item, bool isOwned, bool canAfford) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15), border: Border.all(color: item['color'].withOpacity(0.3))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: _buildSafeImage(item))),
          Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          if (isOwned)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: ElevatedButton(onPressed: () => _equipItem(item['type'], item['id']), style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, minimumSize: const Size(80, 30)), child: const Text("EQUIP", style: TextStyle(fontSize: 10))))
          else
            Padding(padding: const EdgeInsets.only(bottom: 10), child: ElevatedButton(onPressed: canAfford ? () => _buyItem(item) : null, style: ElevatedButton.styleFrom(backgroundColor: canAfford ? Colors.cyanAccent : Colors.redAccent, foregroundColor: Colors.black, minimumSize: const Size(80, 30)), child: Text(canAfford ? "${item['cost']} AURA" : "TOO POOR", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))
        ],
      ),
    );
  }

  void _buyItem(Map<String, dynamic> item) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
    await userRef.update({'aura': FieldValue.increment(-item['cost']), 'ownedItems': FieldValue.arrayUnion([item['id']])});
    _equipItem(item['type'], item['id']);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Purchased ${item['name']}!"), backgroundColor: Colors.green));
  }

  void _equipItem(String type, String id) async {
    String fieldToUpdate = type == 'frame' ? 'equippedFrame' : 'equippedBanner';
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({fieldToUpdate: id});
  }
}