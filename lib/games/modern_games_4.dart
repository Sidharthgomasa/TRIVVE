import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

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

    // Game Loop: Move the "Mole" every 700ms
    _timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (!mounted) return;
      setState(() {
        activeIndex = Random().nextInt(9); // 3x3 Grid
      });
    });
  }

  void _handleTap(int index) {
    if (!isPlaying) return;

    if (index == activeIndex) {
      // HIT!
      setState(() {
        score++;
        activeIndex = -1; // Hide immediately to prevent double taps
      });
      
      // Check Win (e.g., 15 hits)
      if (score >= 15) {
        _stopGame();
        widget.controller.updateGame({'p1Score': score}, mergeWinner: widget.controller.myId);
      }
    } else {
      // MISS! (Optional penalty)
    }
  }

  void _stopGame() {
    _timer?.cancel();
    setState(() => isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                  crossAxisCount: 3,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
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
                        border: Border.all(
                          color: isActive ? Colors.amberAccent : Colors.grey[800]!,
                          width: isActive ? 3 : 1
                        ),
                        boxShadow: isActive ? [BoxShadow(color: Colors.amberAccent, blurRadius: 20, spreadRadius: 2)] : [],
                      ),
                      child: isActive 
                        ? const Icon(Icons.pest_control, color: Colors.amberAccent, size: 40)
                        : null,
                    ),
                  );
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
// 2. CYBER LIGHTS (Lights Out Logic)
// =============================================================================
class LightsOutGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const LightsOutGameUI({super.key, required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    List<bool> grid = List<bool>.from(data['state']['grid'] ?? List.filled(25, false));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text("TURN OFF ALL LIGHTS", style: TextStyle(color: Colors.white54, letterSpacing: 2)),
        ),
        Center(
          child: Container(
            width: 350, height: 350,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20)],
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
    );
  }

  void _handleTap(int index, List<bool> grid) {
    if (data['winner'] != null) return;

    // Toggle Logic (Self + Neighbors)
    _toggle(grid, index);
    if (index % 5 != 0) _toggle(grid, index - 1); // Left
    if (index % 5 != 4) _toggle(grid, index + 1); // Right
    if (index >= 5) _toggle(grid, index - 5);     // Up
    if (index < 20) _toggle(grid, index + 5);     // Down

    // Check Win
    String? winner;
    if (grid.every((light) => !light)) winner = controller.myId;

    controller.updateGame({'grid': grid}, mergeWinner: winner);
  }

  void _toggle(List<bool> grid, int index) {
    grid[index] = !grid[index];
  }
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
  double timeLeft = 30.0; // 30 seconds

  // Pulse Animation
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
        if (timeLeft <= 0) {
          _gameOver();
        }
      });
    });
  }

  void _respawn() {
    // Random alignment between -0.9 and 0.9 to stay on screen
    double x = (Random().nextDouble() * 1.8) - 0.9;
    double y = (Random().nextDouble() * 1.8) - 0.9;
    setState(() {
      targetAlign = Alignment(x, y);
    });
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
    return Stack(
      children: [
        // UI Header
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("SCORE: $score", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text("${timeLeft.toStringAsFixed(1)}s", style: TextStyle(color: timeLeft < 5 ? Colors.red : Colors.white, fontSize: 24)),
              ],
            ),
          ),
        ),

        // Start Button
        if (!isPlaying)
          Center(
            child: ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.touch_app, color: Colors.black),
              label: const Text("START ATTACK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            ),
          ),

        // The Target
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
                      boxShadow: [
                        BoxShadow(color: Colors.pinkAccent, blurRadius: 10 + (10 * _pulseCtrl.value), spreadRadius: 2)
                      ],
                      border: Border.all(color: Colors.white, width: 3)
                    ),
                    child: const Icon(Icons.api, color: Colors.white, size: 40),
                  );
                },
              ),
            ),
          )
      ],
    );
  }
}