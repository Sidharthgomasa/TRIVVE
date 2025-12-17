import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivve/games/core_engine.dart';
import 'package:trivve/games/arcade_wrapper.dart';
import 'package:trivve/games/ai_brain.dart';

// =============================================================================
// CLASSIC ARCADE SUITE - IMPLEMENTED & OPTIMIZED
// =============================================================================

class TicTacToeBoard extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const TicTacToeBoard({super.key, required this.data, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    List b = data['state']['board'];
    return ArcadeWrapper(
      title: "Tic-Tac-Toe",
      instructions: "Align 3 symbols horizontally, vertically, or diagonally. X always starts.",
      data: data, controller: ctrl,
      gameUI: GridView.builder(
        padding: const EdgeInsets.all(30),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemBuilder: (c, i) => GestureDetector(
          onTap: () {
            if (data['winner'] == null && data['state']['turn'] == ctrl.myId && b[i] == '') {
              List nb = List.from(b);
              nb[i] = (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? 'X' : 'O';
              String? w = AIBrain.getWinner('tictactoe', {'board': nb});
              ctrl.updateGame({'board': nb, 'turn': 'AI'}, mergeWinner: w);
            }
          },
          child: Container(
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(b[i], style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: b[i]=='X'?Colors.cyanAccent:Colors.pinkAccent))),
          ),
        ),
      ),
    );
  }
}

class Connect4Board extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const Connect4Board({super.key, required this.data, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    List b = data['state']['board'];
    return ArcadeWrapper(
      title: "Connect 4",
      instructions: "Drop discs into columns. First to align 4 of their color wins.",
      data: data, controller: ctrl,
      gameUI: GridView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: 42,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
        itemBuilder: (c, i) => GestureDetector(
          onTap: () {
            if (data['winner'] == null && data['state']['turn'] == ctrl.myId) {
              int col = i % 7;
              int target = -1;
              for(int r=5; r>=0; r--) { if(b[r*7+col]=='') {target=r*7+col; break;} }
              if(target != -1) {
                List nb = List.from(b);
                nb[target] = (ctrl.myId == data['host']) ? 'R' : 'Y';
                String? w = AIBrain.getWinner('connect4', {'board': nb});
                ctrl.updateGame({'board': nb, 'turn': 'AI'}, mergeWinner: w);
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: b[i] == '' ? Colors.white12 : (b[i] == 'R' ? Colors.redAccent : Colors.yellowAccent),
            ),
          ),
        ),
      ),
    );
  }
}

class MemoryBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const MemoryBoard({super.key, required this.data, required this.ctrl});
  @override State<MemoryBoard> createState() => _MemoryBoardState();
}

class _MemoryBoardState extends State<MemoryBoard> {
  @override
  Widget build(BuildContext context) {
    List grid = widget.data['state']['grid'] ?? [];
    List flipped = widget.data['state']['revealed'] ?? List.filled(16, false);

    return ArcadeWrapper(
      title: "Memory Match",
      instructions: "Find all matching pairs. Only 2 tiles can be flipped at a time.",
      data: widget.data, controller: widget.ctrl,
      gameUI: GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: grid.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemBuilder: (c, i) => GestureDetector(
          onTap: () {
            if (flipped[i] || widget.data['state']['turn'] != widget.ctrl.myId) return;
            List nextFlipped = List.from(flipped);
            nextFlipped[i] = true;
            widget.ctrl.updateGame({'revealed': nextFlipped, 'turn': 'AI'});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: flipped[i] ? Colors.purpleAccent : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(flipped[i] ? "${grid[i]}" : "?", style: const TextStyle(color: Colors.white, fontSize: 20))),
          ),
        ),
      ),
    );
  }
}

