import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';

// --- GAME UI IMPORTS ---
import 'package:trivve/games/tictactoe_game.dart';
import 'package:trivve/games/modern_games_1.dart';
import 'package:trivve/games/modern_games_2.dart';
import 'package:trivve/games/modern_games_3.dart';
import 'package:trivve/games/modern_games_4.dart';
import 'package:trivve/games/modern_games_5.dart';
import 'package:trivve/games/modern_games_6.dart';
import 'package:trivve/games/modern_games_7.dart';
import 'package:trivve/games/ludo_game.dart';
import 'package:trivve/games/cricket_game.dart';

// --- CORE & LOGIC IMPORTS ---
import 'package:trivve/games/core_engine.dart'; 
import 'package:trivve/games/ai_brain.dart';

// =============================================================================
// 1. MAIN LOBBY SCREEN (Clean Version - No Squads)
// =============================================================================

class GameLobby extends StatefulWidget {
  const GameLobby({super.key});
  @override 
  State<GameLobby> createState() => _GameLobbyState();
}

class _GameLobbyState extends State<GameLobby> {
  final _codeController = TextEditingController();

  // --- A. GAME DATA LIST ---
  final List<Map<String, dynamic>> _games = [
    {'title': 'Ludo', 'type': 'ludo', 'icon': Icons.grid_view, 'color': Colors.redAccent},
    {'title': 'Carrom', 'type': 'carrom', 'icon': Icons.circle_outlined, 'color': Colors.amber},
    {'title': 'Super Over', 'type': 'cricket', 'icon': Icons.sports_cricket, 'color': const Color(0xFF39FF14)},
    {'title': 'Tic Tac Toe', 'type': 'tictactoe', 'icon': Icons.grid_3x3, 'color': Colors.blue},
    {'title': 'Cyber Snake', 'type': 'snake', 'icon': Icons.all_inclusive, 'color': Colors.cyanAccent},
    {'title': 'Connect 4', 'type': 'connect4', 'icon': Icons.table_rows, 'color': Colors.yellow},
    {'title': 'RPS Duel', 'type': 'rps', 'icon': Icons.cut, 'color': Colors.pink},
    {'title': 'Gomoku', 'type': 'gomoku', 'icon': Icons.grid_on, 'color': Colors.orange},
    {'title': 'Tap Attack', 'type': 'tapattack', 'icon': Icons.touch_app, 'color': Colors.redAccent},
    {'title': 'Memory', 'type': 'memory', 'icon': Icons.style, 'color': Colors.teal},
    {'title': 'Guess Number', 'type': 'guessnum', 'icon': Icons.question_mark, 'color': Colors.purple},
    {'title': 'Hangman', 'type': 'hangman', 'icon': Icons.abc, 'color': Colors.indigo},
    {'title': 'Math Sprint', 'type': 'math', 'icon': Icons.calculate, 'color': Colors.green},
    {'title': 'Reaction', 'type': 'reaction', 'icon': Icons.flash_on, 'color': Colors.cyan},
    {'title': 'Simon Says', 'type': 'simon', 'icon': Icons.surround_sound, 'color': Colors.lightBlueAccent},
    {'title': '2048', 'type': '2048', 'icon': Icons.filter_4, 'color': Colors.amberAccent},
    {'title': 'Minesweeper', 'type': 'mines', 'icon': Icons.flag, 'color': Colors.red},
    {'title': 'Dots & Boxes', 'type': 'dots', 'icon': Icons.bento, 'color': Colors.purpleAccent},
    {'title': 'Wordle', 'type': 'wordle', 'icon': Icons.text_fields, 'color': Colors.greenAccent},
    {'title': 'Battleship', 'type': 'ships', 'icon': Icons.directions_boat, 'color': Colors.blueGrey},
    {'title': 'Trivia', 'type': 'trivia', 'icon': Icons.quiz, 'color': Colors.pinkAccent},
    {'title': 'Typer', 'type': 'typer', 'icon': Icons.keyboard, 'color': Colors.white},
    {'title': 'Whack-A-Mole', 'type': 'whack', 'icon': Icons.pest_control, 'color': Colors.brown},
    {'title': 'Lights Out', 'type': 'lights', 'icon': Icons.lightbulb_outline, 'color': Colors.yellowAccent},
  ];

  // --- B. HELPER METHODS ---

