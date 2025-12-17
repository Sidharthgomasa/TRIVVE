import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';
import 'package:trivve/games/arcade_wrapper.dart'; // Ensure this is imported

// =============================================================================
// 1. NEON WHACK (Whack-A-Mole)
// =============================================================================
class WhackAMoleGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const WhackAMoleGameUI({super.key, required this.data, required this.controller});

  @override
  State<WhackAMoleGameUI> createState() => _WhackAMoleGameUIState();
}

class _WhackAMoleGameUIState extends State<WhackAMoleGameUI> {
  int activeIndex = -1;
  int score = 0;
  Timer? _timer;
  bool isPlaying = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    if (isPlaying) return;
    setState(() {
      isPlaying = true;
      score = 0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (!mounted) return;
      setState(() { activeIndex = Random().nextInt(9); });
    });
  }

  void _handleTap(int index) {
    if (!isPlaying) return;
    if (index == activeIndex) {
      setState(() {
        score++;
        activeIndex = -1;
      });
      if (score >= 15) {
        _stopGame();
        widget.controller.updateGame({'p1Score': score}, mergeWinner: widget.controller.myId);
      }
    }
  }

  void _stopGame() {
    _timer?.cancel();
    setState(() => isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeWrapper(
      title: "WHACK-A-MOLE",
      instructions: "• Tap the moles as they pop up from the holes.\n• Don't miss! Speed is key.\n• Hit 15 moles to reach the target score and win.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("HITS: $score/15", style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                if (!isPlaying)
                  ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
                    child: const Text("START", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 9,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15,
                  ),
                  itemBuilder: (context, index) {
                    bool isActive = index == activeIndex;
                    return GestureDetector(
                      onTap: () => _handleTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          shape: BoxShape.circle,
                          border: Border.all(color: isActive ? Colors.amberAccent : Colors.grey[800]!, width: isActive ? 3 : 1),
                          boxShadow: isActive ? [BoxShadow(color: Colors.amberAccent, blurRadius: 20)] : [],
                        ),
                        child: isActive ? const Icon(Icons.pest_control, color: Colors.amberAccent, size: 40) : null,
                      ),
                    );
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
// 2. CYBER LIGHTS (Lights Out Logic)
// =============================================================================
class LightsOutGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const LightsOutGameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    List<bool> grid = List<bool>.from(data['state']['grid'] ?? List.filled(25, false));

    return ArcadeWrapper(
      title: "LIGHTS OUT",
      instructions: "• Tapping a light toggles it and its adjacent neighbors (Up, Down, Left, Right).\n• Your goal: Turn all the lights off simultaneously to win.",
      data: data,
      controller: controller,
      gameUI: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          const Text("TURN OFF ALL LIGHTS", style: TextStyle(color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 350, height: 350,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 25,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8
                ),
                itemBuilder: (context, index) {
                  bool isOn = grid[index];
                  return GestureDetector(
                    onTap: () => _handleTap(index, grid),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: isOn ? Colors.cyanAccent : Colors.grey[900],
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: isOn ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.8), blurRadius: 15)] : [],
                        border: Border.all(color: isOn ? Colors.white : Colors.white10)
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

  void _handleTap(int index, List<bool> grid) {
    if (data['winner'] != null) return;
    _toggle(grid, index);
    if (index % 5 != 0) _toggle(grid, index - 1);
    if (index % 5 != 4) _toggle(grid, index + 1);
    if (index >= 5) _toggle(grid, index - 5);
    if (index < 20) _toggle(grid, index + 5);

    String? winner;
    if (grid.every((light) => !light)) winner = controller.myId;
    controller.updateGame({'grid': grid}, mergeWinner: winner);
  }

  void _toggle(List<bool> grid, int index) { grid[index] = !grid[index]; }
}

// =============================================================================
// 3. HYPER TAP (Tap Attack)
// =============================================================================
class TapAttackGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const TapAttackGameUI({super.key, required this.data, required this.controller});

  @override
  State<TapAttackGameUI> createState() => _TapAttackGameUIState();
}

class _TapAttackGameUIState extends State<TapAttackGameUI> with TickerProviderStateMixin {
  int score = 0;
  bool isPlaying = false;
  Alignment targetAlign = Alignment.center;
  Timer? _timer;
  double timeLeft = 30.0;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    if (isPlaying) return;
    setState(() {
      score = 0;
      timeLeft = 30.0;
      isPlaying = true;
      _respawn();
    });

    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() {
        timeLeft -= 0.1;
        if (timeLeft <= 0) _gameOver();
      });
    });
  }

  void _respawn() {
    double x = (Random().nextDouble() * 1.8) - 0.9;
    double y = (Random().nextDouble() * 1.8) - 0.9;
    setState(() { targetAlign = Alignment(x, y); });
  }

  void _handleTap() {
    if (!isPlaying) return;
    setState(() => score++);
    _respawn();
  }

  void _gameOver() {
    _timer?.cancel();
    setState(() => isPlaying = false);
    widget.controller.updateGame({'p1Score': score}, mergeWinner: widget.controller.myId);
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeWrapper(
      title: "TAP ATTACK",
      instructions: "• Tap the moving target as fast as possible before time runs out.\n• Each tap adds to your score.\n• Reach the highest score within 30 seconds to win.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Stack(
        children: [
          const SizedBox(height: 60),
          Positioned(
            top: 60, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("SCORE: $score", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("${timeLeft.toStringAsFixed(1)}s", style: TextStyle(color: timeLeft < 5 ? Colors.red : Colors.white, fontSize: 24)),
                ],
              ),
            ),
          ),
          if (!isPlaying)
            Center(
              child: ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.touch_app, color: Colors.black),
                label: const Text("START ATTACK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              ),
            ),
          if (isPlaying)
            Align(
              alignment: targetAlign,
              child: GestureDetector(
                onTap: _handleTap,
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    return Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.pinkAccent,
                        boxShadow: [BoxShadow(color: Colors.pinkAccent, blurRadius: 10 + (10 * _pulseCtrl.value), spreadRadius: 2)],
                        border: Border.all(color: Colors.white, width: 3)
                      ),
                      child: const Icon(Icons.api, color: Colors.white, size: 40),
                    );
                  },
                ),
              ),
            )
        ],
      ),
    );
  }
}