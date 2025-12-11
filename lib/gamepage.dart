import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';

// =============================================================================
// 1. GAME LOBBY
// =============================================================================

class GameLobby extends StatefulWidget {
  const GameLobby({super.key});
  @override
  State<GameLobby> createState() => _GameLobbyState();
}

class _GameLobbyState extends State<GameLobby> {
  final _codeController = TextEditingController();
  final List<Map<String, dynamic>> _games = [
    {'title': 'Tic Tac Toe', 'type': 'tictactoe', 'icon': Icons.grid_3x3, 'color': Colors.blue},
    {'title': 'Rock Paper Scissors', 'type': 'rps', 'icon': Icons.cut, 'color': Colors.pink},
    {'title': 'Connect 4', 'type': 'connect4', 'icon': Icons.table_rows, 'color': Colors.yellow},
    {'title': 'Gomoku', 'type': 'gomoku', 'icon': Icons.grid_on, 'color': Colors.orange},
    {'title': 'Tap Attack', 'type': 'tapattack', 'icon': Icons.touch_app, 'color': Colors.redAccent},
    {'title': 'Memory', 'type': 'memory', 'icon': Icons.style, 'color': Colors.teal},
    {'title': 'Guess Number', 'type': 'guessnum', 'icon': Icons.question_mark, 'color': Colors.purple},
    {'title': 'Hangman', 'type': 'hangman', 'icon': Icons.abc, 'color': Colors.indigo},
    {'title': 'Math Sprint', 'type': 'math', 'icon': Icons.calculate, 'color': Colors.green},
    {'title': 'Reaction', 'type': 'reaction', 'icon': Icons.flash_on, 'color': Colors.cyan},
  ];

  void _create(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String code = String.fromCharCodes(Iterable.generate(4, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(32))));
    await FirebaseFirestore.instance.collection('games').doc(code).set({
      'type': type, 'host': user.uid, 'hostName': user.displayName ?? 'Anon',
      'status': 'waiting', 'created': FieldValue.serverTimestamp(), 'winner': null,
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16), color: Colors.grey[900],
                child: Row(children: [
                  Expanded(child: TextField(controller: _codeController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "ENTER CODE", filled: true, fillColor: Colors.black))),
                  const SizedBox(width: 10),
                  ElevatedButton(onPressed: _join, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("JOIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))
                ]),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, childAspectRatio: 1.0, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: _games.length,
                  itemBuilder: (c, i) => GestureDetector(
                    onTap: () => _create(_games[i]['type']),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15), border: Border.all(color: _games[i]['color'])),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_games[i]['icon'], size: 40, color: _games[i]['color']), const SizedBox(height: 10), Text(_games[i]['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. GAME SCAFFOLD
// =============================================================================

class GameScaffold extends StatefulWidget {
  final String title;
  final String gameId;
  final Widget gameBoard;
  final String rules;
  final bool isGameOver;
  final bool amIWinner;
  final VoidCallback? onPlayAgain;

  const GameScaffold({super.key, required this.title, required this.gameId, required this.gameBoard, required this.rules, this.isGameOver=false, this.amIWinner=false, this.onPlayAgain});
  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  bool _showChat = false;
  late ConfettiController _confettiCtrl;
  final TextEditingController _chatCtrl = TextEditingController();
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() { super.initState(); _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3)); }
  @override
  void didUpdateWidget(GameScaffold old) {
    super.didUpdateWidget(old);
    if (widget.isGameOver && !old.isGameOver && widget.amIWinner) _confettiCtrl.play();
  }
  @override
  void dispose() { _confettiCtrl.dispose(); super.dispose(); }

  void _sendMessage() {
    if (_chatCtrl.text.trim().isEmpty || widget.gameId == 'offline') return;
    FirebaseFirestore.instance.collection('games').doc(widget.gameId).collection('messages').add({
      'text': _chatCtrl.text.trim(), 'sender': _user?.displayName ?? 'Anon', 'uid': _user?.uid, 'time': FieldValue.serverTimestamp(),
    });
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.grey[900], foregroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.help_outline, color: Colors.cyanAccent), onPressed: () => showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: Colors.grey[900], title: const Text("RULES", style: TextStyle(color: Colors.cyanAccent)), content: Text(widget.rules, style: const TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]))),
        if(widget.gameId != 'offline') IconButton(icon: Icon(_showChat ? Icons.chat_bubble : Icons.chat_bubble_outline), onPressed: () => setState(() => _showChat = !_showChat))
      ]),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Column(children: [
            Expanded(flex: 2, child: widget.gameBoard),
            if(_showChat) Expanded(flex: 1, child: Container(color: Colors.grey[900], child: Column(children: [
              Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('games').doc(widget.gameId).collection('messages').orderBy('time', descending: true).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const SizedBox(); return ListView.builder(reverse: true, itemCount: snapshot.data!.docs.length, itemBuilder: (c, i) { var d = snapshot.data!.docs[i]; return ListTile(title: Text(d['text'], style: const TextStyle(color: Colors.white)), subtitle: Text(d['sender'], style: const TextStyle(color: Colors.grey, fontSize: 10))); }); })),
              Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [Expanded(child: TextField(controller: _chatCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Chat...", filled: true, fillColor: Colors.black))), IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: _sendMessage)]))
            ])))
          ]))),
          Align(alignment: Alignment.topCenter, child: ConfettiWidget(confettiController: _confettiCtrl, blastDirectionality: BlastDirectionality.explosive)),
          if (widget.isGameOver) Container(color: Colors.black87, alignment: Alignment.center, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.amIWinner ? Icons.emoji_events : Icons.close, size: 80, color: widget.amIWinner ? Colors.yellow : Colors.red),
            Text(widget.amIWinner ? "VICTORY" : "DEFEAT", style: TextStyle(color: widget.amIWinner ? Colors.yellow : Colors.red, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("EXIT")),
              const SizedBox(width: 20),
              if (widget.onPlayAgain != null) ElevatedButton(onPressed: widget.onPlayAgain, child: const Text("REMATCH"))
            ])
          ]))
        ],
      ),
    );
  }
}