class BattleshipBoard extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const BattleshipBoard({super.key, required this.data, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    List grid = data['state']['p1Grid'] ?? List.filled(25, 0); // 0: Sea, 1: Ship, 2: Hit, 3: Miss
    bool isMyTurn = data['state']['turn'] == ctrl.myId;

    return ArcadeWrapper(
      title: "Battleship",
      instructions: "Find and sink the hidden enemy ships. Hit fire to keep your turn!",
      data: data, controller: ctrl,
      gameUI: GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 25,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 5, mainAxisSpacing: 5),
        itemBuilder: (c, i) => GestureDetector(
          onTap: () {
            if (!isMyTurn || grid[i] > 1) return;
            List nextGrid = List.from(grid);
            nextGrid[i] = (grid[i] == 1) ? 2 : 3;
            bool won = !nextGrid.contains(1);
            ctrl.updateGame({'p1Grid': nextGrid, 'turn': nextGrid[i] == 2 ? ctrl.myId : 'AI'}, mergeWinner: won ? ctrl.myId : null);
          },
          child: Container(
            decoration: BoxDecoration(
              color: grid[i] == 2 ? Colors.redAccent : (grid[i] == 3 ? Colors.white24 : Colors.blue.withOpacity(0.1)),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: Icon(
              grid[i] == 2 ? Icons.local_fire_department : (grid[i] == 3 ? Icons.close : null),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class WordleBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const WordleBoard({super.key, required this.data, required this.ctrl});
  @override State<WordleBoard> createState() => _WordleBoardState();
}

class _WordleBoardState extends State<WordleBoard> {
  final _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    List guesses = widget.data['state']['guesses'] ?? [];
    String target = widget.data['state']['word'] ?? "CODE";

    return ArcadeWrapper(
      title: "Wordle 4x4",
      instructions: "Guess the 4-letter word. Green = Right spot, Yellow = Wrong spot.",
      data: widget.data, controller: widget.ctrl,
      gameUI: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (c, i) {
                String g = i < guesses.length ? guesses[i] : "";
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (charIdx) {
                    Color col = Colors.white10;
                    if (g.isNotEmpty) {
                      if (g[charIdx] == target[charIdx]) {
                        col = Colors.green;
                      } else if (target.contains(g[charIdx])) col = Colors.orange;
                      else col = Colors.white24;
                    }
                    return Container(
                      width: 50, height: 50, margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text(g.length > charIdx ? g[charIdx] : "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
                    );
                  }),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _c, maxLength: 4, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, letterSpacing: 10),
              decoration: InputDecoration(
                hintText: "GUESS",
                suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: () {
                  if (_c.text.length == 4) {
                    List nextG = List.from(guesses)..add(_c.text.toUpperCase());
                    String? w = (_c.text.toUpperCase() == target) ? widget.ctrl.myId : null;
                    widget.ctrl.updateGame({'guesses': nextG}, mergeWinner: w);
                    _c.clear();
                  }
                }),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// =============================================================================
// REMAINING LEGACY BOARDS (RPS, SNAKE, SIMON, ETC) - ALL WRAPPED
// =============================================================================

class CyberSnakeBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const CyberSnakeBoard({super.key, required this.data, required this.ctrl});
  @override State<CyberSnakeBoard> createState() => _CyberSnakeBoardState();
}

class _CyberSnakeBoardState extends State<CyberSnakeBoard> {
  List<int> snake = [45, 44, 43]; int food = 100; String dir = 'down'; Timer? _timer; int score = 0;
  void _start() { snake=[45,44,43]; score=0; _timer?.cancel(); _timer = Timer.periodic(const Duration(milliseconds: 150), (t) => _tick()); }
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
  @override Widget build(BuildContext context) => ArcadeWrapper(
    title: "Cyber Snake",
    instructions: "Swipe to turn. Eat orbs to grow. Avoid the walls and your own tail.",
    data: widget.data, controller: widget.ctrl,
    gameUI: Column(children: [
      Text("CORE STABILITY: $score%", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
      Expanded(child: GestureDetector(
        onVerticalDragUpdate: (d) => dir = d.delta.dy < 0 ? 'up' : 'down',
        onHorizontalDragUpdate: (d) => dir = d.delta.dx < 0 ? 'left' : 'right',
        child: GridView.builder(itemCount: 400, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 20), itemBuilder: (c, i) => Container(margin: const EdgeInsets.all(0.5), decoration: BoxDecoration(color: snake.contains(i) ? Colors.greenAccent : (food==i ? Colors.redAccent : Colors.black), borderRadius: BorderRadius.circular(1))))
      )),
      ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("INITIALIZE", style: TextStyle(color: Colors.black)))
    ]),
  );
}

class CarromBoard extends StatefulWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const CarromBoard({super.key, required this.data, required this.ctrl});
  @override State<CarromBoard> createState() => _CarromBoardState();
}

class _CarromBoardState extends State<CarromBoard> {
  double strikerPos = 0.5;
  @override
  Widget build(BuildContext context) {
    return ArcadeWrapper(
      title: "Carrom Pro",
      instructions: "Position the striker and flick to pocket coins. Pocket the Queen for a massive bonus.",
      data: widget.data, controller: widget.ctrl,
      gameUI: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 300, height: 300,
            decoration: BoxDecoration(color: const Color(0xFFD7B899), border: Border.all(color: Colors.brown, width: 8), borderRadius: BorderRadius.circular(10)),
            child: Stack(
              children: [
                Positioned(left: strikerPos * 250, bottom: 20, child: const CircleAvatar(radius: 15, backgroundColor: Colors.white, child: CircleAvatar(radius: 12, backgroundColor: Colors.red))),
                const Center(child: CircleAvatar(radius: 40, backgroundColor: Colors.black12)),
              ],
            ),
          ),
          Slider(value: strikerPos, onChanged: (v) => setState(() => strikerPos = v)),
          const Text("STRIKER POSITION", style: TextStyle(color: Colors.white54))
        ],
      ),
    );
  }
}

class RPSBoard extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const RPSBoard({super.key, required this.data, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    String myField = (ctrl.myId == data['host'] || ctrl.myId == 'P1') ? 'p1Move' : 'p2Move';
    bool moved = data['state'][myField] != '';
    return ArcadeWrapper(
      title: "RPS Duel",
      instructions: "Rock > Scissor > Paper > Rock. Match to 10 points wins.",
      data: data, controller: ctrl,
      gameUI: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(moved ? "ENCRYPTING CHOICE..." : "SELECT WEAPON", style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, letterSpacing: 2)),
        const SizedBox(height: 50),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ["🪨","📄","✂️"].map((e) => InkWell(
          onTap: moved ? null : () => ctrl.updateGame({myField: e, 'turn': 'AI'}),
          child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(15)), child: Text(e, style: const TextStyle(fontSize: 50))),
        )).toList())
      ]),
    );
  }
}

class LudoBoard extends StatelessWidget {
  final Map<String, dynamic> data; final GameController ctrl;
  const LudoBoard({super.key, required this.data, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ArcadeWrapper(
      title: "Royal Ludo",
      instructions: "Roll a 6 to start. Get all 4 tokens to the home triangle to win.",
      data: data, controller: ctrl,
      gameUI: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
            child: CustomPaint(painter: LudoPainter()),
          ),
        ),
      ),
    );
  }
}

class LudoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double step = size.width / 15;
    final paint = Paint();
    // Simplified board representation
    paint.color = Colors.redAccent; canvas.drawRect(Rect.fromLTWH(0, 0, step*6, step*6), paint);
    paint.color = Colors.greenAccent; canvas.drawRect(Rect.fromLTWH(step*9, 0, step*6, step*6), paint);
    paint.color = Colors.yellowAccent; canvas.drawRect(Rect.fromLTWH(0, step*9, step*6, step*6), paint);
    paint.color = Colors.blueAccent; canvas.drawRect(Rect.fromLTWH(step*9, step*9, step*6, step*6), paint);
  }
  @override bool shouldRepaint(old) => false;
}