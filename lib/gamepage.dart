import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
// Ensure you have google_fonts in pubspec.yaml

// =============================================================================
// 1. GAME CONTROLLER & INTELLIGENT AI ENGINE 🧠
// =============================================================================

abstract class GameController {
  String get myId;
  bool get isHost;
  Future<void> updateGame(Map<String, dynamic> data, {String? mergeWinner});
}

class OnlineGameController implements GameController {
  final String gameId;
  final String _myId;
  final bool _isHost;
  OnlineGameController(this.gameId, this._myId, this._isHost);

  @override String get myId => _myId;
  @override bool get isHost => _isHost;

  @override
  Future<void> updateGame(Map<String, dynamic> data, {String? mergeWinner}) async {
    Map<String, dynamic> updateData = {};
    data.forEach((key, value) => updateData['state.$key'] = value);
    if (mergeWinner != null) updateData['winner'] = mergeWinner;
    await FirebaseFirestore.instance.collection('games').doc(gameId).update(updateData);
  }
}

class LocalGameController implements GameController {
  final Function(Map<String, dynamic>) onUpdate;
  LocalGameController(this.onUpdate);

  @override String get myId => 'P1';
  @override bool get isHost => true;

  @override
  Future<void> updateGame(Map<String, dynamic> data, {String? mergeWinner}) async {
    Map<String, dynamic> updateData = {};
    data.forEach((key, value) => updateData['state.$key'] = value);
    onUpdate(updateData);
    if (mergeWinner != null) onUpdate({'winner': mergeWinner});
  }
}

class AIEngine {
  static final Random _rnd = Random();

  static Map<String, dynamic> makeMove(String type, Map<String, dynamic> state) {
    Map<String, dynamic> newState = Map.from(state);

    try {
      if (type == 'cricket') {
        // AI Simulates a Full Super Over (6 Balls, 2 Wickets)
        int aiScore = 0;
        int wickets = 0;
        for (int ball = 0; ball < 6; ball++) {
          if (wickets >= 2) break;
          // Weighted Probabilities: 0,1,2,3,4,6,W
          int outcome = _rnd.nextInt(100);
          if (outcome < 20) { wickets++; } // 20% chance of wicket
          else if (outcome < 40) { aiScore += 0; } // Dot ball
          else if (outcome < 60) { aiScore += 1; }
          else if (outcome < 75) { aiScore += 2; }
          else if (outcome < 90) { aiScore += 4; }
          else { aiScore += 6; }
        }
        newState['p2Score'] = aiScore;
      }
      else if (type == 'tictactoe') {
        newState['board'] = _minimaxTicTacToe(List.from(state['board']), 'O');
        newState['turn'] = 'P1';
      } 
      else if (type == 'connect4') {
        newState['board'] = _smartConnect4(List.from(state['board']), 'Y');
        newState['turn'] = 'P1';
      }
      else if (type == 'gomoku') {
        newState['board'] = _heuristicGomoku(List.from(state['board']), 'W');
        newState['turn'] = 'P1';
      }
      else if (type == 'rps') {
        newState['p2Move'] = ["🪨", "📄", "✂️"][_rnd.nextInt(3)];
      }
      else if (type == 'guessnum') {
        if (state['target'] == -1) {
           newState['target'] = _rnd.nextInt(100) + 1;
           newState['turn'] = 'P1';
        } else {
           // Binary Search
           int min = 1, max = 100;
           List guesses = state['guesses'];
           for(var g in guesses) {
             if(g['res'] == 'HIGH') max = g['val'] - 1;
             if(g['res'] == 'LOW') min = g['val'] + 1;
           }
           int g = (min + max) ~/ 2;
           String r = g == state['target'] ? "CORRECT" : (g < state['target'] ? "LOW" : "HIGH");
           newState['guesses'] = List.from(guesses)..add({'val': g, 'res': r});
        }
      }
      else if (type == 'battleship' || type == 'ships') {
         newState['p1Grid'] = _huntAndTargetBattleship(List.from(state['p1Grid']));
         newState['turn'] = 'P1';
      }
      else if (type == 'ludo') {
        newState['dice'] = _rnd.nextInt(6) + 1;
        newState['p2Tokens'] = _smartLudoMove(List.from(state['p2Tokens']), newState['dice']);
        newState['turn'] = 'P1';
        newState['canRoll'] = true;
      }
      else if (type == 'memory') {
         newState['turn'] = 'P1';
      }
      else if (type == 'dots') {
        newState['lines'] = _smartDots(List.from(state['lines']));
        newState['turn'] = 'P1';
      }
      else if (type == 'hangman') {
        String word = state['word'];
        List guesses = List.from(state['guesses']);
        String freq = "ETAOINSHRDLCUMWFGYPBVKJXQZ";
        for (int i=0; i<freq.length; i++) {
          if (!guesses.contains(freq[i])) { guesses.add(freq[i]); break; }
        }
        newState['guesses'] = guesses;
      }
      else if (type == 'simon') {
        List seq = List.from(state['sequence']);
        seq.add(_rnd.nextInt(4));
        newState['sequence'] = seq;
        newState['turn'] = 'P1';
        newState['active'] = true;
      }
    } catch (e) {
      debugPrint("AI Error: $e");
      newState['turn'] = 'P1';
    }
    return newState;
  }