  void _onGameTap(String type, String title) {
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Select Game Mode", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.smart_toy, color: Colors.cyanAccent),
            label: const Text("VS AI", style: TextStyle(color: Colors.cyanAccent)),
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (c) => LocalGameScreen(gameType: type, title: title)));
            }
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.people, color: Colors.black),
            label: const Text("VS FRIEND", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              Navigator.pop(c);
              _createOnline(type);
            }
          )
        ],
      )
    );
  }

  void _createOnline(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login required!")));
      return;
    }
    String code = String.fromCharCodes(Iterable.generate(4, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(32))));
    
    await FirebaseFirestore.instance.collection('games').doc(code).set({
      'type': type, 
      'host': user.uid, 
      'hostName': user.displayName ?? 'Anon',
      'status': 'waiting', 
      'created': FieldValue.serverTimestamp(), 
      'winner': null,
      'rematchHost': false, 'rematchJoiner': false, 
      'state': _getInitialState(type, user.uid)
    });

    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (c) => OnlineGameScreen(gameId: code, gameType: type)));
  }

  void _join() async {
    String code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    var ref = FirebaseFirestore.instance.collection('games').doc(code);
    var doc = await ref.get();

    if (doc.exists && doc['status'] == 'waiting') {
      await ref.update({'player2': FirebaseAuth.instance.currentUser!.uid, 'player2Name': 'Challenger', 'status': 'playing'});
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (c) => OnlineGameScreen(gameId: code, gameType: doc['type'])));
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Game not found!")));
    }
  }

  // --- C. UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("ARCADE LOBBY 🎮"), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Column(
        children: [
          // 1. GAME CODE INPUT
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: TextField(controller: _codeController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "ENTER GAME CODE", filled: true, fillColor: Colors.white10))),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _join, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("JOIN GAME", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
            ]),
          ),

          // 2. GAME GRID
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 140, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _games.length,
              itemBuilder: (c, i) => GestureDetector(
                onTap: () => _onGameTap(_games[i]['type'], _games[i]['title']),
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15), border: Border.all(color: _games[i]['color'])),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_games[i]['icon'], size: 35, color: _games[i]['color']), const SizedBox(height: 10), Text(_games[i]['title'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. GAME SCAFFOLD (Frame + Rematch Logic)
// =============================================================================

class GameScaffold extends StatefulWidget {
  final String title;
  final Widget gameBoard;
  final bool isGameOver;
  final bool amIWinner;
  final String statusText;
  final VoidCallback onExit;
  final VoidCallback onRematch;
  final bool isAiThinking;

  const GameScaffold({super.key, required this.title, required this.gameBoard, this.isGameOver=false, this.amIWinner=false, required this.statusText, required this.onExit, required this.onRematch, this.isAiThinking=false});
  @override State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  late ConfettiController _confettiCtrl;
  @override void initState() { super.initState(); _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3)); }
  @override void didUpdateWidget(GameScaffold old) { super.didUpdateWidget(old); if(widget.isGameOver && !old.isGameOver && widget.amIWinner) _confettiCtrl.play(); }
  @override void dispose() { _confettiCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.grey[900], centerTitle: true, actions: [IconButton(icon: const Icon(Icons.exit_to_app), onPressed: widget.onExit)]),
      body: Stack(children: [
        Column(children: [
          Container(width: double.infinity, color: Colors.grey[900], padding: const EdgeInsets.all(8), child: Text(widget.statusText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold))),
          if(widget.isAiThinking) const LinearProgressIndicator(color: Colors.purpleAccent, backgroundColor: Colors.transparent),
          Expanded(child: widget.gameBoard)
        ]),
        Align(alignment: Alignment.topCenter, child: ConfettiWidget(confettiController: _confettiCtrl, blastDirectionality: BlastDirectionality.explosive)),
        
        if (widget.isGameOver) Container(color: Colors.black87, alignment: Alignment.center, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.amIWinner ? Icons.emoji_events : Icons.close, size: 80, color: widget.amIWinner ? Colors.yellow : Colors.red),
          Text(widget.amIWinner ? "VICTORY" : "DEFEAT", style: TextStyle(color: widget.amIWinner ? Colors.yellow : Colors.red, fontSize: 40, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(onPressed: widget.onExit, child: const Text("EXIT")), 
            const SizedBox(width: 20), 
            ElevatedButton(onPressed: widget.onRematch, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black), child: const Text("REMATCH"))
          ])
        ]))
      ]),
    );
  }
}

// =============================================================================
// 3. SCREENS (Local & Online)
// =============================================================================

