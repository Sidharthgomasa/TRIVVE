import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

// =============================================================================
// 1. NEON CONNECT 4 (With Animations)
// =============================================================================
class Connect4GameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const Connect4GameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    List board = data['state']['board']; // 42 slots
    String turn = data['state']['turn'];
    bool isMyTurn = turn == controller.myId;

    return Column(
      children: [
        // Status Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isMyTurn ? "YOUR MOVE" : "OPPONENT THINKING...",
                style: TextStyle(
                  color: isMyTurn ? Colors.greenAccent : Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: isMyTurn ? [const Shadow(color: Colors.greenAccent, blurRadius: 10)] : [],
                ),
              ),
            ],
          ),
        ),
        
        // The Grid
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 7 / 6,
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20)],
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 42,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _handleTap(index),
                      child: _buildCell(board[index]),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell(String cellValue) {
    Color color = Colors.transparent;
    bool hasValue = cellValue != '';
    
    if (cellValue == 'R') color = Colors.redAccent;
    if (cellValue == 'Y') color = Colors.yellowAccent;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        border: Border.all(color: Colors.grey[800]!),
        // ✅ FIXED: Removed 'inset: true'
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 2)], 
      ),
      child: hasValue 
        ? TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<double>(begin: -1.0, end: 0.0),
            curve: Curves.bounceOut,
            builder: (context, double val, child) {
              return Transform.translate(
                offset: Offset(0, val * 50), // Drop animation
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.6), blurRadius: 10, spreadRadius: 2),
                      // ✅ FIXED: Removed 'inset: true'
                      BoxShadow(color: Colors.white.withOpacity(0.4), offset: const Offset(-2, -2), blurRadius: 5)
                    ],
                  ),
                ),
              );
            },
          )
        : null,
    );
  }

  void _handleTap(int index) {
    if (data['winner'] != null || data['state']['turn'] != controller.myId) return;

    List board = List.from(data['state']['board']);
    int col = index % 7;
    
    // Find lowest empty spot
    int targetIndex = -1;
    for (int r = 5; r >= 0; r--) {
      if (board[r * 7 + col] == '') {
        targetIndex = r * 7 + col;
        break;
      }
    }

    if (targetIndex != -1) {
      String symbol = (controller.myId == data['host'] || controller.myId == 'P1') ? 'R' : 'Y';
      board[targetIndex] = symbol;
      
      String nextTurn = (controller.myId == data['host'] || controller.myId == 'P1') 
          ? (data['player2'] ?? 'AI') 
          : data['host'];

      controller.updateGame({
        'board': board,
        'turn': nextTurn
      }, mergeWinner: _checkWin(board, symbol) ? controller.myId : null);
    }
  }

  bool _checkWin(List b, String p) {
    // Basic logic is handled by AI/Game Engine usually
    return false; 
  }
}

// =============================================================================
// 2. CYBER RPS (Rock Paper Scissors)
// =============================================================================
class RPSGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const RPSGameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    String myField = (controller.myId == data['host'] || controller.myId == 'P1') ? 'p1Move' : 'p2Move';
    String oppField = (myField == 'p1Move') ? 'p2Move' : 'p1Move';
    
    String myMove = data['state'][myField] ?? '';
    String oppMove = data['state'][oppField] ?? '';
    
    bool bothPlayed = myMove.isNotEmpty && oppMove.isNotEmpty;
    bool iPlayed = myMove.isNotEmpty;

    if (bothPlayed && data['winner'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve(myMove, oppMove));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("OPPONENT", style: TextStyle(color: Colors.grey[600], letterSpacing: 2)),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 100, width: 100,
          decoration: BoxDecoration(
            color: bothPlayed ? Colors.redAccent.withOpacity(0.1) : Colors.grey[900],
            shape: BoxShape.circle,
            border: Border.all(color: bothPlayed ? Colors.redAccent : Colors.grey[800]!),
            boxShadow: bothPlayed ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 20)] : [],
          ),
          child: Center(
            child: Text(
              bothPlayed ? oppMove : (oppMove.isNotEmpty ? "Ready" : "?"),
              style: TextStyle(fontSize: 40, color: bothPlayed ? Colors.white : Colors.grey),
            ),
          ),
        ),

        const SizedBox(height: 50),
        if (bothPlayed) 
          Text(data['winner'] == controller.myId ? "YOU WIN" : (data['winner'] == 'draw' ? "DRAW" : "YOU LOSE"),
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: data['winner'] == controller.myId ? Colors.greenAccent : Colors.redAccent)),
        const SizedBox(height: 50),

        Text("YOUR PICK", style: TextStyle(color: Colors.grey[600], letterSpacing: 2)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ["🪨", "📄", "✂️"].map((move) {
            bool selected = myMove == move;
            return GestureDetector(
              onTap: iPlayed ? null : () => controller.updateGame({myField: move}),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: selected ? Colors.cyanAccent.withOpacity(0.2) : Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? Colors.cyanAccent : (iPlayed ? Colors.transparent : Colors.grey[800]!),
                    width: 2
                  ),
                  boxShadow: selected ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 20)] : []
                ),
                child: Text(move, style: const TextStyle(fontSize: 40)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _resolve(String m1, String m2) {
    String w = 'draw';
    if (m1 != m2) {
      if ((m1 == '🪨' && m2 == '✂️') || (m1 == '📄' && m2 == '🪨') || (m1 == '✂️' && m2 == '📄')) {
        w = controller.myId;
      } else {
        w = (controller.myId == data['host'] || controller.myId == 'P1') 
            ? (data['player2'] ?? 'AI') 
            : data['host'];
      }
    }
    controller.updateGame({}, mergeWinner: w);
  }
}

// =============================================================================
// 3. MEMORY MATRIX (3D Match)
// =============================================================================
class MemoryGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const MemoryGameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    List<dynamic> grid = data['state']['grid'] ?? [];
    List<bool> revealed = List<bool>.from(data['state']['revealed'] ?? []);
    bool isMyTurn = data['state']['turn'] == controller.myId;

    if (grid.isEmpty) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            isMyTurn ? "FIND A PAIR" : "MEMORIZING...",
            style: TextStyle(color: isMyTurn ? Colors.purpleAccent : Colors.grey, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: grid.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _handleTap(index, revealed, grid),
                child: TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 400),
                  tween: Tween<double>(begin: 0, end: revealed[index] ? 1 : 0),
                  builder: (context, double val, child) {
                    bool isFaceUp = val >= 0.5;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(val * pi),
                      child: isFaceUp 
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(pi), 
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.5), blurRadius: 10)],
                              ),
                              child: Center(
                                child: Text(
                                  "${grid[index]}",
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Icon(Icons.hub, color: Colors.grey, size: 20),
                            ),
                          ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleTap(int index, List<bool> revealed, List grid) {
    if (revealed[index] || data['state']['turn'] != controller.myId) return;

    revealed[index] = true;
    controller.updateGame({'revealed': revealed});

    int flippedCount = revealed.where((b) => b).length;
    if (flippedCount % 2 == 0) {
       Future.delayed(const Duration(seconds: 1), () {
          String nextTurn = (controller.myId == data['host'] || controller.myId == 'P1') 
            ? (data['player2'] ?? 'AI') 
            : data['host'];
          controller.updateGame({'turn': nextTurn});
       });
    }
  }
}