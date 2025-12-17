import 'dart:async';
import 'dart:math';
import 'dart:ui'; 
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
import 'package:trivve/trrive_yearbook.dart'; 

// =============================================================================
// 1. MAIN LOBBY SCREEN
// =============================================================================

class GameLobby extends StatefulWidget {
  const GameLobby({super.key});
  @override 
  State<GameLobby> createState() => _GameLobbyState();
}

class _GameLobbyState extends State<GameLobby> with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  late AnimationController _backgroundCtrl;
  late AnimationController _entranceCtrl;
  final List<Star> _stars = [];
  final Random _rng = Random();

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

  @override
  void initState() {
    super.initState();
    _backgroundCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    for(int i=0; i<50; i++) {
      _stars.add(Star(x: _rng.nextDouble(), y: _rng.nextDouble(), size: _rng.nextDouble() * 2 + 1, speed: _rng.nextDouble() * 0.05 + 0.01));
    }
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _backgroundCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

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
    if (user == null) return;
    String code = String.fromCharCodes(Iterable.generate(4, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(32))));
    
    await FirebaseFirestore.instance.collection('games').doc(code).set({
      'type': type, 
      'host': user.uid, 
      'hostName': user.displayName ?? 'Anon',
      'status': 'waiting', 
      'created': FieldValue.serverTimestamp(), 
      'winner': null,
      'rematchHost': false, 'rematchJoiner': false, 
      'state': getInitialGameState(type, user.uid)
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        title: const Text("ARCADE LOBBY 🎮"), 
        backgroundColor: Colors.transparent, 
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.5)))),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30, color: Colors.cyanAccent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TheYearbookScreen())),
          ),
        ],
      ),
      extendBodyBehindAppBar: true, 
      body: Stack(
        children: [
          Positioned.fill(child: AnimatedBuilder(animation: _backgroundCtrl, builder: (context, child) => CustomPaint(painter: StarfieldPainter(_stars, _backgroundCtrl.value)))),
          Column(
            children: [
              const SizedBox(height: 100),
              // IDENTITY HEADER
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
                builder: (context, snapshot) {
                  String name = FirebaseAuth.instance.currentUser?.displayName ?? "Player";
                  String avatar = snapshot.hasData && snapshot.data!.exists ? (snapshot.data!.data() as Map)['avatar'] ?? "🤖" : "🤖";
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
                    child: Row(children: [
                      Text(avatar, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 15),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("OPERATOR", style: TextStyle(color: Colors.cyanAccent.withOpacity(0.7), fontSize: 10, letterSpacing: 2)),
                        Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ]),
                    ]),
                  );
                },
              ),
              // CODE ENTRY
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: TextField(controller: _codeController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "ENTER GAME CODE", hintStyle: TextStyle(color: Colors.white24), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                  const SizedBox(width: 10),
                  ElevatedButton(onPressed: _join, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("JOIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
                ]),
              ),
              // GRID
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 140, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: _games.length,
                  itemBuilder: (c, i) => GestureDetector(onTap: () => _onGameTap(_games[i]['type'], _games[i]['title']), child: GlassGameCard(game: _games[i])),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. VISUAL COMPONENTS
// =============================================================================

class GlassGameCard extends StatelessWidget {
  final Map<String, dynamic> game;
  const GlassGameCard({super.key, required this.game});
  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: game['color'].withOpacity(0.3))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(game['icon'], size: 30, color: game['color']),
        const SizedBox(height: 10),
        Text(game['title'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
      ]),
    );
  }
}

class Star { double x, y, size, speed; Star({required this.x, required this.y, required this.size, required this.speed}); }
class StarfieldPainter extends CustomPainter {
  final List<Star> stars; 
  final double animationValue;

  StarfieldPainter(this.stars, this.animationValue);

  @override 
  void paint(Canvas canvas, Size size) {
    Paint p = Paint(); // Create the paint object
    for (var s in stars) {
      double y = (s.y + (animationValue * s.speed)) % 1.0;
      // Set color with opacity for the glowing effect
      p.color = Colors.white.withOpacity(0.5); 
      // Draw the star at its calculated position
      canvas.drawCircle(Offset(s.x * size.width, y * size.height), s.size, p); 
    }
  }

  @override 
  bool shouldRepaint(covariant StarfieldPainter old) => true;
}

// =============================================================================
// 3. GAME SCAFFOLD & SCREENS
// =============================================================================

class GameScaffold extends StatefulWidget {
  final String title; final Widget gameBoard; final bool isGameOver; final bool amIWinner;
  final String statusText; final VoidCallback onExit; final VoidCallback onRematch;
  final bool isAiThinking; final bool isRematchRequested;