class LocalGameScreen extends StatefulWidget {
  final String gameType; final String title;
  const LocalGameScreen({super.key, required this.gameType, required this.title});
  @override State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen> {
  late Map<String, dynamic> _gameState; late GameController _controller; int _p1Wins = 0; int _p2Wins = 0; bool _aiThinking = false;
  
 @override void initState() { 
    super.initState(); 
    _resetGame(); 
    
    _controller = LocalGameController((newData) { 
      if (!mounted) return; 
      setState(() { 
        newData.forEach((k, v) { 
          if (k == 'winner') { _gameState['winner'] = v; if (v == 'P1') _p1Wins++; else _p2Wins++; } 
          else if (k.startsWith('state.')) _gameState['state'][k.replaceAll('state.', '')] = v; 
          else _gameState[k] = v; 
        }); 
        
        if (_gameState['winner'] == null && _isAiTurn(widget.gameType, _gameState)) { 
          setState(() => _aiThinking = true); 
          Future.delayed(Duration(milliseconds: 700 + Random().nextInt(500)), () { 
            if(mounted && _gameState['winner'] == null) { 
              var aiMove = AIBrain.makeMove(widget.gameType, _gameState['state']); 
              setState(() { 
                _gameState['state'] = aiMove; 
                _aiThinking = false; 
                String? winner = AIBrain.getWinner(widget.gameType, _gameState['state']);
                if (winner != null) {
                  _gameState['winner'] = winner;
                  if (winner == 'P1') _p1Wins++; else if (winner == 'AI') _p2Wins++;
                }
              }); 
            } 
          }); 
        } 
      }); 
    }, () => _resetGame()); 
  }

  void _resetGame() { bool aiStarts = widget.gameType == 'guessnum'; setState(() { _gameState = { 'host': aiStarts?'AI':'P1', 'player2': aiStarts?'P1':'AI', 'winner': null, 'state': _getInitialState(widget.gameType, aiStarts?'AI':'P1') }; _aiThinking = false; if (aiStarts) Future.delayed(Duration.zero, () => _controller.updateGame({})); }); }
  bool _isAiTurn(String type, Map data) { 
    List<String> turnGames = ['tictactoe', 'connect4', 'rps', 'guessnum', 'cricket', 'gomoku', 'ludo', 'simon', 'battleship', 'dots', 'memory', 'hangman', 'trivia', 'math', 'carrom']; 
    return turnGames.contains(type) && data['state']['turn'] == 'AI'; 
  }
  @override Widget build(BuildContext context) => GameScaffold(title: "${widget.title} (AI)", statusText: _aiThinking ? "AI IS THINKING..." : "YOU: $_p1Wins  |  AI: $_p2Wins", isGameOver: _gameState['winner'] != null, amIWinner: _gameState['winner'] == 'P1', isAiThinking: _aiThinking, onExit: () => Navigator.pop(context), onRematch: _resetGame, gameBoard: _buildBoard(widget.gameType, _gameState, _controller));
}

class OnlineGameScreen extends StatelessWidget {
  final String gameId; final String gameType;
  const OnlineGameScreen({super.key, required this.gameId, required this.gameType});
  
  @override Widget build(BuildContext context) {
    String myId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('games').doc(gameId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
        
        var data = snapshot.data!.data() as Map<String, dynamic>;
        
        if (data['status'] == 'waiting') {
           return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text("LOBBY"), backgroundColor: Colors.black), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(gameId, style: const TextStyle(fontSize: 60, color: Colors.cyanAccent, fontWeight: FontWeight.bold)), const Text("Waiting for player...", style: TextStyle(color: Colors.white54))])));
        }

        GameController controller = OnlineGameController(gameId, myId, data['host'] == myId);
        
        // Auto Rematch Logic
        if (data['rematchHost'] == true && data['rematchJoiner'] == true && data['host'] == myId) {
             FirebaseFirestore.instance.collection('games').doc(gameId).update({ 
               'winner': null, 'rematchHost': false, 'rematchJoiner': false, 
               'state': _getInitialState(gameType, data['host']) 
             });
        }

        bool isOver = data['winner'] != null;
        
        // Determine Names
        String p1Name = data['hostName'] ?? 'P1';
        String p2Name = data['player2Name'] ?? 'P2';
        
        return GameScaffold(
          title: gameType.toUpperCase(), 
          statusText: "$p1Name  VS  $p2Name", 
          isGameOver: isOver, 
          amIWinner: data['winner'] == myId, 
          onExit: () => Navigator.pop(context), 
          onRematch: () => controller.requestRematch(), 
          gameBoard: _buildBoard(gameType, data, controller)
        );
      },
    );
  }
}

// =============================================================================
// 4. BOARD SWITCHER & INITIAL STATE
// =============================================================================