// =============================================================================
// 3. ONLINE LOGIC
// =============================================================================

class OnlineGameScreen extends StatelessWidget {
  final String gameId; final String gameType;
  const OnlineGameScreen({super.key, required this.gameId, required this.gameType});

  @override
  Widget build(BuildContext context) {
    String myId = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('games').doc(gameId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
        var data = snapshot.data!.data() as Map<String, dynamic>;

        if (data['status'] == 'waiting') return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text("LOBBY"), backgroundColor: Colors.black), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(gameId, style: const TextStyle(fontSize: 60, color: Colors.cyanAccent)), const Text("Waiting for player...", style: TextStyle(color: Colors.white54))])));

        if (data['winner'] != null && data['recorded'] != true && data['host'] == myId) {
           FirebaseFirestore.instance.collection('games').doc(gameId).update({'recorded': true});
           if (data['squadId'] != null) FirebaseFirestore.instance.collection('squads').doc(data['squadId']).collection('history').add({'winnerName': data['winner'] == data['host'] ? data['hostName'] : data['player2Name'], 'gameType': gameType, 'timestamp': FieldValue.serverTimestamp()});
           FirebaseFirestore.instance.collection('users').doc(data['winner']).update({'wins': FieldValue.increment(1), 'xp': FieldValue.increment(100), 'aura': FieldValue.increment(50)});
        }

        bool isOver = data['winner'] != null;
        bool amWin = data['winner'] == myId;
        VoidCallback rematch = () => FirebaseFirestore.instance.collection('games').doc(gameId).update({'winner': null, 'state': _getInitialState(gameType, data['host']), 'recorded': false});

        Widget board = const Center(child: Text("Loading..."));
        if(gameType == 'tictactoe') board = TicTacToeBoard(data: data, gameId: gameId, myId: myId);
        if(gameType == 'rps') board = RPSBoard(data: data, gameId: gameId, myId: myId);
        if(gameType == 'connect4') board = Connect4Board(data: data, gameId: gameId, myId: myId);
        if(gameType == 'gomoku') board = GomokuBoard(data: data, gameId: gameId, myId: myId);
        if(gameType == 'tapattack') board = TapAttackBoard(data: data, gameId: gameId, myId: myId);
        if(gameType == 'memory') board = MemoryBoard(data: data, gameId: gameId, myId: myId);
        if(gameType == 'guessnum') board = GuessNumBoard(data: data, gameId: gameId, myId: myId);
        if(gameType == 'hangman') board = HangmanBoard(data: data, gameId: gameId, myId: myId);
        if(gameType == 'math') board = MathSprintBoard(data: data, gameId: gameId, myId: myId);
        if(gameType == 'reaction') board = ReactionTestBoard(data: data, gameId: gameId, myId: myId);

        return GameScaffold(title: gameType.toUpperCase(), gameId: gameId, gameBoard: board, rules: _getRules(gameType), isGameOver: isOver, amIWinner: amWin, onPlayAgain: isOver ? rematch : null);
      },
    );
  }
}

