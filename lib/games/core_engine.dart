import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// 1. GAME CONTROLLER (Interfaces)
// =============================================================================

abstract class GameController {
  String get myId;
  void updateGame(Map<String, dynamic> data, {String? mergeWinner});
  void requestRematch(); 
}

class LocalGameController extends GameController {
  @override String get myId => 'P1';
  final Function(Map<String, dynamic>) onUpdate;
  final VoidCallback onReset;
  LocalGameController(this.onUpdate, this.onReset);

  @override
  void updateGame(Map<String, dynamic> data, {String? mergeWinner}) {
    // ✅ CRITICAL FIX: Prefix keys with 'state.' so the UI sees them!
    Map<String, dynamic> update = {};
    data.forEach((key, value) {
      update['state.$key'] = value;
    });
    
    if (mergeWinner != null) update['winner'] = mergeWinner;
    onUpdate(update);
  }

  @override
  void requestRematch() {
    onReset();
  }
}

class OnlineGameController extends GameController {
  final String gameId;
  final String userId;
  final bool isHost;
  
  OnlineGameController(this.gameId, this.userId, this.isHost);
  
  @override String get myId => userId;

  @override
  void updateGame(Map<String, dynamic> data, {String? mergeWinner}) {
    Map<String, dynamic> update = {};
    data.forEach((key, value) {
      update['state.$key'] = value;
    });
    if (mergeWinner != null) update['winner'] = mergeWinner;
    
    FirebaseFirestore.instance.collection('games').doc(gameId).update(update);
  }

  @override
  void requestRematch() {
    String field = isHost ? 'rematchHost' : 'rematchJoiner';
    FirebaseFirestore.instance.collection('games').doc(gameId).update({field: true});
  }
}

// =============================================================================
// 2. GAME STATE GENERATOR (Centralized Logic)
// =============================================================================

Map<String, dynamic> getInitialGameState(String type, String hostId) {
  // AI Configuration (Target Scores)
  int aiTarget = 0;
  if (hostId == 'P1') { 
    if (type == 'snake') aiTarget = 150; 
    if (type == 'whack') aiTarget = 15;
    if (type == 'tapattack') aiTarget = 100;
    if (type == '2048') aiTarget = 2048; 
    if (type == 'mines') aiTarget = 5; 
    if (type == 'typer') aiTarget = 100; 
    if (type == 'math') aiTarget = 10;
    if (type == 'trivia') aiTarget = 50;
    if (type == 'wordle') aiTarget = 4; 
  }

  // --- GAME STATES ---
  if (type == 'cricket') return {'p1Score': -1, 'p2Score': aiTarget > 0 ? aiTarget : -1, 'turn': hostId};
  if (type == 'tictactoe') return {'board': List.filled(9, ''), 'turn': hostId};
  if (type == 'connect4') return {'board': List.filled(42, ''), 'turn': hostId};
  if (type == 'snake') return {'p1Score': -1, 'p2Score': aiTarget > 0 ? aiTarget : -1};
  if (type == 'rps') return {'p1Move': '', 'p2Move': ''};
  if (type == 'gomoku') return {'board': List.filled(100, ''), 'turn': hostId};
  if (type == 'guessnum') return {'target': -1, 'guesses': [], 'host': hostId, 'turn': hostId};
  if (type == 'simon') return {'sequence': [], 'userStep': 0, 'active': true, 'turn': 'AI'}; 
  if (type == '2048') return {'grid': List.filled(16, 0)..first = 2, 'p2Score': aiTarget};
  if (type == 'mines') return {'grid': List.generate(25, (_) => Random().nextBool()), 'revealed': List.filled(25, false), 'p2Score': aiTarget};
  if (type == 'wordle') return {'word': 'CODE', 'guesses': [], 'turn': hostId, 'p2Score': aiTarget};
  if (type == 'whack') return {'mole': -1, 'p1Score': 0, 'p2Score': aiTarget};
  if (type == 'lights') return {'grid': List.generate(25, (_) => Random().nextBool())};
  
  if (type == 'ludo') return {'p1Tokens': [0,0,0,0], 'p2Tokens': [0,0,0,0], 'dice': 0, 'turn': hostId, 'canRoll': true};
  
  if (type == 'dots') return {'lines': List.filled(40, 0), 'boxes': List.filled(20, 0), 'turn': hostId};
  if (type == 'ships') return {'p1Grid': List.filled(25, 0), 'p2Grid': List.filled(25, 0), 'turn': hostId};
  if (type == 'hangman') return {'word': 'FLUTTER', 'guesses': [], 'host': hostId};
  if (type == 'memory') return {'grid': [1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8]..shuffle(), 'revealed': List.filled(16, false), 'turn': hostId};
  if (type == 'tapattack') return {'board': List.filled(25, ''), 'scores': {hostId: 0}, 'p2Score': aiTarget};
  if (type == 'trivia') return {'q': 0, 'p1Score': 0, 'p2Score': aiTarget, 'turn': hostId};
  if (type == 'math') return {'p1Score': 0, 'p2Score': aiTarget, 'turn': hostId};
  if (type == 'carrom') return {'turn': hostId, 'canRoll': true};
  if (type == 'typer') return {'p1Score': 0, 'p2Score': aiTarget};

  return {};
}