Widget _buildBoard(String type, Map<String, dynamic> data, GameController ctrl) {
  switch (type) {
    case 'cricket': return CricketGameUI(data: data, controller: ctrl);
    case 'tictactoe': return TicTacToeGameUI(data: data, controller: ctrl);
    case 'connect4': return Connect4GameUI(data: data, controller: ctrl);
    case 'rps': return RPSGameUI(data: data, controller: ctrl);
    case 'memory': return MemoryGameUI(data: data, controller: ctrl);
    case 'snake': return CyberSnakeGameUI(data: data, controller: ctrl);
    case 'gomoku': return GomokuGameUI(data: data, controller: ctrl);
    case 'simon': return SimonGameUI(data: data, controller: ctrl);
    case 'guessnum': return GuessNumberGameUI(data: data, controller: ctrl);
    case 'hangman': return HangmanGameUI(data: data, controller: ctrl);
    case 'math': return MathSprintGameUI(data: data, controller: ctrl);
    case '2048': return Game2048UI(data: data, controller: ctrl);
    case 'mines': return MinesweeperGameUI(data: data, controller: ctrl);
    case 'wordle': return WordleGameUI(data: data, controller: ctrl);
    case 'whack': return WhackAMoleGameUI(data: data, controller: ctrl);
    case 'lights': return LightsOutGameUI(data: data, controller: ctrl);
    case 'tapattack': return TapAttackGameUI(data: data, controller: ctrl);
    case 'ludo': return LudoGameUI(data: data, controller: ctrl);
    case 'ships': return BattleshipGameUI(data: data, controller: ctrl);
    case 'dots': return DotsAndBoxesGameUI(data: data, controller: ctrl);
    case 'trivia': return TriviaGameUI(data: data, controller: ctrl);
    case 'carrom': return CarromGameUI(data: data, controller: ctrl);
    case 'typer': return TyperGameUI(data: data, controller: ctrl); 
    default: return const Center(child: Text("Loading..."));
  }
}

Map<String, dynamic> _getInitialState(String type, String uid) {
  int aiTarget = 0;
  if (uid == 'P1') { 
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

  if (type == 'cricket') return {'p1Score': -1, 'p2Score': aiTarget > 0 ? aiTarget : -1, 'turn': uid};
  if (type == 'tictactoe') return {'board': List.filled(9, ''), 'turn': uid};
  if (type == 'connect4') return {'board': List.filled(42, ''), 'turn': uid};
  if (type == 'snake') return {'p1Score': -1, 'p2Score': aiTarget > 0 ? aiTarget : -1};
  if (type == 'rps') return {'p1Move': '', 'p2Move': ''};
  if (type == 'gomoku') return {'board': List.filled(100, ''), 'turn': uid};
  if (type == 'guessnum') return {'target': -1, 'guesses': [], 'host': uid};
  if (type == 'simon') return {'sequence': [], 'userStep': 0, 'active': true, 'turn': 'AI'}; 
  if (type == '2048') return {'grid': List.filled(16, 0)..first = 2, 'p2Score': aiTarget};
  if (type == 'mines') return {'grid': List.generate(25, (_) => Random().nextBool()), 'revealed': List.filled(25, false), 'p2Score': aiTarget};
  if (type == 'wordle') return {'word': 'CODE', 'guesses': [], 'turn': uid, 'p2Score': aiTarget};
  if (type == 'whack') return {'mole': -1, 'p1Score': 0, 'p2Score': aiTarget};
  if (type == 'lights') return {'grid': List.generate(25, (_) => Random().nextBool())};
  if (type == 'ludo') return {'p1Tokens': [0,0,0,0], 'p2Tokens': [0,0,0,0], 'dice': 0, 'turn': uid, 'canRoll': true};
  if (type == 'dots') return {'lines': List.filled(40, 0), 'boxes': List.filled(20, 0), 'turn': uid};
  if (type == 'battleship') return {'p1Grid': List.filled(25, 0), 'p2Grid': List.filled(25, 0), 'turn': uid};
  if (type == 'hangman') return {'word': 'FLUTTER', 'guesses': [], 'host': uid};
  if (type == 'memory') return {'grid': [1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8]..shuffle(), 'revealed': List.filled(16, false), 'turn': uid};
  if (type == 'tapattack') return {'board': List.filled(25, ''), 'scores': {uid: 0}, 'p2Score': aiTarget};
  if (type == 'trivia') return {'q': 0, 'p1Score': 0, 'p2Score': aiTarget, 'turn': uid};
  if (type == 'math') return {'p1Score': 0, 'p2Score': aiTarget, 'turn': uid};
  if (type == 'carrom') return {'turn': uid, 'canRoll': true}; 
  if (type == 'typer') return {'p1Score': 0, 'p2Score': aiTarget};
  
  return {};
}