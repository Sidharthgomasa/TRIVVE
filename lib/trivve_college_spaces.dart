import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// --------------------------------------------------
/// COLLEGE SPACES → LIVE COLLEGE FEED (TRUST VERSION)
/// --------------------------------------------------

class CollegeSpacesHub extends StatefulWidget {
  const CollegeSpacesHub({super.key});

  @override
  State<CollegeSpacesHub> createState() => _CollegeSpacesHubState();
}

class _CollegeSpacesHubState extends State<CollegeSpacesHub> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Colleges"),
        elevation: 0,
      ),
      body: Column(
        children: [
          _searchBar(),
          Expanded(child: _collegeList()),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (v) => setState(() => _query = v.toLowerCase()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search college",
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _collegeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('colleges')
          .orderBy('name')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs.where((d) {
          return d['name']
              .toString()
              .toLowerCase()
              .contains(_query);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No colleges found",
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            return ListTile(
              title: Text(
                docs[i]['name'],
                style: const TextStyle(color: Colors.white),
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: Colors.cyanAccent),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CollegeFeedScreen(
                      collegeId: docs[i].id,
                      collegeName: docs[i]['name'],
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
}

/// --------------------------------------------------
/// COLLEGE LIVE FEED
/// --------------------------------------------------

class CollegeFeedScreen extends StatelessWidget {
  final String collegeId;
  final String collegeName;

  const CollegeFeedScreen({
    super.key,
    required this.collegeId,
    required this.collegeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(collegeName),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('college_posts')
            .where('collegeId', isEqualTo: collegeId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No updates yet",
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          return ListView.builder(
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              final data =
                  snap.data!.docs[i].data() as Map<String, dynamic>;
              return _PostCard(data: data);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                _CreatePostSheet(collegeId: collegeId),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

/// --------------------------------------------------
/// POST CARD (TRUST STYLE)
/// --------------------------------------------------

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PostCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        data['content'] ?? "",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }
}

/// --------------------------------------------------
/// CREATE POST SHEET
/// --------------------------------------------------

class _CreatePostSheet extends StatefulWidget {
  final String collegeId;
  const _CreatePostSheet({required this.collegeId});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _controller = TextEditingController();

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('college_posts').add({
      'collegeId': widget.collegeId,
      'content': _controller.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser?.uid,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Text(
              "Post an update",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "What’s happening right now?",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                ),
                child: const Text(
                  "Post",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
