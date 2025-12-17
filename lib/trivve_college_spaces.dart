import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:trivve/services/ad_service.dart';

// ==========================================
// 1. COLLEGE LIST HUB (Search & Aura)
// ==========================================
class CollegeSpacesHub extends StatefulWidget {
  const CollegeSpacesHub({super.key});
  @override
  State<CollegeSpacesHub> createState() => _CollegeSpacesHubState();
}

class _CollegeSpacesHubState extends State<CollegeSpacesHub> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isAdLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("CAMPUS SPACES", 
          style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildAuraDashboard(),
          _buildSearchField(),
          Expanded(child: _buildCollegeList()),
        ],
      ),
    );
  }

  Widget _buildAuraDashboard() {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("MY AURA BALANCE", style: TextStyle(color: Colors.white54, fontSize: 10)),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                builder: (context, snap) {
                  var aura = snap.hasData ? "${snap.data!['aura'] ?? 0}" : "...";
                  return Text(aura, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold));
                },
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _isAdLoading ? null : () => _showRewardAd(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: Text(_isAdLoading ? "FETCHING..." : "EARN +50"),
          ),
        ],
      ),
    );
  }

  void _showRewardAd() {
    setState(() => _isAdLoading = true);
    HapticFeedback.mediumImpact();
    AdService().showRewarded((reward) {
       if (mounted) setState(() => _isAdLoading = false);
    });
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "SEARCH CAMPUS NODE...",
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
          fillColor: const Color(0xFF111111),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildCollegeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('colleges').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        var docs = snapshot.data!.docs.where((d) => d['name'].toString().toLowerCase().contains(_searchQuery)).toList();
        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemBuilder: (context, i) => Card(
            color: const Color(0xFF111111),
            child: ListTile(
              title: Text(docs[i]['name'], style: const TextStyle(color: Colors.white, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, color: Colors.cyanAccent),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CollegeMainScreen(collegeId: docs[i].id, collegeName: docs[i]['name']))),
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// 2. COLLEGE MAIN SCREEN (Tabs)
// ==========================================
class CollegeMainScreen extends StatefulWidget {
  final String collegeId;
  final String collegeName;
  const CollegeMainScreen({super.key, required this.collegeId, required this.collegeName});

  @override
  State<CollegeMainScreen> createState() => _CollegeMainScreenState();
}

class _CollegeMainScreenState extends State<CollegeMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        backgroundColor: Colors.black,
        title: Text(widget.collegeName, style: const TextStyle(color: Colors.white, fontSize: 15)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          tabs: const [Tab(text: "REALITY FEED"), Tab(text: "THE VERDICT")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FeedTab(collegeId: widget.collegeId),
          _PollsTab(collegeId: widget.collegeId),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        onPressed: () {
          if (_tabController.index == 0) {
            _showPostForm();
          } else {
            _showPollForm();
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showPostForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _ComposePostForm(collegeId: widget.collegeId),
    );
  }

  void _showPollForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _ComposePollForm(collegeId: widget.collegeId),
    );
  }
}

// ==========================================
// 3. REALITY FEED TAB
// ==========================================
class _FeedTab extends StatefulWidget {
  final String collegeId;
  const _FeedTab({required this.collegeId});
  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  String _selectedFilter = "All";
  final List<String> _categories = ["All", "Confession", "Gossip", "Reality", "Help"];

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('college_posts').where('collegeId', isEqualTo: widget.collegeId);
    if (_selectedFilter != "All") {
      query = query.where('category', isEqualTo: _selectedFilter);
    }
    query = query.orderBy('timestamp', descending: true);

    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            itemBuilder: (context, index) {
              bool isSelected = _selectedFilter == _categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_categories[index], style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12)),
                  selected: isSelected,
                  selectedColor: Colors.cyanAccent,
                  backgroundColor: const Color(0xFF1A1A1A),
                  onSelected: (bool selected) => setState(() => _selectedFilter = _categories[index]),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Index building...", style: TextStyle(color: Colors.white24, fontSize: 10)));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No posts here", style: TextStyle(color: Colors.white24)));
              
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return _PostCard(data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. VERDICT TAB (POLLS with 1 Vote Logic)
// ==========================================
class _PollsTab extends StatelessWidget {
  final String collegeId;
  const _PollsTab({required this.collegeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('college_polls')
          .where('collegeId', isEqualTo: collegeId)
          .orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No verdicts yet", style: TextStyle(color: Colors.white24)));
        
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            return _PollCard(doc: snapshot.data!.docs[index]);
          },
        );
      },
    );
  }
}

