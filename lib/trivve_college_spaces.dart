import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// 1. COLLEGE LIST SCREEN (Entry Point)
// =============================================================================

class CollegeSpacesHub extends StatefulWidget {
  const CollegeSpacesHub({super.key});

  @override
  State<CollegeSpacesHub> createState() => _CollegeSpacesHubState();
}

class _CollegeSpacesHubState extends State<CollegeSpacesHub> {
  bool _isSeeding = false;
  
  // SHORTENED LIST FOR DEMO (Your full list is safe in DB if you already ran it)
  // If you need to re-seed, the logic handles it.
  final List<String> _masterCollegeList = [
    "JNTU Hyderabad (JNTUH)", "Osmania University (OU)", "CBIT Gandipet", 
    "Vasavi College", "VNR VJIET", "GRIET", "Sreenidhi (SNIST)", 
    "Malla Reddy University", "Anurag University", "IIT Hyderabad"
  ];

  Future<void> _seedColleges() async {
    setState(() => _isSeeding = true);
    final colRef = FirebaseFirestore.instance.collection('colleges');
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    for (String name in _masterCollegeList) {
      String docId = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      batch.set(colRef.doc(docId), {
        'name': name,
        'region': 'Telangana',
        'isLocked': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    setState(() => _isSeeding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("CAMPUS SPACES", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.sync, color: Colors.white), onPressed: _seedColleges)
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('colleges').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          
          if (snapshot.data!.docs.isEmpty) {
             return Center(child: ElevatedButton(onPressed: _seedColleges, child: const Text("LOAD COLLEGES")));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index];
              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.school, color: Colors.purpleAccent),
                  title: Text(data['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => CollegeMainScreen(collegeId: data.id, collegeName: data['name'])));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// 2. MAIN COLLEGE SCREEN (TABS: FEED & POLLS)
// =============================================================================

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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.collegeName, style: const TextStyle(fontSize: 16, color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "REALITY FEED"),
            Tab(text: "THE VERDICT (POLLS)"),
          ],
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
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () {
          if (_tabController.index == 0) {
            _showPostDialog(context); // Post Text
          } else {
            _showPollDialog(context); // Create Poll
          }
        },
      ),
    );
  }

  // --- DIALOGS ---
  void _showPostDialog(BuildContext context) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      builder: (c) => Padding(padding: MediaQuery.of(c).viewInsets, child: _ComposePostForm(collegeId: widget.collegeId))
    );
  }

  void _showPollDialog(BuildContext context) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      builder: (c) => Padding(padding: MediaQuery.of(c).viewInsets, child: _ComposePollForm(collegeId: widget.collegeId))
    );
  }
}

// =============================================================================
// 3. TAB 1: REALITY FEED (The existing feed)
// =============================================================================

class _FeedTab extends StatelessWidget {
  final String collegeId;
  const _FeedTab({required this.collegeId});

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('college_posts')
          .where('collegeId', isEqualTo: collegeId)
          .where('timestamp', isGreaterThan: cutoff)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Silence on campus...", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (c, i) => _PostCard(doc: snapshot.data!.docs[i]),
        );
      },
    );
  }
}

// =============================================================================
// 4. TAB 2: THE VERDICT (POLLS) - 🆕 NEW FEATURE
// =============================================================================

class _PollsTab extends StatelessWidget {
  final String collegeId;
  const _PollsTab({required this.collegeId});

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('college_polls')
          .where('collegeId', isEqualTo: collegeId)
          .where('timestamp', isGreaterThan: cutoff)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.yellowAccent));
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No active verdicts. Start one!", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (c, i) => _PollCard(doc: snapshot.data!.docs[i]),
        );
      },
    );
  }
}

// =============================================================================
// 5. POLL WIDGETS (Card & Form)
// =============================================================================

