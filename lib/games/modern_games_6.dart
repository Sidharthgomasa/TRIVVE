import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

// =============================================================================
// 1. NEON BATTLESHIP (Radar Hunt)
// =============================================================================
class BattleshipGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const BattleshipGameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    // 0=Water, 1=Ship(Hidden), 2=Hit, 3=Miss
    // In local AI mode, 'p1Grid' is actually the ENEMY grid we are attacking.
    List grid = data['state']['p1Grid'] ?? List.filled(25, 0); 
    String turn = data['state']['turn'];
    bool isMyTurn = turn == controller.myId;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Header
        Text(
          isMyTurn ? "SCANNING SECTOR..." : "ENEMY FIRING...",
          style: TextStyle(
            color: isMyTurn ? Colors.greenAccent : Colors.redAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2
          ),
        ),
        const SizedBox(height: 20),

        // Radar Screen
        Container(
          width: 350, height: 350,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 4),
            boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 30)],
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 25,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, crossAxisSpacing: 5, mainAxisSpacing: 5
            ),
            itemBuilder: (context, index) {
              int cell = grid[index]; // 0=Water, 1=Ship, 2=Hit, 3=Miss
              bool isHit = cell == 2;
              bool isMiss = cell == 3;
              bool isRevealed = isHit || isMiss;

              return GestureDetector(
                onTap: () => _handleTap(index, grid, isMyTurn),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isRevealed 
                        ? (isHit ? Colors.red.withOpacity(0.8) : Colors.grey.withOpacity(0.3)) 
                        : Colors.greenAccent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isRevealed ? Colors.transparent : Colors.greenAccent.withOpacity(0.3)
                    )
                  ),
                  child: Center(
                    child: isRevealed 
                      ? Icon(
                          isHit ? Icons.local_fire_department : Icons.close, 
                          color: isHit ? Colors.yellow : Colors.grey,
                          size: 20,
                        ) 
                      : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleTap(int index, List grid, bool isMyTurn) {
    if (data['winner'] != null || !isMyTurn) return;
    
    int cell = grid[index];
    if (cell == 2 || cell == 3) return; // Already shot

    // Logic: 0 -> 3 (Miss), 1 -> 2 (Hit)
    List newGrid = List.from(grid);
    if (cell == 1) {
      newGrid[index] = 2; // Hit!
    } else {
      newGrid[index] = 3; // Miss
    }

    // Check Win (Are any '1's left?)
    bool won = !newGrid.contains(1);

    controller.updateGame({
      'p1Grid': newGrid,
      'turn': (newGrid[index] == 2) ? controller.myId : 'AI' // Bonus turn on hit
    }, mergeWinner: won ? controller.myId : null);
  }
}

