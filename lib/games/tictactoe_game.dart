import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart'; // Import your engine

class TicTacToeGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const TicTacToeGameUI({super.key, required this.data, required this.controller});

  @override
  State<TicTacToeGameUI> createState() => _TicTacToeGameUIState();
}

class _TicTacToeGameUIState extends State<TicTacToeGameUI> with TickerProviderStateMixin {
  // Animation controllers for the grid and marks
  late AnimationController _gridFade;
  
  @override
  void initState() {
    super.initState();
    _gridFade = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _gridFade.forward();
  }

  @override
  void dispose() {
    _gridFade.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    List board = List.from(widget.data['state']['board']);
    String currentTurn = widget.data['state']['turn'];
    bool isMyTurn = currentTurn == widget.controller.myId;

    if (widget.data['winner'] == null && isMyTurn && board[index] == '') {
      // 1. Make Move
      String symbol = (widget.controller.myId == widget.data['host'] || widget.controller.myId == 'P1') ? 'X' : 'O';
      board[index] = symbol;

      // 2. Check Win
      String? winner;
      if (_checkWin(board, symbol)) {
        winner = widget.controller.myId;
      } else if (!board.contains('')) {
        winner = 'draw';
      }

      // 3. Update Game
      String nextTurn = (widget.controller.myId == widget.data['host'] || widget.controller.myId == 'P1') 
          ? (widget.data['player2'] ?? 'AI') 
          : widget.data['host'];

      widget.controller.updateGame({
        'board': board,
        'turn': nextTurn
      }, mergeWinner: winner);
    }
  }

  bool _checkWin(List b, String p) {
    List<List<int>> wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    return wins.any((l) => b[l[0]]==p && b[l[1]]==p && b[l[2]]==p);
  }

  @override
  Widget build(BuildContext context) {
    List board = widget.data['state']['board'];
    String turn = widget.data['state']['turn'];
    bool isMyTurn = turn == widget.controller.myId;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. Status Indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isMyTurn ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent,
            border: Border.all(color: isMyTurn ? Colors.cyanAccent : Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isMyTurn ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.4), blurRadius: 20)] : []
          ),
          child: Text(
            isMyTurn ? "YOUR TURN" : "OPPONENT THINKING...",
            style: TextStyle(
              color: isMyTurn ? Colors.cyanAccent : Colors.grey,
              fontWeight: FontWeight.bold,
              letterSpacing: 2
            ),
          ),
        ),
        
        const SizedBox(height: 40),

        // 2. The Cyber Grid
        Center(
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 40, spreadRadius: 5),
                BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: -5),
              ]
            ),
            child: GridView.builder(
              padding: const EdgeInsets.all(15),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _handleTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: board[index] != '' 
                            ? (board[index] == 'X' ? Colors.pinkAccent : Colors.cyanAccent)
                            : Colors.white10
                      ),
                      boxShadow: board[index] != '' ? [
                        BoxShadow(
                          color: (board[index] == 'X' ? Colors.pinkAccent : Colors.cyanAccent).withOpacity(0.4),
                          blurRadius: 15,
                        )
                      ] : []
                    ),
                    child: Center(
                      child: board[index] == '' 
                          ? null 
                          : NeonMark(symbol: board[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// A widget to draw the Neon X or O
class NeonMark extends StatelessWidget {
  final String symbol;
  const NeonMark({super.key, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 400),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, double val, child) {
        return Transform.scale(
          scale: val, // Pop-in effect
          child: Opacity(
            opacity: val,
            child: Text(
              symbol,
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: symbol == 'X' ? Colors.pinkAccent : Colors.cyanAccent,
                shadows: [
                  Shadow(
                    color: symbol == 'X' ? Colors.pinkAccent : Colors.cyanAccent,
                    blurRadius: 20 * val
                  ),
                  Shadow(
                    color: Colors.white,
                    blurRadius: 5 * val
                  )
                ]
              ),
            ),
          ),
        );
      },
    );
  }
}