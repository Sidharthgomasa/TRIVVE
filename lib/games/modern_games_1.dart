import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';
import 'package:trivve/games/arcade_wrapper.dart'; // Ensure this is imported

// =============================================================================
// 1. NEON CONNECT 4 (With Info Integration)
// =============================================================================
class Connect4GameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const Connect4GameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    List board = data['state']['board']; 
    String turn = data['state']['turn'];
    bool isMyTurn = turn == controller.myId;

    return ArcadeWrapper(
      title: "CONNECT 4",
      instructions: "• Drop discs into columns.\n• First to align 4 discs in any direction—horizontal, vertical, or diagonal—wins.\n• Tap any cell in a column to drop your disc to the lowest available spot.",
      data: data,
      controller: controller,
      gameUI: Column(
        children: [
          const SizedBox(height: 60), // Space for Arcade Bar
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
      ),
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
      ),
      child: hasValue 
        ? TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<double>(begin: -1.0, end: 0.0),
            curve: Curves.bounceOut,
            builder: (context, double val, child) {
              return Transform.translate(
                offset: Offset(0, val * 50),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.6), blurRadius: 10, spreadRadius: 2),
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
          ? (data['player2'] ?? 'AI') : data['host'];
      controller.updateGame({'board': board, 'turn': nextTurn});
    }
  }
}

// =============================================================================
// 2. CYBER RPS - MATCH TO 10 (With Info Integration)
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
    int p1Score = data['state']['p1Score'] ?? 0;
    int p2Score = data['state']['p2Score'] ?? 0;
    
    bool bothPlayed = myMove.isNotEmpty && oppMove.isNotEmpty;

    if (bothPlayed && data['winner'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1500), () => _resolveRound(myMove, oppMove));
      });
    }

    return ArcadeWrapper(
      title: "RPS DUEL",
      instructions: "• Reach 10 points to win the match.\n• Rock crushes Scissors 🪨 > ✂️\n• Scissors cut Paper ✂️ > 📄\n• Paper covers Rock 📄 > 🪨\n• Tap your move and wait for the AI to reveal its choice.",
      data: data,
      controller: controller,
      gameUI: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _scoreBox("YOU", p1Score, Colors.cyanAccent),
              const Text("VS", style: TextStyle(color: Colors.white24, fontSize: 24)),
              _scoreBox("ENEMY", p2Score, Colors.pinkAccent),
            ],
          ),
          const SizedBox(height: 40),
          Text("OPPONENT'S MOVE", style: TextStyle(color: Colors.grey[600], letterSpacing: 2, fontSize: 10)),
          const SizedBox(height: 10),
          _buildMoveCircle(bothPlayed ? oppMove : (oppMove.isNotEmpty ? "READY" : "?"), bothPlayed),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ["🪨", "📄", "✂️"].map((move) {
              bool isSelected = myMove == move;
              return GestureDetector(
                onTap: (myMove.isNotEmpty || bothPlayed) ? null : () {
                  controller.updateGame({myField: move, 'turn': 'AI'});
                },
                child: _buildActionCard(move, isSelected, myMove.isNotEmpty),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _resolveRound(String m1, String m2) {
    int p1S = data['state']['p1Score'] ?? 0;
    int p2S = data['state']['p2Score'] ?? 0;
    String? finalWinner;

    if (m1 != m2) {
      bool p1Wins = (m1 == '🪨' && m2 == '✂️') || (m1 == '📄' && m2 == '🪨') || (m1 == '✂️' && m2 == '📄');
      if (p1Wins) p1S++; else p2S++;
    }

    if (p1S >= 10) finalWinner = 'P1';
    else if (p2S >= 10) finalWinner = 'AI';

    controller.updateGame({
      'p1Move': '', 'p2Move': '',
      'p1Score': p1S, 'p2Score': p2S,
      'turn': 'P1'
    }, mergeWinner: finalWinner);
  }

  Widget _scoreBox(String label, int score, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      Text("$score", style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w900, fontFamily: 'Courier')),
    ]);
  }

  Widget _buildMoveCircle(String content, bool active) {
    return Container(
      height: 90, width: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(color: active ? Colors.pinkAccent : Colors.white12, width: 2),
        boxShadow: active ? [BoxShadow(color: Colors.pinkAccent.withOpacity(0.3), blurRadius: 15)] : [],
      ),
      child: Center(child: Text(content, style: TextStyle(fontSize: 35, color: active ? Colors.white : Colors.white24))),
    );
  }

  Widget _buildActionCard(String move, bool selected, bool anyPlayed) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: selected ? Colors.cyanAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: selected ? Colors.cyanAccent : Colors.white12),
      ),
      child: Text(move, style: const TextStyle(fontSize: 35)),
    );
  }
}

// =============================================================================
// 3. MEMORY MATRIX (With Info Integration)
// =============================================================================
class MemoryGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const MemoryGameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    List<dynamic> grid = data['state']['grid'] ?? [];
    List<bool> revealed = List<bool>.from(data['state']['revealed'] ?? []);

    return ArcadeWrapper(
      title: "MEMORY",
      instructions: "• Flip tiles to find matching pairs.\n• Remember the positions!\n• The player with the most matches at the end wins.\n• Only two tiles can be flipped at a time.",
      data: data,
      controller: controller,
      gameUI: Column(
        children: [
          const SizedBox(height: 60),
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
                                  child: Text("${grid[index]}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                              ),
                              child: const Center(child: Icon(Icons.hub, color: Colors.grey, size: 20)),
                            ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
            ? (data['player2'] ?? 'AI') : data['host'];
          controller.updateGame({'turn': nextTurn});
       });
    }
  }
}