// =============================================================================
// 2. DOTS & BOXES (Neon Circuit)
// =============================================================================
class DotsAndBoxesGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const DotsAndBoxesGameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    // 40 lines for a 4x4 grid of dots (3x3 boxes)
    // Horizontal: 3 rows * 4 cols = 12? No.
    // 4x4 Grid of Dots = 3x3 Boxes.
    // Horizontal Lines: 4 rows of 3 = 12 lines.
    // Vertical Lines: 3 rows of 4 = 12 lines. 
    // Total 24 lines.
    // List state: 0=Empty, 1=P1(Blue), 2=AI(Pink)
    List lines = data['state']['lines'] ?? List.filled(24, 0); 
    bool isMyTurn = data['state']['turn'] == controller.myId;

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12)
          ),
          child: CustomPaint(
            painter: DotsBoardPainter(lines),
            child: Stack(
              children: _buildClickableZones(lines, isMyTurn),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildClickableZones(List lines, bool isMyTurn) {
    List<Widget> zones = [];
    double step = 80.0; // Spacing estimate
    // We map simplified zones for tapping.
    // Real implementation requires precise LayoutBuilder calc.
    // For V1, we use a grid overlay.
    
    int hIndex = 0;
    int vIndex = 12;

    // Horizontal Click Zones
    for(int r=0; r<4; r++) {
      for(int c=0; c<3; c++) {
        int idx = hIndex++;
        zones.add(Positioned(
          left: c * step + 20, top: r * step - 10,
          width: step - 20, height: 40,
          child: GestureDetector(
            onTap: () => _lineClick(idx, lines, isMyTurn),
            child: Container(color: Colors.transparent), // Invisible Hitbox
          ),
        ));
      }
    }
    
    // Vertical Click Zones
    for(int r=0; r<3; r++) {
      for(int c=0; c<4; c++) {
        int idx = vIndex++;
        zones.add(Positioned(
          left: c * step - 10, top: r * step + 20,
          width: 40, height: step - 20,
          child: GestureDetector(
            onTap: () => _lineClick(idx, lines, isMyTurn),
            child: Container(color: Colors.transparent),
          ),
        ));
      }
    }
    return zones;
  }

  void _lineClick(int index, List lines, bool isMyTurn) {
    if (data['winner'] != null || !isMyTurn || lines[index] != 0) return;
    
    List newLines = List.from(lines);
    newLines[index] = 1; // P1 Color

    // Logic: Did we close a box?
    // Simplified: Check neighbors. If box closed, keep turn.
    // For V1, simple pass turn.
    controller.updateGame({'lines': newLines, 'turn': 'AI'});
  }
}

class DotsBoardPainter extends CustomPainter {
  final List lines;
  DotsBoardPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    Paint dotPaint = Paint()..color = Colors.white..strokeWidth = 5..strokeCap = StrokeCap.round;
    Paint linePaint = Paint()..strokeWidth = 4..style = PaintingStyle.stroke;
    
    double step = 80.0; // Fixed spacing for V1
    
    // Draw Dots
    for(int r=0; r<4; r++) {
      for(int c=0; c<4; c++) {
        canvas.drawCircle(Offset(c*step + 10, r*step + 10), 4, dotPaint);
      }
    }

    // Draw Lines
    int hIdx = 0;
    for(int r=0; r<4; r++) {
      for(int c=0; c<3; c++) {
        int val = lines[hIdx++];
        if(val != 0) {
          linePaint.color = val==1 ? Colors.cyanAccent : Colors.pinkAccent;
          canvas.drawLine(Offset(c*step+10, r*step+10), Offset((c+1)*step+10, r*step+10), linePaint);
        }
      }
    }
    int vIdx = 12;
    for(int r=0; r<3; r++) {
      for(int c=0; c<4; c++) {
        int val = lines[vIdx++];
        if(val != 0) {
          linePaint.color = val==1 ? Colors.cyanAccent : Colors.pinkAccent;
          canvas.drawLine(Offset(c*step+10, r*step+10), Offset(c*step+10, (r+1)*step+10), linePaint);
        }
      }
    }
  }
  @override bool shouldRepaint(old) => true;
}

// =============================================================================
// 3. TRIVIA (Cyber Quiz)
// =============================================================================
class TriviaGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const TriviaGameUI({super.key, required this.data, required this.controller});

  @override
  State<TriviaGameUI> createState() => _TriviaGameUIState();
}

class _TriviaGameUIState extends State<TriviaGameUI> {
  // Hardcoded mini-db for V1
  final List<Map<String, dynamic>> _questions = [
    {'q': 'What is the capital of France?', 'a': 'Paris', 'opts': ['London', 'Berlin', 'Paris', 'Madrid']},
    {'q': 'Which language runs Flutter?', 'a': 'Dart', 'opts': ['Java', 'Python', 'Dart', 'C++']},
    {'q': 'Fastest land animal?', 'a': 'Cheetah', 'opts': ['Lion', 'Cheetah', 'Horse', 'Eagle']},
    {'q': 'Planet closest to Sun?', 'a': 'Mercury', 'opts': ['Venus', 'Mars', 'Mercury', 'Earth']},
  ];

  void _answer(String ans) {
    if (widget.data['winner'] != null) return;
    
    int qIdx = widget.data['state']['q'] ?? 0;
    int score = widget.data['state']['p1Score'] ?? 0;
    
    if (ans == _questions[qIdx]['a']) score += 10;

    if (qIdx + 1 >= _questions.length) {
      widget.controller.updateGame({'p1Score': score}, mergeWinner: widget.controller.myId);
    } else {
      widget.controller.updateGame({'q': qIdx + 1, 'p1Score': score});
    }
  }

  @override
  Widget build(BuildContext context) {
    int qIdx = widget.data['state']['q'] ?? 0;
    if (qIdx >= _questions.length) return const Center(child: Text("QUIZ COMPLETE", style: TextStyle(color: Colors.white)));

    var q = _questions[qIdx];
    int score = widget.data['state']['p1Score'] ?? 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("SCORE: $score", style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.1),
            border: Border.all(color: Colors.blueAccent),
            borderRadius: BorderRadius.circular(15)
          ),
          child: Text(
            q['q'],
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        
        const SizedBox(height: 40),
        
        ...List.generate(4, (i) {
          String opt = q['opts'][i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _answer(opt),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[900],
                  side: const BorderSide(color: Colors.white24)
                ),
                child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
          );
        })
      ],
    );
  }
}