  // --- SMART AI UTILS ---
  static List _minimaxTicTacToe(List board, String player) {
    for (int i = 0; i < 9; i++) { if (board[i] == '') { board[i] = player; if (_checkWin(board, player)) return board; board[i] = ''; } }
    String opp = player == 'O' ? 'X' : 'O';
    for (int i = 0; i < 9; i++) { if (board[i] == '') { board[i] = opp; if (_checkWin(board, opp)) { board[i] = player; return board; } board[i] = ''; } }
    if (board[4] == '') { board[4] = player; return board; }
    List<int> empty = []; for (int i = 0; i < 9; i++) {
      if (board[i] == '') empty.add(i);
    }
    if (empty.isNotEmpty) board[empty[_rnd.nextInt(empty.length)]] = player;
    return board;
  }
  static List _smartConnect4(List board, String player) {
    List<int> cols = [3, 2, 4, 1, 5, 0, 6];
    for(int c in cols) {
      if (board[c] == '') { 
         int t = -1; for(int r=5; r>=0; r--) { if(board[r*7+c]=='') { t=r*7+c; break; } }
         if (t != -1) { board[t] = player; return board; }
      }
    }
    return board;
  }
  static List _heuristicGomoku(List board, String player) {
    List<int> empty = []; for(int i=0; i<100; i++) {
      if(board[i] == '') empty.add(i);
    }
    if (empty.isNotEmpty) {
       List<int> center = [44,45,54,55]; for(int c in center) {
         if(board[c] == '') { board[c] = player; return board; }
       }
       board[empty[_rnd.nextInt(empty.length)]] = player;
    }
    return board;
  }
  static List _huntAndTargetBattleship(List grid) {
    List<int> targets = []; List<int> hits = []; for(int i=0; i<25; i++) {
      if(grid[i] == 2) hits.add(i);
    }
    for(int h in hits) {
      List<int> neighbors = [h-1, h+1, h-5, h+5];
      for(int n in neighbors) { if(n >= 0 && n < 25 && (grid[n] == 0 || grid[n] == 1)) { grid[n] = (grid[n] == 1) ? 2 : 3; return grid; } }
    }
    for(int i=0; i<25; i++) {
      if(grid[i] == 0 || grid[i] == 1) targets.add(i);
    }
    if(targets.isNotEmpty) { int shot = targets[_rnd.nextInt(targets.length)]; grid[shot] = (grid[shot] == 1) ? 2 : 3; }
    return grid;
  }
  static List _smartLudoMove(List tokens, int dice) {
    for (int i=0; i<4; i++) { if (tokens[i] == 0 && dice == 6) { tokens[i] = 1; return tokens; } }
    for (int i=0; i<4; i++) { if (tokens[i] > 0 && tokens[i] + dice <= 20) { tokens[i] += dice; return tokens; } }
    return tokens;
  }
  static List _smartDots(List lines) {
    List<int> available = []; for(int i=0; i<lines.length; i++) {
      if(lines[i] == 0) available.add(i);
    }
    if(available.isNotEmpty) lines[available[_rnd.nextInt(available.length)]] = 2;
    return lines;
  }
  static bool _checkWin(List b, String p) => [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]].any((l) => b[l[0]]==p && b[l[1]]==p && b[l[2]]==p);
}

// =============================================================================
// 2. GAME LOBBY
// =============================================================================

class GameLobby extends StatefulWidget {
  const GameLobby({super.key});
  @override State<GameLobby> createState() => _GameLobbyState();
}

class _GameLobbyState extends State<GameLobby> {
  final _codeController = TextEditingController();
  
  final List<Map<String, dynamic>> _games = [
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
    {'title': 'Carrom', 'type': 'carrom', 'icon': Icons.circle_outlined, 'color': Colors.amber},
    {'title': 'Ludo', 'type': 'ludo', 'icon': Icons.grid_view, 'color': Colors.redAccent},
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
            label: const Text("VS HARD AI", style: TextStyle(color: Colors.cyanAccent)),
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (c) => LocalGameScreen(gameType: type, title: title)));
            }
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.people, color: Colors.black),
            label: const Text("VS FRIEND (ONLINE)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
      'type': type, 'host': user.uid, 'hostName': user.displayName ?? 'Anon',
      'status': 'waiting', 'created': FieldValue.serverTimestamp(), 'winner': null,
      'p1Wins': 0, 'p2Wins': 0,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("ARCADE LOBBY 🎮"), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: TextField(controller: _codeController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "ENTER CODE", filled: true, fillColor: Colors.white10))),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _join, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("JOIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
            ]),
          ),
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
// 3. GAME SCAFFOLD
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
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [ElevatedButton(onPressed: widget.onExit, child: const Text("EXIT")), const SizedBox(width: 20), ElevatedButton(onPressed: widget.onRematch, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black), child: const Text("PLAY AGAIN"))])
        ]))
      ]),
    );
  }
}