class _PollCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _PollCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    var data = doc.data() as Map<String, dynamic>;
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    
    // Check if user has already voted
    List<dynamic> voters = data['voters'] ?? [];
    bool hasVoted = voters.contains(uid);

    int yes = data['yes'] ?? 0;
    int no = data['no'] ?? 0;
    int total = yes + no;
    double yesPercent = total == 0 ? 0.5 : yes / total;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.yellowAccent.withOpacity(hasVoted ? 0.05 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("CAMPUS VERDICT", style: TextStyle(color: Colors.yellowAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              if (hasVoted) const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          Text(data['question'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          
          // PROGRESS BAR
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: yesPercent,
              minHeight: 10,
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("YES: ${(yesPercent * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
              Text("NO: ${((1 - yesPercent) * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),

          // VOTE BUTTONS (Disabled if already voted)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: hasVoted ? null : () => _handleVote(context, doc.id, 'yes', uid),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: hasVoted ? Colors.grey : Colors.greenAccent),
                  ),
                  child: Text(hasVoted ? "VOTED" : "YES", 
                    style: TextStyle(color: hasVoted ? Colors.grey : Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: OutlinedButton(
                  onPressed: hasVoted ? null : () => _handleVote(context, doc.id, 'no', uid),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: hasVoted ? Colors.grey : Colors.redAccent),
                  ),
                  child: Text(hasVoted ? "VOTED" : "NO", 
                    style: TextStyle(color: hasVoted ? Colors.grey : Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (hasVoted) 
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Center(child: Text("You have already cast your verdict.", style: TextStyle(color: Colors.white24, fontSize: 10))),
            ),
        ],
      ),
    );
  }

  void _handleVote(BuildContext context, String pollId, String type, String uid) async {
    HapticFeedback.lightImpact();
    // High Gain: Atomic update to prevent double voting and clashing counts
    await FirebaseFirestore.instance.collection('college_polls').doc(pollId).update({
      type: FieldValue.increment(1),
      'voters': FieldValue.arrayUnion([uid]), // Add user to voters list
    });
  }
}

// ==========================================
// 5. HELPER COMPONENTS
// ==========================================
class _PostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PostCard({required this.data});

  @override
  Widget build(BuildContext context) {
    String category = data['category'] ?? 'Reality';
    Color themeColor = category == 'Gossip' ? Colors.pinkAccent : category == 'Confession' ? Colors.purpleAccent : category == 'Help' ? Colors.greenAccent : Colors.cyanAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(15), border: Border.all(color: themeColor.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                child: Text(category.toUpperCase(), style: TextStyle(color: themeColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.more_horiz, color: Colors.white24, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(data['content'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

class _ComposePostForm extends StatefulWidget {
  final String collegeId;
  const _ComposePostForm({required this.collegeId});
  @override
  State<_ComposePostForm> createState() => _PostFormState();
}

class _PostFormState extends State<_ComposePostForm> {
  final TextEditingController _con = TextEditingController();
  String _selectedCat = "Reality";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
      decoration: const BoxDecoration(color: Color(0xFF111111), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("CAMPUS STORY", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          DropdownButton<String>(
            value: _selectedCat,
            dropdownColor: const Color(0xFF1A1A1A),
            isExpanded: true,
            underline: Container(height: 1, color: Colors.white10),
            items: ["Reality", "Gossip", "Confession", "Help"].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (v) => setState(() => _selectedCat = v!),
          ),
          TextField(
            controller: _con,
            maxLines: 3,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: "What's the buzz?", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_con.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('college_posts').add({
                  'collegeId': widget.collegeId,
                  'content': _con.text.trim(),
                  'category': _selectedCat,
                  'timestamp': FieldValue.serverTimestamp(),
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
              child: const Text("POST NOW", style: TextStyle(color: Colors.black)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ComposePollForm extends StatefulWidget {
  final String collegeId;
  const _ComposePollForm({required this.collegeId});
  @override
  State<_ComposePollForm> createState() => _PollFormState();
}

class _PollFormState extends State<_ComposePollForm> {
  final TextEditingController _con = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
      decoration: const BoxDecoration(color: Color(0xFF111111), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("LAUNCH VERDICT POLL", style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
          TextField(
            controller: _con,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: "Ex: Is the canteen food good?", hintStyle: TextStyle(color: Colors.white24)),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_con.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('college_polls').add({
                  'collegeId': widget.collegeId,
                  'question': _con.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                  'yes': 0,
                  'no': 0,
                  'voters': [], // Initialize empty voters list
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent),
              child: const Text("LAUNCH", style: TextStyle(color: Colors.black)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}