// 4. HELPERS
String _getRules(String type) {
  if(type == 'guessnum') return "Host sets a number. Joiner guesses. Watch the hints!";
  if(type == 'hangman') return "Host sets a word. Joiner guesses letters.";
  if(type == 'math') return "First to 5 points wins!";
  return "Win to earn Aura!";
}

Map<String, dynamic> _getInitialState(String type, String uid) {
  if(type == 'tictactoe') return {'board': List.filled(9, ''), 'turn': uid};
  if(type == 'rps') return {'p1Move': '', 'p2Move': ''};
  if(type == 'connect4') return {'board': List.filled(42, ''), 'turn': uid};
  if(type == 'gomoku') return {'board': List.filled(100, ''), 'turn': uid};
  if(type == 'tapattack') return {'board': List.filled(25, ''), 'scores': {uid: 0}, 'startTime': 0};
  if(type == 'memory') return {'revealed': List.filled(16, false), 'turn': uid};
  if(type == 'guessnum') return {'target': -1, 'guesses': [], 'host': uid};
  if(type == 'hangman') return {'word': '', 'guesses': [], 'lives': 6, 'host': uid};
  if(type == 'math') return {'p1Score': 0, 'p2Score': 0, 'question': '${Random().nextInt(10)} + ${Random().nextInt(10)}', 'answer': 0};
  if(type == 'reaction') return {'triggerTime': 0};
  return {};
}

// 5. GAME BOARDS
class TicTacToeBoard extends StatelessWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const TicTacToeBoard({super.key, required this.data, required this.gameId, required this.myId});
  bool _checkWin(List b, String p) {
    List<List<int>> w = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    for(var l in w) { if(b[l[0]]==p && b[l[1]]==p && b[l[2]]==p) return true; }
    return false;
  }
  @override Widget build(BuildContext context) {
    List b = data['state']['board'];
    return GridView.builder(padding: const EdgeInsets.all(20), itemCount: 9, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10), itemBuilder: (c, i) => GestureDetector(onTap: () { if (data['winner'] == null && data['state']['turn'] == myId && b[i] == '') { List nb = List.from(b); nb[i] = (myId == data['host']) ? 'X' : 'O'; String? w; if (_checkWin(nb, nb[i])) w = myId; else if (!nb.contains('')) w = 'draw'; FirebaseFirestore.instance.collection('games').doc(gameId).update({'state.board': nb, 'state.turn': data['state']['turn'] == data['host'] ? data['player2'] : data['host'], 'winner': w}); } }, child: Container(color: Colors.white10, child: Center(child: Text(b[i], style: const TextStyle(fontSize: 40, color: Colors.cyanAccent))))));
  }
}

class RPSBoard extends StatelessWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const RPSBoard({super.key, required this.data, required this.gameId, required this.myId});
  @override Widget build(BuildContext context) {
    bool hasMoved = (myId == data['host'] ? data['state']['p1Move'] : data['state']['p2Move']) != '';
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(hasMoved ? "You picked! Waiting..." : "Make your move!", style: const TextStyle(color: Colors.white)),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ["🪨","📄","✂️"].map((e) => ElevatedButton(onPressed: () {
        if(data['winner'] != null || hasMoved) return;
        String field = (myId == data['host'] ? 'state.p1Move' : 'state.p2Move');
        FirebaseFirestore.instance.collection('games').doc(gameId).update({field: e}).then((_) async {
          var s = (await FirebaseFirestore.instance.collection('games').doc(gameId).get()).data()!['state'];
          if(s['p1Move'] != '' && s['p2Move'] != '') {
            String p1 = s['p1Move']; String p2 = s['p2Move'];
            String w = 'draw';
            if(p1!=p2) { if((p1=='🪨'&&p2=='✂️') || (p1=='📄'&&p2=='🪨') || (p1=='✂️'&&p2=='📄')) w = data['host']; else w = data['player2']; }
            FirebaseFirestore.instance.collection('games').doc(gameId).update({'winner': w});
          }
        });
      }, child: Text(e, style: const TextStyle(fontSize: 30)))).toList())
    ]);
  }
}

