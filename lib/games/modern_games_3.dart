import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

// =============================================================================
// 1. NEON 2048 (Physics & Merging Logic)
// =============================================================================
class Game2048UI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const Game2048UI({super.key, required this.data, required this.controller});

  @override
  State<Game2048UI> createState() => _Game2048UIState();
}

class _Game2048UIState extends State<Game2048UI> {
  // Colors for tiles 2, 4, 8, 16...
  final Map<int, Color> _tileColors = {
    2: Colors.cyanAccent, 4: Colors.purpleAccent, 8: Colors.orangeAccent,
    16: Colors.pinkAccent, 32: Colors.greenAccent, 64: Colors.blueAccent,
    128: Colors.yellowAccent, 256: Colors.redAccent, 512: Colors.tealAccent,
    1024: Colors.indigoAccent, 2048: Colors.amberAccent
  };

  void _handleSwipe(String dir) {
    if (widget.data['winner'] != null) return;

    List<int> grid = List<int>.from(widget.data['state']['grid']);
    bool moved = false;

    // 1. MERGE LOGIC
    if (dir == 'left') moved = _moveLeft(grid);
    else if (dir == 'right') moved = _moveRight(grid);
    else if (dir == 'up') moved = _moveUp(grid);
    else if (dir == 'down') moved = _moveDown(grid);

    if (moved) {
      // 2. SPAWN NEW TILE
      List<int> empty = [];
      for (int i = 0; i < 16; i++) if (grid[i] == 0) empty.add(i);
      if (empty.isNotEmpty) {
        grid[empty[Random().nextInt(empty.length)]] = Random().nextBool() ? 2 : 4;
      }

      // 3. CHECK WIN/LOSS
      String? winner;
      if (grid.contains(2048)) winner = widget.controller.myId; // Win Condition
      else if (!_canMove(grid)) winner = 'AI'; // Loss Condition (Grid Full)

      widget.controller.updateGame({'grid': grid}, mergeWinner: winner);
    }
  }

  // --- LOGIC HELPERS ---
  bool _moveLeft(List<int> grid) {
    bool moved = false;
    for (int r = 0; r < 4; r++) {
      List<int> row = [grid[r*4], grid[r*4+1], grid[r*4+2], grid[r*4+3]];
      List<int> newRow = _mergeRow(row);
      for (int c = 0; c < 4; c++) {
        if (grid[r*4+c] != newRow[c]) moved = true;
        grid[r*4+c] = newRow[c];
      }
    }
    return moved;
  }
  bool _moveRight(List<int> grid) {
    bool moved = false;
    for (int r = 0; r < 4; r++) {
      List<int> row = [grid[r*4+3], grid[r*4+2], grid[r*4+1], grid[r*4]];
      List<int> newRow = _mergeRow(row);
      for (int c = 0; c < 4; c++) {
        if (grid[r*4+(3-c)] != newRow[c]) moved = true;
        grid[r*4+(3-c)] = newRow[c];
      }
    }
    return moved;
  }
  bool _moveUp(List<int> grid) {
    bool moved = false;
    for (int c = 0; c < 4; c++) {
      List<int> col = [grid[c], grid[c+4], grid[c+8], grid[c+12]];
      List<int> newCol = _mergeRow(col);
      for (int r = 0; r < 4; r++) {
        if (grid[r*4+c] != newCol[r]) moved = true;
        grid[r*4+c] = newCol[r];
      }
    }
    return moved;
  }
  bool _moveDown(List<int> grid) {
    bool moved = false;
    for (int c = 0; c < 4; c++) {
      List<int> col = [grid[c+12], grid[c+8], grid[c+4], grid[c]];
      List<int> newCol = _mergeRow(col);
      for (int r = 0; r < 4; r++) {
        if (grid[(3-r)*4+c] != newCol[r]) moved = true;
        grid[(3-r)*4+c] = newCol[r];
      }
    }
    return moved;
  }

  List<int> _mergeRow(List<int> row) {
    List<int> nonZero = row.where((e) => e != 0).toList();
    for (int i = 0; i < nonZero.length - 1; i++) {
      if (nonZero[i] == nonZero[i+1]) {
        nonZero[i] *= 2;
        nonZero[i+1] = 0;
      }
    }
    nonZero = nonZero.where((e) => e != 0).toList();
    while (nonZero.length < 4) nonZero.add(0);
    return nonZero;
  }

  bool _canMove(List<int> grid) {
    if (grid.contains(0)) return true;
    for (int i = 0; i < 16; i++) {
      int r = i ~/ 4, c = i % 4;
      if (c < 3 && grid[i] == grid[i+1]) return true;
      if (r < 3 && grid[i] == grid[i+4]) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> grid = widget.data['state']['grid'];
    return GestureDetector(
      onVerticalDragEnd: (d) => _handleSwipe(d.primaryVelocity! < 0 ? 'up' : 'down'),
      onHorizontalDragEnd: (d) => _handleSwipe(d.primaryVelocity! < 0 ? 'left' : 'right'),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          width: 350, height: 350,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white24)
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 16,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8
            ),
            itemBuilder: (ctx, i) {
              int val = grid[i];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: val == 0 ? Colors.white10 : (_tileColors[val] ?? Colors.black).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: val == 0 ? Colors.transparent : (_tileColors[val] ?? Colors.white)),
                  boxShadow: val > 0 ? [BoxShadow(color: (_tileColors[val] ?? Colors.white).withOpacity(0.4), blurRadius: 10)] : []
                ),
                child: Center(child: Text(val > 0 ? "$val" : "", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: _tileColors[val] ?? Colors.white))),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. CYBER MINESWEEPER (Logic: Reveal, Flood Fill, Boom)
