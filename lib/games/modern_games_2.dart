import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

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

  // Animation for Food Pulse
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
      // Respawn food randomly
      food = Random().nextInt(400); 
      while (snake.contains(food)) { food = Random().nextInt(400); }
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      setState(() {
        _moveSnake();
      });
    });
  }

  void _moveSnake() {
    int head = snake.first;
    
    if (direction == 'up') head -= 20;
    if (direction == 'down') head += 20;
    if (direction == 'left') head -= 1;
    if (direction == 'right') head += 1;

    // Wall Collision or Self Collision
    if (head < 0 || head >= 400 || snake.contains(head)) {
      _gameOver();
      return;
    }

    // Wrap-around logic for Left/Right edges (optional, strictly grid based here)
    if (direction == 'left' && (snake.first % 20 == 0)) { _gameOver(); return; }
    if (direction == 'right' && ((snake.first + 1) % 20 == 0)) { _gameOver(); return; }

    snake.insert(0, head);

    if (head == food) {
      score += 10;
      // Respawn food
      food = Random().nextInt(400);
      while (snake.contains(food)) { food = Random().nextInt(400); }
    } else {
      snake.removeLast();
    }
  }

  void _gameOver() {
    _gameLoop?.cancel();
    setState(() => isPlaying = false);
    
    // Submit Score
    widget.controller.updateGame({
      'p1Score': score
    }, mergeWinner: widget.data['host'] == widget.controller.myId ? null : 'AI'); // AI Logic will check winner
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
    return Column(
      children: [
        // Score Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          color: Colors.black,
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

        // Game Grid
        Expanded(
          child: GestureDetector(
            onPanUpdate: _handleSwipe,
            child: Container(
              color: Colors.grey[900], // Dark Background
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 400, // 20x20 Grid
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 20,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                ),
                itemBuilder: (context, index) {
                  bool isSnake = snake.contains(index);
                  bool isHead = snake.isNotEmpty && snake.first == index;
                  bool isFood = food == index;

                  if (isSnake) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isHead ? Colors.white : Colors.cyanAccent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isHead ? [const BoxShadow(color: Colors.cyanAccent, blurRadius: 10)] : []
                      ),
                    );
                  } else if (isFood) {
                    return AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (ctx, child) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent, blurRadius: 5 + (_pulseCtrl.value * 5))
                            ]
                          ),
                        );
                      },
                    );
                  } else {
                    return Container(color: Colors.black);
                  }
                },
              ),
            ),
          ),
        ),
      ],
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
    List board = data['state']['board']; // 100 slots (10x10)
    String turn = data['state']['turn'];
    bool isMyTurn = turn == controller.myId;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isMyTurn ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isMyTurn ? Colors.orangeAccent.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: isMyTurn ? Colors.orangeAccent : Colors.grey)
            ),
            child: Text(
              isMyTurn ? "YOUR TURN (Place Stone)" : "AI THINKING...",
              style: TextStyle(color: isMyTurn ? Colors.orangeAccent : Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        Center(
          child: Container(
            width: 350, height: 350,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[800]!, width: 5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)]
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
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[900]!),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Grid Cross Line
                        if (cell == '') const Icon(Icons.add, size: 10, color: Colors.grey),
                        
                        // The Stone
                        if (cell != '') 
                          TweenAnimationBuilder(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (ctx, double val, child) {
                              return Transform.scale(
                                scale: val,
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: cell == 'B' 
                                        ? [Colors.grey[800]!, Colors.black] 
                                        : [Colors.white, Colors.grey[300]!],
                                      center: const Alignment(-0.3, -0.3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(2, 2), blurRadius: 3)
                                    ]
                                  ),
                                ),
                              );
                            },
                          )
                      ],
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

  void _handleTap(int index) {
    if (data['winner'] != null || data['state']['turn'] != controller.myId) return;
    List board = List.from(data['state']['board']);
    
    if (board[index] == '') {
      board[index] = 'B'; // Player is always Black ('B') in local vs AI
      controller.updateGame({
        'board': board,
        'turn': 'AI' // Pass turn explicitly to AI
      });
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
  int? _activePad; // Which pad is currently lit up
  String _status = "WATCH SEQUENCE";
  bool _userInputEnabled = false;
  int _currentStep = 0;

  @override
  void didUpdateWidget(SimonGameUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If turn changed to AI or sequence grew, play it
    if (widget.data['state']['turn'] == 'AI' && oldWidget.data['state']['turn'] != 'AI') {
       _playSequence();
    }
    // Initial start logic if data loaded fresh
    if (widget.data['state']['sequence'].isNotEmpty && widget.data['state']['turn'] == 'AI' && !_userInputEnabled) {
       _playSequence();
    }
  }

  Future<void> _playSequence() async {
    if (!mounted) return;
    setState(() {
      _status = "WATCH...";
      _userInputEnabled = false;
    });

    await Future.delayed(const Duration(seconds: 1)); // Wait a beat

    List sequence = widget.data['state']['sequence'];
    for (int padIndex in sequence) {
      if (!mounted) return;
      setState(() => _activePad = padIndex); // Light up
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _activePad = null); // Light off
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;
    setState(() {
      _status = "YOUR TURN!";
      _userInputEnabled = true;
      _currentStep = 0;
    });
  }

  void _handlePadTap(int padIndex) {
    if (!_userInputEnabled) return;

    // Flash the pad briefly for feedback
    setState(() => _activePad = padIndex);
    Future.delayed(const Duration(milliseconds: 200), () => setState(() => _activePad = null));

    List sequence = widget.data['state']['sequence'];
    if (sequence[_currentStep] == padIndex) {
      _currentStep++;
      if (_currentStep >= sequence.length) {
        // Completed sequence successfully
        setState(() {
          _status = "GOOD! NEXT LEVEL...";
          _userInputEnabled = false;
        });
        // Pass turn to AI to add next step
        widget.controller.updateGame({'turn': 'AI'});
      }
    } else {
      // Failed
      setState(() => _status = "GAME OVER!");
      widget.controller.updateGame({}, mergeWinner: 'AI');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_status, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
        const SizedBox(height: 40),
        
        SizedBox(
          width: 300, height: 300,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            padding: const EdgeInsets.all(10),
            children: [
              _buildPad(0, Colors.greenAccent),
              _buildPad(1, Colors.redAccent),
              _buildPad(2, Colors.yellowAccent),
              _buildPad(3, Colors.blueAccent),
            ],
          ),
        ),
      ],
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
        child: Center(
          child: Icon(Icons.touch_app, color: isActive ? Colors.white : color.withOpacity(0.5), size: 40),
        ),
      ),
    );
  }
}