class Connect4Board extends StatelessWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const Connect4Board({super.key, required this.data, required this.gameId, required this.myId});
  bool _checkWin(List b, String p) {
    for(int r=0;r<6;r++) { for(int c=0;c<4;c++) { if(b[r*7+c]==p&&b[r*7+c+1]==p&&b[r*7+c+2]==p&&b[r*7+c+3]==p) return true; }}
    for(int r=0;r<3;r++) { for(int c=0;c<7;c++) { if(b[r*7+c]==p&&b[(r+1)*7+c]==p&&b[(r+2)*7+c]==p&&b[(r+3)*7+c]==p) return true; }}
    return false;
  }
  @override Widget build(BuildContext context) {
    List b = data['state']['board'];
    return GridView.builder(padding: const EdgeInsets.all(10), itemCount: 42, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemBuilder: (c, i) => GestureDetector(onTap: () { if (data['winner'] == null && data['state']['turn'] == myId) { int col = i % 7; int t = -1; for(int r=5; r>=0; r--) { if(b[r*7+col]=='') {t=r*7+col; break;} } if(t!=-1) { List nb = List.from(b); nb[t] = (myId == data['host']) ? 'R' : 'Y'; String? w; if(_checkWin(nb, nb[t])) w = myId; FirebaseFirestore.instance.collection('games').doc(gameId).update({'state.board': nb, 'state.turn': data['state']['turn'] == data['host'] ? data['player2'] : data['host'], 'winner': w}); } } }, child: CircleAvatar(backgroundColor: b[i] == '' ? Colors.grey : (b[i]=='R' ? Colors.red : Colors.yellow))));
  }
}

class GomokuBoard extends StatelessWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const GomokuBoard({super.key, required this.data, required this.gameId, required this.myId});
  bool _checkWin(List b, String p) {
    for(int i=0; i<100; i++) {
       int r=i~/10, c=i%10;
       if(c<=5 && b[i]==p&&b[i+1]==p&&b[i+2]==p&&b[i+3]==p&&b[i+4]==p) return true;
       if(r<=5 && b[i]==p&&b[i+10]==p&&b[i+20]==p&&b[i+30]==p&&b[i+40]==p) return true;
    }
    return false;
  }
  @override Widget build(BuildContext context) {
    List b = data['state']['board'];
    return GridView.builder(itemCount: 100, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10), itemBuilder: (c, i) => GestureDetector(onTap: () { if(data['winner'] == null && b[i] == '' && data['state']['turn'] == myId) { List nb = List.from(b); nb[i] = (myId==data['host']?'B':'W'); String? w; if(_checkWin(nb, nb[i])) w=myId; FirebaseFirestore.instance.collection('games').doc(gameId).update({'state.board': nb, 'state.turn': data['state']['turn'] == data['host'] ? data['player2'] : data['host'], 'winner': w}); } }, child: Container(margin: const EdgeInsets.all(1), color: Colors.brown, child: b[i] != '' ? CircleAvatar(backgroundColor: b[i]=='B'?Colors.black:Colors.white) : null)));
  }
}

class TapAttackBoard extends StatelessWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const TapAttackBoard({super.key, required this.data, required this.gameId, required this.myId});
  @override Widget build(BuildContext context) {
    List b = data['state']['board'];
    return GridView.builder(itemCount: 25, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5), itemBuilder: (c, i) => GestureDetector(onTap: () { if(data['winner'] == null) { List nb = List.from(b); nb[i] = (myId == data['host']) ? 'A' : 'B'; int scoreA = nb.where((e)=>e=='A').length; int scoreB = nb.where((e)=>e=='B').length; if(!nb.contains('')) FirebaseFirestore.instance.collection('games').doc(gameId).update({'state.board': nb, 'winner': scoreA > scoreB ? data['host'] : data['player2']}); else FirebaseFirestore.instance.collection('games').doc(gameId).update({'state.board': nb}); } }, child: Container(margin: const EdgeInsets.all(2), color: b[i] == '' ? Colors.grey : (b[i] == 'A' ? Colors.cyan : Colors.purple))));
  }
}

