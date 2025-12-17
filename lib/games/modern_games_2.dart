import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';
import 'package:trivve/games/arcade_wrapper.dart';

// =============================================================================
// 1. CYBER SNAKE (Neon Arcade Style)
// =============================================================================
class CyberSnakeGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const CyberSnakeGameUI({super.key, required this.data, required this.controller});

  @override
  State<CyberSnakeGameUI> createState() => _CyberSnakeGameUIState();
}

class _CyberSnakeGameUIState extends State<CyberSnakeGameUI> with TickerProviderStateMixin {
  List<int> snake = [45, 44, 43];
  int food = 85;
  String direction = 'down';
  Timer? _gameLoop;
  bool isPlaying = false;
  int score = 0;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    if (isPlaying) return;
    setState(() {
      snake = [45, 44, 43];
      score = 0;
      direction = 'down';
      isPlaying = true;
      food = Random().nextInt(400); 
      while (snake.contains(food)) { food = Random().nextInt(400); }
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      setState(() { _moveSnake(); });
    });
  }

  void _moveSnake() {
    int head = snake.first;
    int col = head % 20; 

    if (direction == 'up') head -= 20;
    if (direction == 'down') head += 20;
    if (direction == 'left') head -= 1;
    if (direction == 'right') head += 1;

    // --- CRITICAL FIX: WALL DETECTION ---
    bool hitWall = false;
    if (head < 0 || head >= 400) hitWall = true; 
    if (direction == 'left' && col == 0) hitWall = true; 
    if (direction == 'right' && col == 19) hitWall = true; 

    if (hitWall || snake.contains(head)) {
      _gameOver();
      return;
    }

    snake.insert(0, head);
    if (head == food) {
      score += 10;
      food = Random().nextInt(400);
      while (snake.contains(food)) { food = Random().nextInt(400); }
    } else {
      snake.removeLast();
    }
  }

  void _gameOver() {
    _gameLoop?.cancel();
    setState(() => isPlaying = false);
    widget.controller.updateGame({
      'p1Score': score
    }, mergeWinner: score >= (widget.data['p2Score'] ?? 150) ? widget.controller.myId : 'AI');
  }

  void _handleSwipe(DragUpdateDetails details) {
    if (details.delta.dx.abs() > details.delta.dy.abs()) {
      if (details.delta.dx > 0 && direction != 'left') direction = 'right';
      else if (details.delta.dx < 0 && direction != 'right') direction = 'left';
    } else {
      if (details.delta.dy > 0 && direction != 'up') direction = 'down';
      else if (details.delta.dy < 0 && direction != 'down') direction = 'up';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeWrapper(
      title: "CYBER SNAKE",
      instructions: "• Swipe to navigate the snake.\n• Eat neon orbs to grow.\n• Avoid hitting walls or your tail.\n• Reach target score to win.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("SCORE: $score", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 20)),
                if (!isPlaying) 
                  ElevatedButton.icon(
                    onPressed: _startGame, 
                    icon: const Icon(Icons.play_arrow, color: Colors.black),
                    label: const Text("START RUN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                  )
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onPanUpdate: _handleSwipe,
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent.withOpacity(0.3))),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 400,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 20),
                  itemBuilder: (context, index) {
                    bool isSnake = snake.contains(index);
                    bool isHead = snake.isNotEmpty && snake.first == index;
                    bool isFood = food == index;
                    if (isSnake) {
                      return Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: isHead ? Colors.white : Colors.cyanAccent,
                          boxShadow: isHead ? [const BoxShadow(color: Colors.cyanAccent, blurRadius: 10)] : []
                        ),
                      );
                    } else if (isFood) {
                      return AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (ctx, child) => Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 5 + (_pulseCtrl.value * 5))]
                          ),
                        ),
                      );
                    }
                    return Container(color: Colors.black.withOpacity(0.1));
                  },
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
// 2. NEON GOMOKU (10x10 Board)
// =============================================================================
class GomokuGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const GomokuGameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    List board = data['state']['board'];
    String turn = data['state']['turn'];
    bool isMyTurn = turn == controller.myId;

    return ArcadeWrapper(
      title: "GOMOKU",
      instructions: "• Standard 5-in-a-row.\n• Place stones on the grid.\n• Align five stones to win.",
      data: data,
      controller: controller,
      gameUI: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Text(isMyTurn ? "YOUR TURN" : "AI THINKING...", 
               style: TextStyle(color: isMyTurn ? Colors.orangeAccent : Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: Colors.grey[800]!, width: 2),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 100,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                itemBuilder: (context, index) {
                  String cell = board[index];
                  return GestureDetector(
                    onTap: () => _handleTap(index),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white10, width: 0.5)),
                      child: Center(
                        child: cell == '' 
                          ? const Icon(Icons.add, size: 8, color: Colors.white10)
                          : Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cell == 'B' ? Colors.black : Colors.white,
                                border: Border.all(color: Colors.grey),
                                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)]
                              ),
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(int index) {
    if (data['winner'] != null || data['state']['turn'] != controller.myId) return;
    List board = List.from(data['state']['board']);
    if (board[index] == '') {
      board[index] = 'B';
      controller.updateGame({'board': board, 'turn': 'AI'});
    }
  }
}