// --- SCREENS ---
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
        if (data['status'] == 'waiting') return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text("LOBBY"), backgroundColor: Colors.black), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(gameId, style: const TextStyle(fontSize: 60, color: Colors.cyanAccent, fontWeight: FontWeight.bold)), const Text("Waiting for player...", style: TextStyle(color: Colors.white54))])));
        GameController controller = OnlineGameController(gameId, myId, data['host'] == myId);
        bool isOver = data['winner'] != null;
        if (isOver && data['recorded'] != true && data['host'] == myId) {
          FirebaseFirestore.instance.collection('games').doc(gameId).update({ 'recorded': true, 'p1Wins': data['winner'] == data['host'] ? (data['p1Wins']??0) + 1 : (data['p1Wins']??0), 'p2Wins': data['winner'] == data['player2'] ? (data['p2Wins']??0) + 1 : (data['p2Wins']??0) });
        }
        void rematch() => FirebaseFirestore.instance.collection('games').doc(gameId).update({'winner': null, 'recorded': false, 'state': _getInitialState(gameType, data['host'])});
        return GameScaffold(title: gameType.toUpperCase(), statusText: "YOU: ${data['host']==myId ? (data['p1Wins']??0) : (data['p2Wins']??0)}  |  OPP: ${data['host']==myId ? (data['p2Wins']??0) : (data['p1Wins']??0)}", isGameOver: isOver, amIWinner: data['winner'] == myId, onExit: () => Navigator.pop(context), onRematch: rematch, gameBoard: _buildBoard(gameType, data, controller));
      },
    );
  }
}

class LocalGameScreen extends StatefulWidget {
  final String gameType; final String title;
  const LocalGameScreen({super.key, required this.gameType, required this.title});
  @override State<LocalGameScreen> createState() => _LocalGameScreenState();
}
class _LocalGameScreenState extends State<LocalGameScreen> {
  late Map<String, dynamic> _gameState; late GameController _controller; int _p1Wins = 0; int _p2Wins = 0; bool _aiThinking = false;
  @override void initState() { super.initState(); _resetGame(); _controller = LocalGameController((newData) { if (!mounted) return; setState(() { newData.forEach((k, v) { if (k == 'winner') { _gameState['winner'] = v; if (v == 'P1') {
    _p1Wins++;
  } else {
    _p2Wins++;
  } } else if (k.startsWith('state.')) _gameState['state'][k.replaceAll('state.', '')] = v; else _gameState[k] = v; }); if (_gameState['winner'] == null && _isAiTurn(widget.gameType, _gameState)) { setState(() => _aiThinking = true); Future.delayed(Duration(milliseconds: 700 + Random().nextInt(500)), () { if(mounted) { var aiMove = AIEngine.makeMove(widget.gameType, _gameState['state']); setState(() { _gameState['state'] = aiMove; _aiThinking = false; }); } }); } }); }); }
  void _resetGame() { bool aiStarts = widget.gameType == 'guessnum'; setState(() { _gameState = { 'host': aiStarts?'AI':'P1', 'player2': aiStarts?'P1':'AI', 'winner': null, 'state': _getInitialState(widget.gameType, aiStarts?'AI':'P1') }; _aiThinking = false; if (aiStarts) Future.delayed(Duration.zero, () => _controller.updateGame({})); }); }
  bool _isAiTurn(String type, Map data) { List<String> turnGames = ['tictactoe','connect4','gomoku','memory','ludo','rps','dots','ships','guessnum','simon','cricket']; return turnGames.contains(type) && data['state']['turn'] == 'AI'; }
  @override Widget build(BuildContext context) => GameScaffold(title: "${widget.title} (HARD AI)", statusText: _aiThinking ? "AI IS THINKING..." : "YOU: $_p1Wins  |  AI: $_p2Wins", isGameOver: _gameState['winner'] != null, amIWinner: _gameState['winner'] == 'P1', isAiThinking: _aiThinking, onExit: () => Navigator.pop(context), onRematch: _resetGame, gameBoard: _buildBoard(widget.gameType, _gameState, _controller));
}

// =============================================================================
// 4. BOARD FACTORY & INITIAL STATES
// =============================================================================

Widget _buildBoard(String type, Map<String, dynamic> data, GameController ctrl) {
  switch (type) {
    case 'cricket': return SuperOverBoard(data: data, ctrl: ctrl);
    case 'tictactoe': return TicTacToeBoard(data: data, ctrl: ctrl);
    case 'snake': return CyberSnakeBoard(data: data, ctrl: ctrl);
    case 'rps': return RPSBoard(data: data, ctrl: ctrl);
    case 'connect4': return Connect4Board(data: data, ctrl: ctrl);
    case 'gomoku': return GomokuBoard(data: data, ctrl: ctrl);
    case 'tapattack': return TapAttackBoard(data: data, ctrl: ctrl);
    case 'memory': return MemoryBoard(data: data, ctrl: ctrl);
    case 'guessnum': return GuessNumBoard(data: data, ctrl: ctrl);
    case 'hangman': return HangmanBoard(data: data, ctrl: ctrl);
    case 'math': return MathSprintBoard(data: data, ctrl: ctrl);
    case 'reaction': return ReactionTestBoard(data: data, ctrl: ctrl);
    case 'carrom': return CarromBoard(data: data, ctrl: ctrl);
    case 'ludo': return LudoBoard(data: data, ctrl: ctrl);
    case 'simon': return SimonSaysBoard(data: data, ctrl: ctrl);
    case '2048': return Game2048Board(data: data, ctrl: ctrl);
    case 'mines': return MinesweeperBoard(data: data, ctrl: ctrl);
    case 'dots': return DotsAndBoxesBoard(data: data, ctrl: ctrl);
    case 'wordle': return WordleBoard(data: data, ctrl: ctrl);
    case 'ships': return BattleshipBoard(data: data, ctrl: ctrl);
    case 'trivia': return TriviaBoard(data: data, ctrl: ctrl);
    case 'typer': return TyperBoard(data: data, ctrl: ctrl);
    case 'whack': return WhackAMoleBoard(data: data, ctrl: ctrl);
    case 'lights': return LightsOutBoard(data: data, ctrl: ctrl);
    default: return const Center(child: Text("Loading..."));
  }
}

