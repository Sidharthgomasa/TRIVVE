import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:trivve/games/core_engine.dart'; 

// =============================================================================
// RESTORED GAME BOARDS
// =============================================================================

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
    return GridView.builder(padding: const EdgeInsets.all(10), itemCount: 42, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemBuilder: (c, i) => GestureDetector(onTap: () { if (data['winner'] == null && data['state']['turn'] == ctrl.myId) { int col = i % 7; int t = -1; for(int r=5; r>=0; r--) { if(b[r*7+col]=='') {t=r*7+col; break;} } if(t!=-1) { List nb = List.from(b); nb[t] = (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? 'R' : 'Y'; ctrl.updateGame({'board': nb, 'turn': (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? (data['player2'] ?? 'AI') : data['host']}, mergeWinner: null); } } }, child: CircleAvatar(backgroundColor: b[i] == '' ? Colors.grey[800] : (b[i]=='R' ? Colors.red : Colors.yellow))));
  }
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
  void _resolve(String m1, String m2) { String w = 'draw'; if(m1!=m2) { if((m1=='🪨'&&m2=='✂️')||(m1=='📄'&&m2=='🪨')||(m1=='✂️'&&m2=='📄')) { w = data['host']; } else { w = data['player2'] ?? 'AI'; } } ctrl.updateGame({}, mergeWinner: w); }
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
      if(head==food) { score+=10; food=Random().nextInt(400); } else { snake.removeLast(); }
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

// --- PLACEHOLDERS (For games you defined but hadn't finished logic for) ---
class DotsAndBoxesBoard extends StatelessWidget { final Map data; final GameController ctrl; const DotsAndBoxesBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Dots & Boxes (Coming Soon)", style: TextStyle(color: Colors.white))); }
class BattleshipBoard extends StatelessWidget { final Map data; final GameController ctrl; const BattleshipBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Battleship (Coming Soon)", style: TextStyle(color: Colors.white))); }
class TriviaBoard extends StatelessWidget { final Map data; final GameController ctrl; const TriviaBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Trivia (Coming Soon)", style: TextStyle(color: Colors.white))); }
class TyperBoard extends StatelessWidget { final Map data; final GameController ctrl; const TyperBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Typer (Coming Soon)", style: TextStyle(color: Colors.white))); }
class TapAttackBoard extends StatelessWidget { final Map data; final GameController ctrl; const TapAttackBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Tap Attack (Coming Soon)", style: TextStyle(color: Colors.white))); }
class MemoryBoard extends StatelessWidget { final Map data; final GameController ctrl; const MemoryBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Memory (Coming Soon)", style: TextStyle(color: Colors.white))); }
class HangmanBoard extends StatelessWidget { final Map data; final GameController ctrl; const HangmanBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Hangman (Coming Soon)", style: TextStyle(color: Colors.white))); }
class MathSprintBoard extends StatelessWidget { final Map data; final GameController ctrl; const MathSprintBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Math Sprint (Coming Soon)", style: TextStyle(color: Colors.white))); }
class ReactionTestBoard extends StatelessWidget { final Map data; final GameController ctrl; const ReactionTestBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Reaction Test (Coming Soon)", style: TextStyle(color: Colors.white))); }
class CarromBoard extends StatelessWidget { final Map data; final GameController ctrl; const CarromBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Carrom (Coming Soon)", style: TextStyle(color: Colors.white))); }
class LudoBoard extends StatelessWidget { final Map data; final GameController ctrl; const LudoBoard({super.key, required this.data, required this.ctrl}); @override Widget build(BuildContext context) => const Center(child: Text("Ludo (Coming Soon)", style: TextStyle(color: Colors.white))); }