class MemoryBoard extends StatelessWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const MemoryBoard({super.key, required this.data, required this.gameId, required this.myId});
  @override Widget build(BuildContext context) {
    List revealed = data['state']['revealed']; 
    return GridView.builder(itemCount: 16, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4), itemBuilder: (c, i) => GestureDetector(onTap: () { if (!revealed[i]) { List nr = List.from(revealed); nr[i] = true; FirebaseFirestore.instance.collection('games').doc(gameId).update({'state.revealed': nr}); if(!nr.contains(false)) FirebaseFirestore.instance.collection('games').doc(gameId).update({'winner': myId}); } }, child: Card(color: revealed[i] ? Colors.white : Colors.blue, child: const Center(child: Text("?")))));
  }
}

// =============================================================================
// UPDATED GUESS NUMBER BOARD
// =============================================================================

class GuessNumBoard extends StatefulWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const GuessNumBoard({super.key, required this.data, required this.gameId, required this.myId});
  @override State<GuessNumBoard> createState() => _GuessNumBoardState();
}

class _GuessNumBoardState extends State<GuessNumBoard> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    int target = widget.data['state']['target'];
    bool amHost = widget.myId == widget.data['host'];
    bool isGameActive = widget.data['winner'] == null;

    // 1. HOST VIEW: SET THE NUMBER
    if (target == -1) {
      return Center(
        child: amHost 
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open, size: 50, color: Colors.purpleAccent),
              const SizedBox(height: 10),
              const Text("Set the Secret Number (1-100)", style: TextStyle(color: Colors.white, fontSize: 18)),
              Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text("LOCK IT IN"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () {
                  int? val = int.tryParse(_ctrl.text);
                  if (val != null && val > 0 && val <= 100) {
                    FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({'state.target': val});
                  }
                }
              )
            ],
          )
        : const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.purple),
              SizedBox(height: 20),
              Text("Host is choosing a number...", style: TextStyle(color: Colors.white54)),
            ],
          ),
      );
    }

    // 2. GAME VIEW: GUESSING LIST AND INPUT
    List guesses = List.from(widget.data['state']['guesses'] ?? []);
    
    return Column(
      children: [
        // History List
        Expanded(
          child: guesses.isEmpty 
          ? const Center(child: Text("No guesses yet. Start now!", style: TextStyle(color: Colors.white30)))
          : ListView.builder(
              itemCount: guesses.length,
              reverse: true, // Show newest at bottom (or top depending on logic, here we stick to normal flow but reversed index)
              itemBuilder: (context, index) {
                 // To show newest at TOP, we reverse index:
                 int i = guesses.length - 1 - index;
                 var g = guesses[i];
                 bool isHigh = g['res'] == 'HIGH' || g['res'].toString().contains('HIGH');
                 bool isWin = g['res'] == 'CORRECT';
                 Color c = isWin ? Colors.green : (isHigh ? Colors.orange : Colors.blue);
                 
                 return Card(
                   color: Colors.grey[900],
                   margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                   child: ListTile(
                     leading: CircleAvatar(backgroundColor: c.withOpacity(0.2), child: Text("${g['val']}", style: TextStyle(color: c, fontWeight: FontWeight.bold))),
                     title: Text(isWin ? "CRACKED THE CODE!" : (isHigh ? "Too High 🔽" : "Too Low 🔼"), style: TextStyle(color: c, fontWeight: FontWeight.bold)),
                     trailing: isWin ? const Icon(Icons.star, color: Colors.yellow) : null,
                   ),
                 );
              },
            ),
        ),
        
        // Input Area (Only for Joiner)
        if (!amHost && isGameActive)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Enter 1-100...",
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                  onPressed: () {
                    int? g = int.tryParse(_ctrl.text);
                    if (g == null) return;
                    
                    String r = g == target ? "CORRECT" : (g < target ? "LOW" : "HIGH");
                    
                    FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
                      'state.guesses': FieldValue.arrayUnion([{'val': g, 'res': r}]),
                      'winner': g == target ? widget.myId : null
                    });
                    
                    _ctrl.clear();
                  },
                  child: const Text("GUESS")
                )
              ],
            ),
          ),
          
        if(amHost && isGameActive)
           Padding(
             padding: const EdgeInsets.all(20),
             child: Text("Target: $target\nWaiting for them to guess...", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
           )
      ],
    );
  }
}