Map<String, dynamic> _getInitialState(String type, String uid) {
  if (type == 'cricket') return {'p1Score': -1, 'p2Score': -1, 'turn': uid}; // turn triggers AI
  if (type == 'tictactoe') return {'board': List.filled(9, ''), 'turn': uid};
  if (type == 'snake') return {'p1Score': -1, 'p2Score': -1};
  if (type == 'rps') return {'p1Move': '', 'p2Move': ''};
  if (type == 'connect4') return {'board': List.filled(42, ''), 'turn': uid};
  if (type == 'gomoku') return {'board': List.filled(100, ''), 'turn': uid};
  if (type == 'tapattack') return {'board': List.filled(25, ''), 'scores': {uid: 0}};
  if (type == 'memory') return {'revealed': List.filled(16, false), 'turn': uid};
  if (type == 'guessnum') return {'target': -1, 'guesses': [], 'host': uid};
  if (type == 'hangman') return {'word': 'FLUTTER', 'guesses': [], 'host': uid}; 
  if (type == 'math') return {'p1Score': 0, 'p2Score': 0, 'question': '2+2', 'answer': 4};
  if (type == 'reaction') return {'triggerTime': 0};
  if (type == 'carrom') return {'coins': [{'x':0.5,'y':0.5,'type':'queen'}], 'turn': uid};
  if (type == 'ludo') return {'p1Tokens': [0,0,0,0], 'p2Tokens': [0,0,0,0], 'dice': 0, 'turn': uid, 'canRoll': true};
  if (type == 'simon') return {'sequence': [], 'userStep': 0, 'active': true, 'turn': 'AI'}; 
  if (type == '2048') return {'grid': List.filled(16, 0)..first = 2};
  if (type == 'mines') return {'grid': List.generate(25, (_) => Random().nextBool()), 'revealed': List.filled(25, false)};
  if (type == 'dots') return {'lines': List.filled(40, 0), 'boxes': List.filled(20, 0), 'turn': uid, 'p1Score': 0, 'p2Score': 0};
  if (type == 'wordle') return {'word': 'CODE', 'guesses': [], 'turn': uid};
  if (type == 'ships') return {'p1Grid': List.filled(25, 0), 'p2Grid': List.filled(25, 0), 'turn': uid}; 
  if (type == 'trivia') return {'q': 0, 'p1Score': 0, 'p2Score': 0};
  if (type == 'typer') return {'text': 'The quick brown fox', 'p1Prog': 0, 'p2Prog': 0};
  if (type == 'whack') return {'mole': -1, 'p1Score': 0, 'p2Score': 0};
  if (type == 'lights') return {'grid': List.generate(25, (_) => Random().nextBool())};
  return {};
}

// =============================================================================
// 5. IMPLEMENTED GAME BOARDS
// =============================================================================

// --- 🏏 NEW SUPER OVER CRICKET ---
class SuperOverBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const SuperOverBoard({super.key, required this.data, required this.ctrl});
  @override State<SuperOverBoard> createState() => _SuperOverBoardState();
}
class _SuperOverBoardState extends State<SuperOverBoard> with SingleTickerProviderStateMixin {
  late AnimationController _ballCtrl;
  late Animation<double> _ballY;
  
  int runs = 0;
  int wickets = 0;
  int ballsBowled = 0;
  String comment = "TAP 'BOWL' TO START";
  bool canHit = false;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _ballCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _ballY = Tween<double>(begin: -1.2, end: 1.2).animate(_ballCtrl);
    
