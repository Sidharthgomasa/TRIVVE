import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SquadChatWidget extends StatefulWidget {
  final String squadId;
  const SquadChatWidget({super.key, required this.squadId});

  @override
  State<SquadChatWidget> createState() => _SquadChatWidgetState();
}

class _SquadChatWidgetState extends State<SquadChatWidget> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  void _sendMessage() async {
    String text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Add message to Firestore subcollection
    await FirebaseFirestore.instance
        .collection('squads')
        .doc(widget.squadId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Unknown',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text', // can be 'system' later
    });

    // Scroll to bottom
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    String myId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        // 1. MESSAGES LIST
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('squads')
                .doc(widget.squadId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: Text("Start chatting...", style: TextStyle(color: Colors.grey)));
              var docs = snapshot.data!.docs;

              return ListView.builder(
                controller: _scrollCtrl,
                reverse: true, // Stick to bottom
                padding: const EdgeInsets.all(10),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  var data = docs[i].data() as Map<String, dynamic>;
                  bool isMe = data['senderId'] == myId;
                  bool isSystem = data['type'] == 'system';

                  if (isSystem) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                        child: Text(data['text'], style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                      ),
                    );
                  }

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blueAccent : Colors.grey[800],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                          bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) Text(data['senderName'], style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          Text(data['text'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // 2. INPUT AREA
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: const Border(top: BorderSide(color: Colors.white12))
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.cyanAccent),
                onPressed: _sendMessage,
              )
            ],
          ),
        )
      ],
    );
  }
}