// =============================================================================
class MinesweeperGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const MinesweeperGameUI({super.key, required this.data, required this.controller});

  @override
  State<MinesweeperGameUI> createState() => _MinesweeperGameUIState();
}

class _MinesweeperGameUIState extends State<MinesweeperGameUI> {
  
  void _handleTap(int index) {
    if (widget.data['winner'] != null) return;

    List<bool> revealed = List<bool>.from(widget.data['state']['revealed']);
    List<bool> grid = List<bool>.from(widget.data['state']['grid']); // True = Bomb

    if (revealed[index]) return;

    if (grid[index]) {
      // 💥 BOOM! Game Over.
      revealed[index] = true; // Show the bomb
      widget.controller.updateGame({'revealed': revealed}, mergeWinner: 'AI'); // AI wins (Player lost)
    } else {
      // ✅ SAFE
      _revealSafe(index, revealed, grid);
      
      // Check Win (All safe revealed)
      int totalSafe = grid.where((b) => !b).length;
      int totalRevealed = 0;
      for(int i=0; i<25; i++) if(!grid[i] && revealed[i]) totalRevealed++;
      
      String? winner;
      if (totalRevealed == totalSafe) winner = widget.controller.myId;

      widget.controller.updateGame({'revealed': revealed}, mergeWinner: winner);
    }
  }

  void _revealSafe(int index, List<bool> revealed, List<bool> grid) {
    // Simple Flood Fill could go here, but for V1 we just reveal one tile 
    // to keep code safe and lag-free. 
    revealed[index] = true;
  }

  @override
  Widget build(BuildContext context) {
    List<bool> revealed = List<bool>.from(widget.data['state']['revealed']);
    List<bool> grid = List<bool>.from(widget.data['state']['grid']);

    return Center(
      child: Container(
        width: 350, height: 350,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.greenAccent), borderRadius: BorderRadius.circular(20)),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 25,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 5, mainAxisSpacing: 5),
          itemBuilder: (ctx, i) {
            bool isRevealed = revealed[i];
            bool isBomb = grid[i];
            
            return GestureDetector(
              onTap: () => _handleTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isRevealed 
                      ? (isBomb ? Colors.red : Colors.grey[800]) 
                      : Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: isRevealed ? Colors.transparent : Colors.greenAccent.withOpacity(0.5))
                ),
                child: Center(
                  child: isRevealed 
                    ? (isBomb ? const Icon(Icons.dangerous, color: Colors.black) : const Icon(Icons.check, color: Colors.white24, size: 15))
                    : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// 3. NEON WORDLE (Logic: Guess Check)
// =============================================================================
class WordleGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const WordleGameUI({super.key, required this.data, required this.controller});

  @override
  State<WordleGameUI> createState() => _WordleGameUIState();
}

class _WordleGameUIState extends State<WordleGameUI> {
  final TextEditingController _textCtrl = TextEditingController();

  void _submitGuess() {
    if (widget.data['winner'] != null) return;
    
    String guess = _textCtrl.text.toUpperCase();
    if (guess.length != 4) return; // Enforce 4 letters

    String target = widget.data['state']['word'] ?? 'CODE';
    List<dynamic> guesses = List.from(widget.data['state']['guesses']);
    
    guesses.add(guess);
    _textCtrl.clear();

    String? winner;
    if (guess == target) winner = widget.controller.myId;
    else if (guesses.length >= 6) winner = 'AI'; // Lose condition

    widget.controller.updateGame({'guesses': guesses}, mergeWinner: winner);
  }

  @override
  Widget build(BuildContext context) {
    String target = widget.data['state']['word'] ?? 'CODE';
    List<dynamic> guesses = widget.data['state']['guesses'];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: 6, // Max 6 guesses
            itemBuilder: (ctx, i) {
              if (i < guesses.length) {
                return _buildRow(guesses[i], target);
              } else {
                return _buildEmptyRow();
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  maxLength: 4,
                  style: const TextStyle(color: Colors.white, letterSpacing: 5, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "TYPE 4 LETTERS",
                    hintStyle: TextStyle(letterSpacing: 1, fontSize: 12),
                    counterText: "",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white10
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _submitGuess, 
                icon: const Icon(Icons.send),
                style: IconButton.styleFrom(backgroundColor: Colors.greenAccent),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildRow(String guess, String target) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        String char = guess[i];
        Color color = Colors.grey;
        if (target[i] == char) color = Colors.green;
        else if (target.contains(char)) color = Colors.amber;
        
        return Container(
          margin: const EdgeInsets.all(5),
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)]
          ),
          child: Center(child: Text(char, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black))),
        );
      }),
    );
  }

  Widget _buildEmptyRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) => Container(
        margin: const EdgeInsets.all(5),
        width: 50, height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(10)
        ),
      )),
    );
  }
}