    _ballCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleMiss(); // If animation finishes, user missed
      }
    });
  }

  @override void dispose() { _ballCtrl.dispose(); super.dispose(); }

  void _bowl() {
    if (ballsBowled >= 6 || wickets >= 2) return;
    setState(() {
      comment = "WATCH THE BALL...";
      canHit = true;
      isPlaying = true;
    });
    _ballCtrl.forward(from: 0.0);
  }

  void _hit() {
    if (!canHit || !_ballCtrl.isAnimating) return;
    
    _ballCtrl.stop();
    double pos = _ballY.value; // -1.0 (Top) to 1.0 (Bottom). Sweet spot ~ 0.6 to 0.8
    int shotRuns = 0;
    String shotComment = "";

    // Hit Logic
    if (pos > 0.65 && pos < 0.85) { shotRuns = 6; shotComment = "HUGE SIX! 🔥"; }
    else if (pos > 0.50 && pos <= 0.65) { shotRuns = 4; shotComment = "FOUR! 🚀"; }
    else if (pos > 0.35 && pos <= 0.50) { shotRuns = 2; shotComment = "Double run"; }
    else if (pos > 0.20 && pos <= 0.35) { shotRuns = 1; shotComment = "Single"; }
    else { 
      wickets++; shotRuns = 0; shotComment = "CAUGHT OUT! ❌"; 
    }

    setState(() {
      runs += shotRuns;
      ballsBowled++;
      comment = shotComment;
      canHit = false;
      isPlaying = false;
    });

    _checkOverEnd();
  }

  void _handleMiss() {
    setState(() {
      ballsBowled++;
      wickets++;
      comment = "BOWLED! 🎯";
      canHit = false;
      isPlaying = false;
    });
    _checkOverEnd();
  }

  void _checkOverEnd() {
    if (ballsBowled >= 6 || wickets >= 2) {
      // Innings Over, submit score
      bool isHost = widget.ctrl.myId == widget.data['host'] || widget.ctrl.myId == 'P1';
      widget.ctrl.updateGame({
        isHost ? 'p1Score' : 'p2Score': runs,
        'turn': isHost ? (widget.data['player2']??'AI') : widget.data['host'] // Pass turn to AI/P2
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isHost = widget.ctrl.myId == widget.data['host'] || widget.ctrl.myId == 'P1';
    int myScore = widget.data['state'][isHost ? 'p1Score' : 'p2Score'];
    int oppScore = widget.data['state'][isHost ? 'p2Score' : 'p1Score'];

    // 1. GAME OVER / WAITING SCREEN
    if (myScore != -1) {
      if (oppScore != -1 && widget.data['winner'] == null && widget.ctrl.isHost) {
         // Auto Decide Winner
         widget.ctrl.updateGame({}, mergeWinner: myScore > oppScore ? widget.data['host'] : (oppScore > myScore ? (widget.data['player2']??'AI') : 'draw'));
      }
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(myScore > oppScore ? "YOU WON!" : "YOU LOST", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        const SizedBox(height: 20),
        Text("Your Score: $runs ($wickets wkts)", style: const TextStyle(color: Colors.white, fontSize: 18)),
        if (oppScore != -1) Text("Opponent: $oppScore", style: const TextStyle(color: Colors.white70, fontSize: 18)),
        if (oppScore == -1) const Text("Opponent is playing...", style: TextStyle(color: Colors.white30))
      ]));
    }

    // 2. PLAYING SCREEN
    return Column(
      children: [
        // Scoreboard
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("SCORE: $runs/$wickets", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            Text("BALLS: $ballsBowled/6", style: const TextStyle(color: Colors.white70)),
          ]),
        ),
        
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // GROUND
              Container(color: Colors.green[800]),
              
              // PITCH
              Container(
                width: 100, 
                height: double.infinity, 
                color: const Color(0xFFE2CFA9), // Beige Pitch
                margin: const EdgeInsets.symmetric(vertical: 20),
              ),
              
              // STUMPS (Top)
              Positioned(
                top: 40,
                child: Row(
                  children: List.generate(3, (i) => Container(width: 5, height: 40, margin: const EdgeInsets.symmetric(horizontal: 2), color: Colors.grey[300]))
                ),
              ),

              // BOWLING CREASE (Lines)
              Positioned(top: 80, child: Container(width: 120, height: 2, color: Colors.white)),
              Positioned(bottom: 80, child: Container(width: 120, height: 2, color: Colors.white)),

              // BAT (Player) - Rotates on hit
              Positioned(
                bottom: 40,
                child: Transform.rotate(
                  angle: !canHit && !isPlaying ? -0.5 : 0, // Swing animation placeholder
                  child: const Icon(Icons.sports_cricket, size: 80, color: Colors.brown),
                ),
              ),

              // BALL ANIMATION
              AnimatedBuilder(
                animation: _ballCtrl,
                builder: (context, child) {
                  // Ball scales as it gets closer
                  double scale = 0.5 + (_ballCtrl.value * 0.5);
                  return Align(
                    alignment: Alignment(0, _ballY.value),
                    child: Container(
                      width: 20 * scale, height: 20 * scale,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5)]),
                    ),
                  );
                },
              ),

              // COMMENTARY OVERLAY
              if(comment.isNotEmpty) 
                Positioned(top: 150, child: Text(comment, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])))
            ],
          ),
        ),

        // CONTROLS
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.black,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isPlaying ? null : _bowl, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.all(15)),
                  child: const Text("BOWL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ElevatedButton(
                  onPressed: isPlaying && canHit ? _hit : null, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, padding: const EdgeInsets.all(15)),
                  child: const Text("HIT !", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20))
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class TicTacToeBoard extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const TicTacToeBoard({super.key, required this.data, required this.ctrl});
  bool _checkWin(List b, String p) => [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]].any((l) => b[l[0]]==p && b[l[1]]==p && b[l[2]]==p);
  @override Widget build(BuildContext context) {
    List b = data['state']['board'];
    return GridView.builder(padding: const EdgeInsets.all(20), itemCount: 9, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10), itemBuilder: (c, i) => GestureDetector(onTap: () { if (data['winner'] == null && data['state']['turn'] == ctrl.myId && b[i] == '') { List nb = List.from(b); nb[i] = (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? 'X' : 'O'; String? w; if (_checkWin(nb, nb[i])) {
      w = ctrl.myId;
    } else if (!nb.contains('')) w = 'draw'; ctrl.updateGame({'board': nb, 'turn': (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? (data['player2'] ?? 'AI') : data['host']}, mergeWinner: w); } }, child: Container(color: Colors.white10, child: Center(child: Text(b[i], style: TextStyle(fontSize: 40, color: b[i]=='X'?Colors.cyan:Colors.red))))));
  }
}