// =============================================================================
// 3. NEON SIMON (Memory Rhythm)
// =============================================================================
class SimonGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const SimonGameUI({super.key, required this.data, required this.controller});

  @override
  State<SimonGameUI> createState() => _SimonGameUIState();
}

class _SimonGameUIState extends State<SimonGameUI> {
  int? _activePad;
  String _status = "WATCH SEQUENCE";
  bool _userInputEnabled = false;
  int _currentStep = 0;

  @override
  void didUpdateWidget(SimonGameUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data['state']['turn'] == 'AI' && oldWidget.data['state']['turn'] != 'AI') {
       _playSequence();
    }
    if (widget.data['state']['sequence'].isNotEmpty && widget.data['state']['turn'] == 'AI' && !_userInputEnabled) {
       _playSequence();
    }
  }

  Future<void> _playSequence() async {
    if (!mounted) return;
    setState(() { _status = "WATCH..."; _userInputEnabled = false; });
    await Future.delayed(const Duration(seconds: 1));
    List sequence = widget.data['state']['sequence'];
    for (int padIndex in sequence) {
      if (!mounted) return;
      setState(() => _activePad = padIndex);
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _activePad = null);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    setState(() { _status = "YOUR TURN!"; _userInputEnabled = true; _currentStep = 0; });
  }

  void _handlePadTap(int padIndex) {
    if (!_userInputEnabled) return;
    setState(() => _activePad = padIndex);
    Future.delayed(const Duration(milliseconds: 200), () => setState(() => _activePad = null));

    List sequence = widget.data['state']['sequence'];
    if (sequence[_currentStep] == padIndex) {
      _currentStep++;
      if (_currentStep >= sequence.length) {
        setState(() { _status = "GOOD!"; _userInputEnabled = false; });
        widget.controller.updateGame({
          'turn': 'AI', 
          'userStep': 0 
        });
      }
    } else {
      setState(() => _status = "GAME OVER!");
      widget.controller.updateGame({}, mergeWinner: 'AI');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeWrapper(
      title: "SIMON SAYS",
      instructions: "• Watch the sequence.\n• Repeat the pattern.\n• The length increases each round.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Text(_status, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
          const SizedBox(height: 40),
          SizedBox(
            width: 300, height: 300,
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              children: [
                _buildPad(0, Colors.greenAccent),
                _buildPad(1, Colors.redAccent),
                _buildPad(2, Colors.yellowAccent),
                _buildPad(3, Colors.blueAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPad(int index, Color color) {
    bool isActive = _activePad == index;
    return GestureDetector(
      onTapDown: (_) => _handlePadTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: isActive ? [BoxShadow(color: color, blurRadius: 30, spreadRadius: 5)] : []
        ),
        child: Center(child: Icon(Icons.touch_app, color: isActive ? Colors.white : color.withOpacity(0.5), size: 40)),
      ),
    );
  }
}