import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trivve/games/core_engine.dart'; // Required for getInitialGameState

class SquadEngine {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. CREATE SQUAD
  Future<String> createSquad() async {
    User? user = _auth.currentUser;
    if (user == null) throw "Login required";

    String squadId = _generateCode();
    
    await _db.collection('squads').doc(squadId).set({
      'hostId': user.uid,
      'hostName': user.displayName ?? 'Unknown',
      'members': [
        {'uid': user.uid, 'name': user.displayName ?? 'Unknown', 'status': 'ready'}
      ],
      'activeGame': null, 
      'created': FieldValue.serverTimestamp(),
    });

    return squadId;
  }

  // 2. JOIN SQUAD (Strict 4-Player Limit)
  Future<void> joinSquad(String squadId) async {
    User? user = _auth.currentUser;
    if (user == null) throw "Login required";

    DocumentReference ref = _db.collection('squads').doc(squadId);
    
    // Use transaction to prevent race conditions
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(ref);

      if (!snapshot.exists) throw "Squad does not exist";
      
      List members = List.from(snapshot['members']);
      
      // Check if already in
      if (members.any((m) => m['uid'] == user.uid)) return; 

      // Max 4 Players Check
      if (members.length >= 4) {
        throw "Squad is Full (Max 4 Players)";
      }

      members.add({'uid': user.uid, 'name': user.displayName ?? 'Player', 'status': 'ready'});
      
      transaction.update(ref, {'members': members});
    });
  }

  // 3. LEAVE SQUAD
  Future<void> leaveSquad(String squadId) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentReference ref = _db.collection('squads').doc(squadId);
    
    await _db.runTransaction((transaction) async {
      DocumentSnapshot doc = await transaction.get(ref);
      if (!doc.exists) return;

      List members = List.from(doc['members']);
      members.removeWhere((m) => m['uid'] == user.uid);

      if (members.isEmpty) {
        transaction.delete(ref); // Delete empty squad
      } else {
        // If host left, assign new host
        bool hostLeft = doc['hostId'] == user.uid;
        Map<String, dynamic> updates = {'members': members};
        if (hostLeft) {
          updates['hostId'] = members[0]['uid'];
          updates['hostName'] = members[0]['name'];
        }
        transaction.update(ref, updates);
      }
    });
  }

  // 4. LAUNCH GAME (Flexible 2-4 Players)
  Future<void> launchGame(String squadId, String gameType) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot squadDoc = await _db.collection('squads').doc(squadId).get();
    List members = squadDoc['members'];
    
    // Filter out host (P1)
    List<Map> others = members.where((m) => m['uid'] != user.uid).map((e) => e as Map).toList();
    
    // Assign slots dynamically (others might be empty, or have 1, 2, or 3 people)
    String? p2Id = others.isNotEmpty ? others[0]['uid'] : null;
    String? p2Name = others.isNotEmpty ? others[0]['name'] : null;
    
    String? p3Id = others.length > 1 ? others[1]['uid'] : null;
    String? p3Name = others.length > 1 ? others[1]['name'] : null;
    
    String? p4Id = others.length > 2 ? others[2]['uid'] : null;
    String? p4Name = others.length > 2 ? others[2]['name'] : null;

    String gameId = "${squadId}_${DateTime.now().millisecondsSinceEpoch}";
    
    // Initial State needs to know exactly how many players to setup tokens/scores
    Map<String, dynamic> initialState = getInitialGameState(gameType, user.uid);

    await _db.collection('games').doc(gameId).set({
      'type': gameType,
      'status': 'playing',
      'host': user.uid,
      'hostName': user.displayName ?? 'Host',
      'player2': p2Id, 'player2Name': p2Name,
      'player3': p3Id, 'player3Name': p3Name,
      'player4': p4Id, 'player4Name': p4Name,
      'players': members.map((m) => m['uid']).toList(), // List of all IDs for security
      'state': initialState,
      'created': FieldValue.serverTimestamp(),
      'winner': null,
      'rematchHost': false,
      'rematchJoiner': false,
    });

    // Notify Squad to show the Join Popup
    await _db.collection('squads').doc(squadId).update({
      'activeGame': {'id': gameId, 'type': gameType}
    });
  }

  // --- HELPER METHODS ---
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}