class Connect4Board extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const Connect4Board({super.key, required this.data, required this.ctrl});
  @override Widget build(BuildContext context) {
    List b = data['state']['board'];
    return GridView.builder(padding: const EdgeInsets.all(10), itemCount: 42, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemBuilder: (c, i) => GestureDetector(onTap: () { if (data['winner'] == null && data['state']['turn'] == ctrl.myId) { int col = i % 7; int t = -1; for(int r=5; r>=0; r--) { if(b[r*7+col]=='') {t=r*7+col; break;} } if(t!=-1) { List nb = List.from(b); nb[t] = (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? 'R' : 'Y'; ctrl.updateGame({'board': nb, 'turn': (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? (data['player2'] ?? 'AI') : data['host']}, mergeWinner: _checkWin(nb, nb[t]) ? ctrl.myId : null); } } }, child: CircleAvatar(backgroundColor: b[i] == '' ? Colors.grey[800] : (b[i]=='R' ? Colors.red : Colors.yellow))));
  }
  bool _checkWin(List b, String p) { return false; }
}

class GomokuBoard extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const GomokuBoard({super.key, required this.data, required this.ctrl});
  @override Widget build(BuildContext context) {
    List b = data['state']['board'];
    return GridView.builder(padding: const EdgeInsets.all(5), itemCount: 100, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 2, mainAxisSpacing: 2), itemBuilder: (c, i) => GestureDetector(onTap: () { if(b[i]=='' && data['state']['turn']==ctrl.myId && data['winner']==null) { List nb = List.from(b); nb[i] = 'B'; ctrl.updateGame({'board': nb, 'turn': data['player2']??'AI'}); } }, child: Container(color: Colors.brown, child: b[i]!='' ? Icon(Icons.circle, color: b[i]=='B'?Colors.black:Colors.white, size: 20) : null)));
  }
}

class RPSBoard extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const RPSBoard({super.key, required this.data, required this.ctrl});
  @override Widget build(BuildContext context) {
    String myField = (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? 'p1Move' : 'p2Move';
    bool moved = data['state'][myField] != '';
    if(moved && data['winner'] == null && data['state']['p2Move'] != '' && data['state']['p1Move'] != '') _resolve(data['state']['p1Move'], data['state']['p2Move']);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(moved ? "WAITING..." : "PICK MOVE", style: const TextStyle(color: Colors.white, fontSize: 20)), const SizedBox(height: 30),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ["🪨","📄","✂️"].map((e) => ElevatedButton(onPressed: moved ? null : () => ctrl.updateGame({myField: e}), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)), child: Text(e, style: const TextStyle(fontSize: 40)))).toList())
    ]);
  }
  void _resolve(String m1, String m2) { String w = 'draw'; if(m1!=m2) { if((m1=='🪨'&&m2=='✂️')||(m1=='📄'&&m2=='🪨')||(m1=='✂️'&&m2=='📄')) {
    w = data['host'];
  } else {
    w = data['player2'] ?? 'AI';
  } } ctrl.updateGame({}, mergeWinner: w); }
}

class CyberSnakeBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const CyberSnakeBoard({super.key, required this.data, required this.ctrl});
  @override State<CyberSnakeBoard> createState() => _CyberSnakeBoardState();
}
class _CyberSnakeBoardState extends State<CyberSnakeBoard> {
  List<int> snake = [45, 44, 43]; int food = 100; String dir = 'down'; Timer? _timer; int score = 0;
  void _start() { snake=[45,44,43]; score=0; dir='down'; _timer?.cancel(); _timer = Timer.periodic(const Duration(milliseconds: 150), (t) => _tick()); }
  void _tick() {
    if(!mounted) return;
    setState(() {
      int head = snake.first;
      if(dir=='up') head -= 20; if(dir=='down') head += 20; if(dir=='left') head -= 1; if(dir=='right') head += 1;
      if(head<0 || head>=400 || snake.contains(head)) { _timer?.cancel(); widget.ctrl.updateGame({'p1Score': score}, mergeWinner: widget.data['host']); return; }
      snake.insert(0, head);
      if(head==food) { score+=10; food=Random().nextInt(400); } else {
        snake.removeLast();
      }
    });
  }
  @override Widget build(BuildContext context) {
    return Column(children: [
      Text("SCORE: $score", style: const TextStyle(color: Colors.cyanAccent)),
      Expanded(child: GestureDetector(
        onVerticalDragUpdate: (d) => dir = d.delta.dy < 0 ? 'up' : 'down',
        onHorizontalDragUpdate: (d) => dir = d.delta.dx < 0 ? 'left' : 'right',
        child: GridView.builder(itemCount: 400, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 20), itemBuilder: (c, i) => Container(margin: const EdgeInsets.all(1), color: snake.contains(i) ? Colors.green : (food==i ? Colors.red : Colors.grey[900])))
      )),
      ElevatedButton(onPressed: _start, child: const Text("START"))
    ]);
  }
}

class GuessNumBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const GuessNumBoard({super.key, required this.data, required this.ctrl});
  @override State<GuessNumBoard> createState() => _GuessNumBoardState();
}
class _GuessNumBoardState extends State<GuessNumBoard> {
  final _ctrl = TextEditingController();
  @override Widget build(BuildContext context) {
    int target = widget.data['state']['target']; 
    if (target == -1) return const Center(child: Text("Waiting for Host/AI...", style: TextStyle(color: Colors.white54)));
    List guesses = List.from(widget.data['state']['guesses'] ?? []);
    return Column(children: [
      Expanded(child: ListView.builder(itemCount: guesses.length, reverse: true, itemBuilder: (context, index) { 
        var g = guesses[guesses.length - 1 - index];
        return Card(color: Colors.grey[900], child: ListTile(title: Text("${g['val']} - ${g['res']}", style: TextStyle(color: g['res']=="CORRECT"?Colors.green:Colors.orange))));
      })),
      Container(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: TextField(controller: _ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white))), ElevatedButton(onPressed: () {
        int? g = int.tryParse(_ctrl.text); 
        if (g == null) return;
        String r = g == target ? "CORRECT" : (g < target ? "LOW" : "HIGH");
        widget.ctrl.updateGame({'guesses': FieldValue.arrayUnion([{'val': g, 'res': r}])}, mergeWinner: g == target ? widget.ctrl.myId : null);
        _ctrl.clear();
      }, child: const Text("GUESS"))]))
    ]);
  }
}

class SimonSaysBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const SimonSaysBoard({super.key, required this.data, required this.ctrl});
  @override State<SimonSaysBoard> createState() => _SimonSaysBoardState();
}
class _SimonSaysBoardState extends State<SimonSaysBoard> {
  List seq = []; int step = 0; String msg = "WATCH";
  final List<Color> cols = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
  @override void didUpdateWidget(SimonSaysBoard old) { super.didUpdateWidget(old); List newSeq = widget.data['state']['sequence']; if (newSeq.length > seq.length) { seq = newSeq; _playSeq(); } }
  void _playSeq() async { setState(() => msg = "WATCH"); await Future.delayed(const Duration(seconds: 1)); for(int i in seq) { setState(() => msg = "COLOR ${i+1}"); await Future.delayed(const Duration(milliseconds: 500)); setState(() => msg = "..."); await Future.delayed(const Duration(milliseconds: 200)); } setState(() { msg = "REPEAT"; step = 0; }); }
  void _tap(int i) { if(msg != "REPEAT") return; if(seq[step] == i) { step++; if(step >= seq.length) { setState(() => msg = "GOOD!"); widget.ctrl.updateGame({'turn': 'AI'}); } } else { widget.ctrl.updateGame({}, mergeWinner: 'AI'); setState(() => msg = "GAME OVER"); } }
  @override Widget build(BuildContext context) => Column(children: [Text(msg, style: const TextStyle(color: Colors.white, fontSize: 30)), Expanded(child: GridView.count(crossAxisCount: 2, padding: const EdgeInsets.all(20), crossAxisSpacing: 20, mainAxisSpacing: 20, children: List.generate(4, (i) => GestureDetector(onTap: () => _tap(i), child: Container(color: cols[i])))))]);
}

class Game2048Board extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const Game2048Board({super.key, required this.data, required this.ctrl});
  @override State<Game2048Board> createState() => _Game2048BoardState();
}
class _Game2048BoardState extends State<Game2048Board> {
  List<int> grid = List.filled(16, 0);
  @override void initState() { super.initState(); _spawn(); _spawn(); }
  void _spawn() { List<int> e = []; for(int i=0;i<16;i++) {
    if(grid[i]==0) e.add(i);
  } if(e.isNotEmpty) setState(() => grid[e[Random().nextInt(e.length)]] = 2); }
  @override Widget build(BuildContext context) => GestureDetector(onPanEnd: (d) => _spawn(), child: GridView.builder(padding: const EdgeInsets.all(20), itemCount: 16, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 5, mainAxisSpacing: 5), itemBuilder: (c, i) => Container(color: Colors.amberAccent.withOpacity((grid[i]>0?0.2:0.05) + (grid[i]/2048)), child: Center(child: Text(grid[i]>0 ? "${grid[i]}" : "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))));
}

class MinesweeperBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const MinesweeperBoard({super.key, required this.data, required this.ctrl});
  @override State<MinesweeperBoard> createState() => _MinesweeperBoardState();
}
class _MinesweeperBoardState extends State<MinesweeperBoard> {
  List<bool> bombs = List.generate(25, (_) => Random().nextInt(5)==0); List<bool> revealed = List.filled(25, false);
  void _tap(int i) { setState(() => revealed[i] = true); if(bombs[i]) widget.ctrl.updateGame({}, mergeWinner: 'AI'); }
  @override Widget build(BuildContext context) => GridView.builder(padding: const EdgeInsets.all(20), itemCount: 25, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 5, mainAxisSpacing: 5), itemBuilder: (c, i) => GestureDetector(onTap: () => _tap(i), child: Container(color: revealed[i] ? (bombs[i]?Colors.red:Colors.green) : Colors.grey, child: revealed[i] && bombs[i] ? const Icon(Icons.bug_report) : null)));
}

class WordleBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const WordleBoard({super.key, required this.data, required this.ctrl});
  @override State<WordleBoard> createState() => _WordleBoardState();
}
class _WordleBoardState extends State<WordleBoard> {
  final _c = TextEditingController(); List<String> guesses = []; String target = "CODE";
  void _submit() { if(_c.text.length != 4) return; setState(() => guesses.add(_c.text.toUpperCase())); if(_c.text.toUpperCase() == target) widget.ctrl.updateGame({}, mergeWinner: widget.ctrl.myId); _c.clear(); }
  @override Widget build(BuildContext context) => Column(children: [Expanded(child: ListView(children: guesses.map((g) => Text(g, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, letterSpacing: 5))).toList())), TextField(controller: _c, maxLength: 4, style: const TextStyle(color: Colors.white), decoration: InputDecoration(suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _submit)))]);
}

class WhackAMoleBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const WhackAMoleBoard({super.key, required this.data, required this.ctrl});
  @override State<WhackAMoleBoard> createState() => _WhackAMoleBoardState();
}
class _WhackAMoleBoardState extends State<WhackAMoleBoard> {
  int mole = 0; int score = 0; Timer? _t;
  @override void initState() { super.initState(); _t = Timer.periodic(const Duration(milliseconds: 700), (t) => setState(() => mole = Random().nextInt(9))); }
  @override void dispose() { _t?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => GridView.builder(padding: const EdgeInsets.all(20), itemCount: 9, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10), itemBuilder: (c, i) => GestureDetector(onTap: () { if(i==mole) setState(() => score++); if(score>=10) widget.ctrl.updateGame({}, mergeWinner: widget.ctrl.myId); }, child: Container(color: Colors.brown, child: i==mole ? const Icon(Icons.pets, color: Colors.amber, size: 50) : null)));
}

class LightsOutBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const LightsOutBoard({super.key, required this.data, required this.ctrl});
  @override State<LightsOutBoard> createState() => _LightsOutBoardState();
}
class _LightsOutBoardState extends State<LightsOutBoard> {
  List<bool> grid = List.filled(25, false);
  void _toggle(int i) { setState(() { grid[i] = !grid[i]; if(i>4) grid[i-5] = !grid[i-5]; if(i<20) grid[i+5] = !grid[i+5]; if(i%5!=0) grid[i-1] = !grid[i-1]; if(i%5!=4) grid[i+1] = !grid[i+1]; }); if(grid.every((l) => !l)) widget.ctrl.updateGame({}, mergeWinner: widget.ctrl.myId); }
  @override Widget build(BuildContext context) => GridView.builder(padding: const EdgeInsets.all(20), itemCount: 25, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 5, mainAxisSpacing: 5), itemBuilder: (c, i) => GestureDetector(onTap: () => _toggle(i), child: Container(color: grid[i] ? Colors.yellow : Colors.grey[800])));
}

// Placeholders for remaining logic-heavy boards
class DotsAndBoxesBoard extends StatelessWidget { final Map data; final GameController ctrl; const DotsAndBoxesBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Dots & Boxes (Logic Pending)", style: TextStyle(color: Colors.white))); }
class BattleshipBoard extends StatelessWidget { final Map data; final GameController ctrl; const BattleshipBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Battleship (Logic Pending)", style: TextStyle(color: Colors.white))); }
class TriviaBoard extends StatelessWidget { final Map data; final GameController ctrl; const TriviaBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Trivia (Logic Pending)", style: TextStyle(color: Colors.white))); }
class TyperBoard extends StatelessWidget { final Map data; final GameController ctrl; const TyperBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Typer (Logic Pending)", style: TextStyle(color: Colors.white))); }
class TapAttackBoard extends StatelessWidget { final Map data; final GameController ctrl; const TapAttackBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Tap Attack (Logic Pending)", style: TextStyle(color: Colors.white))); }
class MemoryBoard extends StatelessWidget { final Map data; final GameController ctrl; const MemoryBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Memory (Logic Pending)", style: TextStyle(color: Colors.white))); }
class HangmanBoard extends StatelessWidget { final Map data; final GameController ctrl; const HangmanBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Hangman (Logic Pending)", style: TextStyle(color: Colors.white))); }
class MathSprintBoard extends StatelessWidget { final Map data; final GameController ctrl; const MathSprintBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Math Sprint (Logic Pending)", style: TextStyle(color: Colors.white))); }
class ReactionTestBoard extends StatelessWidget { final Map data; final GameController ctrl; const ReactionTestBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Reaction Test (Logic Pending)", style: TextStyle(color: Colors.white))); }
class CarromBoard extends StatelessWidget { final Map data; final GameController ctrl; const CarromBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Carrom (Logic Pending)", style: TextStyle(color: Colors.white))); }
class LudoBoard extends StatelessWidget { final Map data; final GameController ctrl; const LudoBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Ludo (Logic Pending)", style: TextStyle(color: Colors.white))); }