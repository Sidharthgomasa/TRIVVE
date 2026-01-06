import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// --------------------------------------------------
/// TRIVVE MAP (FOUNDATION – TRUST FIRST)
/// --------------------------------------------------

class TrriveNeonMap extends StatelessWidget {
  const TrriveNeonMap({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Nearby Activity"),
        elevation: 0,
      ),
      body: Column(
        children: [
          _infoBanner(),
          Expanded(child: _mapPlaceholder()),
        ],
      ),
    );
  }

  /// Explains purpose clearly (trust)
  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: const Border(
          bottom: BorderSide(color: Colors.white12),
        ),
      ),
      child: const Text(
        "This map shows live updates and activity shared by people nearby.\nLocation access will be requested only when needed.",
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  /// Temporary visual placeholder (no permissions)
  Widget _mapPlaceholder() {
    return Stack(
      children: [
        // Background grid (map-like feel)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0E0E0E), Color(0xFF000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // Center markers
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('map_updates')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "No nearby updates yet",
                  style: TextStyle(color: Colors.white38),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final data =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
                return _MapUpdateCard(data: data);
              },
            );
          },
        ),
      ],
    );
  }
}

/// --------------------------------------------------
/// MAP UPDATE CARD (TRUST STYLE)
/// --------------------------------------------------

class _MapUpdateCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MapUpdateCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on,
            color: Colors.cyanAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data['title'] ?? "Nearby activity",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