class HangmanBoard extends StatefulWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const HangmanBoard({super.key, required this.data, required this.gameId, required this.myId});
  @override State<HangmanBoard> createState() => _HangmanBoardState();
}
class _HangmanBoardState extends State<HangmanBoard> {
  final _ctrl = TextEditingController();
  @override Widget build(BuildContext context) {
    String word = widget.data['state']['word'];
    bool amHost = widget.myId == widget.data['host'];
    if(word == '') return Center(child: amHost ? Column(children: [const Text("Set Word", style: TextStyle(color: Colors.white)), TextField(controller: _ctrl, style: const TextStyle(color: Colors.white)), ElevatedButton(onPressed: () => FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({'state.word': _ctrl.text.toUpperCase()}), child: const Text("SET"))]) : const Text("Waiting...", style: TextStyle(color: Colors.white)));
    
    List guesses = widget.data['state']['guesses'];
    String display = word.split('').map((e) => guesses.contains(e) ? e : "_").join(" ");
    return Column(children: [
      Text(display, style: const TextStyle(color: Colors.cyanAccent, fontSize: 40, letterSpacing: 5)),
      const SizedBox(height: 20),
      if(!amHost) Wrap(children: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split('').map((e) => Padding(padding: const EdgeInsets.all(2), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: guesses.contains(e) ? Colors.grey : Colors.blue), onPressed: guesses.contains(e) ? null : () {
        List ng = List.from(guesses)..add(e);
        bool won = word.split('').every((c) => ng.contains(c));
        FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({'state.guesses': ng, 'winner': won ? widget.myId : null});
      }, child: Text(e)))).toList())
    ]);
  }
}

class MathSprintBoard extends StatefulWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const MathSprintBoard({super.key, required this.data, required this.gameId, required this.myId});
  @override State<MathSprintBoard> createState() => _MathSprintBoardState();
}
class _MathSprintBoardState extends State<MathSprintBoard> {
  final _ctrl = TextEditingController();
  @override Widget build(BuildContext context) {
    int q1 = int.parse(widget.data['state']['question'].split('+')[0].trim());
    int q2 = int.parse(widget.data['state']['question'].split('+')[1].trim());
    int ans = q1 + q2;
    int myScore = widget.myId == widget.data['host'] ? widget.data['state']['p1Score'] : widget.data['state']['p2Score'];
    
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Score: $myScore", style: const TextStyle(color: Colors.cyanAccent)),
      Text("${widget.data['state']['question']}", style: const TextStyle(color: Colors.white, fontSize: 40)),
      TextField(controller: _ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
      ElevatedButton(onPressed: () {
        if(int.parse(_ctrl.text) == ans) {
          String field = widget.myId == widget.data['host'] ? 'state.p1Score' : 'state.p2Score';
          int newScore = myScore + 1;
          FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
            field: newScore,
            'state.question': '${Random().nextInt(20)} + ${Random().nextInt(20)}',
            'winner': newScore >= 5 ? widget.myId : null
          });
          _ctrl.clear();
        }
      }, child: const Text("SUBMIT"))
    ]);
  }
}

class ReactionTestBoard extends StatelessWidget {
  final Map<String, dynamic> data; final String gameId; final String myId;
  const ReactionTestBoard({super.key, required this.data, required this.gameId, required this.myId});
  @override Widget build(BuildContext context) {
    bool active = DateTime.now().millisecondsSinceEpoch > (data['state']['triggerTime'] ?? 0);
    if (data['state']['triggerTime'] == 0 && myId == data['host']) {
       Future.delayed(Duration(seconds: Random().nextInt(3) + 2), () => FirebaseFirestore.instance.collection('games').doc(gameId).update({'state.triggerTime': DateTime.now().millisecondsSinceEpoch}));
    }
    return GestureDetector(
      onTap: () { if(active && data['winner'] == null) FirebaseFirestore.instance.collection('games').doc(gameId).update({'winner': myId}); },
      child: Container(color: active ? Colors.green : Colors.red, child: Center(child: Text(active ? "TAP!" : "WAIT...", style: const TextStyle(fontSize: 40))))
    );
  }
}

class LocalGameScreen extends StatelessWidget {
  final String gameType; final String title;
  const LocalGameScreen({super.key, required this.gameType, required this.title});
  @override Widget build(BuildContext context) => GameScaffold(title: title, gameId: 'offline', rules: "Training", gameBoard: const Center(child: Text("AI Mode", style: TextStyle(color: Colors.white))));
}