  const GameScaffold({super.key, required this.title, required this.gameBoard, this.isGameOver=false, this.amIWinner=false, required this.statusText, required this.onExit, required this.onRematch, this.isAiThinking=false, this.isRematchRequested=false});
  @override State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  late ConfettiController _confettiCtrl;
  @override void initState() { super.initState(); _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3)); }
  @override void didUpdateWidget(GameScaffold old) { 
    super.didUpdateWidget(old); 
    if(widget.isGameOver && !old.isGameOver && widget.amIWinner) {
      _confettiCtrl.play();
      _grantRewards(FirebaseAuth.instance.currentUser?.uid, true);
    } 
  }

  void _grantRewards(String? uid, bool win) {
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'wins': FieldValue.increment(win ? 1 : 0),
      'xp': FieldValue.increment(win ? 50 : 5),
      'aura': FieldValue.increment(win ? 10 : -2),
    });
  }

  @override void dispose() { _confettiCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Column(children: [
          AppBar(title: Text(widget.title), backgroundColor: Colors.grey[900], centerTitle: true, actions: [IconButton(icon: const Icon(Icons.exit_to_app), onPressed: widget.onExit)]),
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
            ElevatedButton(
              onPressed: widget.isRematchRequested ? null : widget.onRematch, 
              style: ElevatedButton.styleFrom(backgroundColor: widget.isRematchRequested ? Colors.grey : Colors.cyanAccent),
              child: Text(widget.isRematchRequested ? "WAITING..." : "REMATCH")
            )
          ])
        ]))
      ]),
    );
  }
}

class LocalGameScreen extends StatefulWidget {
  final String gameType; final String title;
  const LocalGameScreen({super.key, required this.gameType, required this.title});
  @override State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen> {
  late Map<String, dynamic> _gameState; late GameController _controller; int _p1W=0; int _aiW=0; bool _aiT=false;
  @override void initState() { super.initState(); _reset(); }
  void _reset() { setState(() { _gameState = {'host':'P1', 'winner':null, 'state':getInitialGameState(widget.gameType, 'P1')}; _aiT=false; }); }

  @override Widget build(BuildContext context) {
    _controller = LocalGameController((newData) {
      if(!mounted) return;
      setState(() {
        newData.forEach((k,v) {
          if (k == 'winner') { _gameState['winner'] = v; if(v=='P1') {
            _p1W++;
          } else if(v=='AI') _aiW++; }
          else if (k.startsWith('state.')) _gameState['state'][k.replaceAll('state.', '')] = v;
        });
        if (_gameState['winner']==null && _gameState['state']['turn'] == 'AI') {
          _aiT = true;
          Future.delayed(const Duration(milliseconds: 1000), () {
            if(mounted) {
              var aiMove = AIBrain.makeMove(widget.gameType, _gameState['state']);
              setState(() { _gameState['state'] = aiMove; _aiT = false; _gameState['winner'] = AIBrain.getWinner(widget.gameType, aiMove); });
            }
          });
        }
      });
    }, _reset);
    return GameScaffold(title: widget.title, gameBoard: _buildBoard(widget.gameType, _gameState, _controller), statusText: "YOU: $_p1W  AI: $_aiW", isGameOver: _gameState['winner']!=null, amIWinner: _gameState['winner']=='P1', isAiThinking: _aiT, onExit: ()=>Navigator.pop(context), onRematch: _reset);
  }
}

class OnlineGameScreen extends StatelessWidget {
  final String gameId; final String gameType;
  const OnlineGameScreen({super.key, required this.gameId, required this.gameType});
  @override Widget build(BuildContext context) {
    String myId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('games').doc(gameId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var data = snapshot.data!.data() as Map<String, dynamic>;
        bool isHost = data['host'] == myId;
        
        // HANDSHAKE REMATCH
        if (data['rematchHost'] == true && data['rematchJoiner'] == true && isHost) {
          FirebaseFirestore.instance.collection('games').doc(gameId).update({'winner': null, 'rematchHost': false, 'rematchJoiner': false, 'status': 'playing', 'state': getInitialGameState(gameType, myId)});
        }

        bool iReq = isHost ? (data['rematchHost']??false) : (data['rematchJoiner']??false);
        GameController ctrl = OnlineGameController(gameId, myId, isHost);

        return GameScaffold(title: gameType.toUpperCase(), gameBoard: _buildBoard(gameType, data, ctrl), isGameOver: data['winner']!=null, amIWinner: data['winner']==myId, statusText: "ONLINE MATCH", onExit: ()=>Navigator.pop(context), onRematch: ()=>ctrl.requestRematch(), isRematchRequested: iReq);
      },
    );
  }
}
// =============================================================================

// 4. BOARD SWITCHER

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