class _PollCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _PollCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    List<dynamic> voters = data['voters'] ?? [];
    bool iVoted = voters.contains(myUid);
    
    List<dynamic> options = data['options']; // List of strings
    Map<String, dynamic> votes = data['vote_counts'] ?? {}; // Map "0": 12, "1": 5
    int totalVotes = voters.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.yellowAccent.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(10)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.how_to_vote, color: Colors.yellowAccent, size: 16),
            const SizedBox(width: 5),
            const Text("THE VERDICT", style: TextStyle(color: Colors.yellowAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Spacer(),
            Text("$totalVotes Votes", style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
          Text(data['question'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // OPTIONS LIST
          ...List.generate(options.length, (index) {
            String opText = options[index];
            int opVotes = votes[index.toString()] ?? 0;
            double percent = totalVotes == 0 ? 0 : (opVotes / totalVotes);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: iVoted 
                ? _buildResultBar(opText, percent, opVotes) // Show result if voted
                : _buildVoteButton(context, index, opText)  // Show button if not
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultBar(String text, double percent, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: const TextStyle(color: Colors.white70)),
            Text("${(percent * 100).toInt()}%", style: const TextStyle(color: Colors.yellowAccent)),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: percent,
          backgroundColor: Colors.grey[800],
          color: Colors.yellowAccent,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        )
      ],
    );
  }

  Widget _buildVoteButton(BuildContext context, int index, String text) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.grey),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.centerLeft
      ),
      onPressed: () {
        FirebaseFirestore.instance.collection('college_polls').doc(doc.id).update({
          "vote_counts.$index": FieldValue.increment(1),
          "voters": FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid])
        });
      },
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _ComposePollForm extends StatefulWidget {
  final String collegeId;
  const _ComposePollForm({required this.collegeId});

  @override
  State<_ComposePollForm> createState() => _ComposePollFormState();
}

class _ComposePollFormState extends State<_ComposePollForm> {
  final _questionCtrl = TextEditingController();
  final _op1Ctrl = TextEditingController();
  final _op2Ctrl = TextEditingController();
  bool _isPosting = false;

  Future<void> _postPoll() async {
    if (_questionCtrl.text.isEmpty || _op1Ctrl.text.isEmpty || _op2Ctrl.text.isEmpty) return;
    setState(() => _isPosting = true);

    try {
      await FirebaseFirestore.instance.collection('college_polls').add({
        'collegeId': widget.collegeId,
        'question': _questionCtrl.text.trim(),
        'options': [_op1Ctrl.text.trim(), _op2Ctrl.text.trim()], // Just 2 options for simplicity
        'vote_counts': {'0': 0, '1': 0},
        'voters': [],
        'timestamp': FieldValue.serverTimestamp(),
        'authorUid': FirebaseAuth.instance.currentUser!.uid
      });
      if(mounted) Navigator.pop(context);
    } catch(e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("START A VERDICT", style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          TextField(controller: _questionCtrl, decoration: const InputDecoration(hintText: "Ask something...", filled: true, fillColor: Colors.black12), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          TextField(controller: _op1Ctrl, decoration: const InputDecoration(hintText: "Option 1 (e.g. Yes)", filled: true, fillColor: Colors.black12), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          TextField(controller: _op2Ctrl, decoration: const InputDecoration(hintText: "Option 2 (e.g. No)", filled: true, fillColor: Colors.black12), style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent),
              onPressed: _isPosting ? null : _postPoll,
              child: const Text("LAUNCH POLL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// =============================================================================
// 6. EXISTING POST LOGIC (Minimally changed)
// =============================================================================

class _ComposePostForm extends StatefulWidget {
  final String collegeId;
  const _ComposePostForm({required this.collegeId});
  @override
  State<_ComposePostForm> createState() => _ComposePostFormState();
}

class _ComposePostFormState extends State<_ComposePostForm> {
  final _textController = TextEditingController();
  String _selectedCategory = "General Reality";
  bool _isPosting = false;
  final List<String> _categories = ["General Reality", "Placements", "Exams", "Events", "Confession", "Sports"];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("POST REALITY", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _selectedCategory, dropdownColor: Colors.grey[800], isExpanded: true,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
          ),
          TextField(controller: _textController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "What's happening?", hintStyle: TextStyle(color: Colors.grey))),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () async {
              if (_textController.text.isEmpty) return;
              setState(() => _isPosting = true);
              await FirebaseFirestore.instance.collection('college_posts').add({
                'collegeId': widget.collegeId, 'content': _textController.text.trim(), 'category': _selectedCategory,
                'timestamp': FieldValue.serverTimestamp(), 'reactions': {'fire':0}
              });
              if(mounted) Navigator.pop(context);
            },
            child: const Text("POST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _PostCard({required this.doc});
  @override
  Widget build(BuildContext context) {
    var data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['category'] ?? "General", style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(data['content'] ?? "", style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 14)),
      ]),
    );
  }
}