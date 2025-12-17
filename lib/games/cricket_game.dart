import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';
import 'package:trivve/games/arcade_wrapper.dart';

// =============================================================================
// 🏏 PRO CRICKET (Final Realistic 1-Over Edition)
// =============================================================================

class CricketGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const CricketGameUI({super.key, required this.data, required this.controller});

  @override
  State<CricketGameUI> createState() => _CricketGameUIState();
}

class _CricketGameUIState extends State<CricketGameUI> with TickerProviderStateMixin {
  late AnimationController _ballCtrl;
  late AnimationController _batCtrl;
  late AnimationController _hitEffectCtrl;
  
  String _commentary = "1 OVER MATCH - START!";
  bool _isBowling = false;
  bool _ballDelivered = false;
  double _ballProgress = 0.0;
  double _ballHorizontalShift = 0.0;
  final List<String> _overHistory = [];

  @override
  void initState() {
    super.initState();
    _ballCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _ballCtrl.addListener(() {
      setState(() {
        _ballProgress = _ballCtrl.value;
        // If ball reaches the end without being hit
        if (_ballProgress == 1.0 && _isBowling) _handleShot(missed: true);
      });
    });

    _batCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _hitEffectCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    
    _startDelivery();
  }

  @override
  void dispose() {
    _ballCtrl.dispose();
    _batCtrl.dispose();
    _hitEffectCtrl.dispose();
    super.dispose();
  }

  void _startDelivery() async {
    if (_isBowling || _overHistory.length >= 6) return;
    
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _isBowling = true;
      _ballDelivered = false;
      _commentary = "Bowler approaching...";
      _ballProgress = 0;
      _ballHorizontalShift = (Random().nextDouble() * 80) - 40; // Random swing
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    
    setState(() => _ballDelivered = true);
    // Randomize delivery speed (between 800ms and 1400ms)
    _ballCtrl.duration = Duration(milliseconds: 800 + Random().nextInt(600));
    _ballCtrl.forward(from: 0);
  }

  void _attemptShot() {
    if (!_isBowling || !_ballDelivered) return;

    _batCtrl.forward(from: 0).then((_) => _batCtrl.reverse());
    double p = _ballProgress;
    _ballCtrl.stop(); 
    
    int runs = 0;
    String outcome = "";
    
    // Timing Logic (Sweet spot is between 0.82 and 0.93)
    if (p < 0.78) {
      outcome = "TOO EARLY!";
      runs = 0; 
    } else if (p < 0.82) {
      outcome = "EDGED! 1 RUN";
      runs = 1;
    } else if (p >= 0.82 && p <= 0.93) {
      runs = (Random().nextDouble() > 0.4) ? 6 : 4;
      outcome = runs == 6 ? "MAXIMUM! 🎆" : "CRACKING FOUR!";
      _hitEffectCtrl.forward(from: 0);
    } else {
      outcome = "BOWLED! ❌";
      runs = -1; // Wicket
    }

    _handleShot(score: runs, text: outcome);
  }

  void _handleShot({int score = 0, String text = "Missed!", bool missed = false}) {
    if (missed) { score = -1; text = "BOWLED! ❌"; }

    setState(() {
      _isBowling = false;
      _commentary = text;
      _overHistory.add(score == -1 ? "W" : "$score");
    });

    int currentScore = (widget.data['state']['p1Score'] ?? 0);
    int newScore = currentScore + (score == -1 ? 0 : score);

    Map<String, dynamic> update = {
      'p1Score': newScore,
      'ballsPlayed': _overHistory.length,
    };

    // WINNER LOGIC
    String? winner;
    if (_overHistory.length >= 6) {
      int target = widget.data['state']['p2Score'] ?? 20; // Default target 20
      winner = (newScore >= target) ? widget.controller.myId : 'AI';
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.controller.updateGame(update, mergeWinner: winner);
        if (_overHistory.length < 6 && winner == null) _startDelivery();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int p1Score = widget.data['state']['p1Score'] ?? 0;
    int target = (widget.data['state']['p2Score'] ?? 20);

    return ArcadeWrapper(
      title: "PRO CRICKET",
      instructions: "• Tap anywhere to swing when the ball enters the strike zone!\n• Watch for the ball's swing.\n• 6 Balls to reach the target score.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        children: [
          const SizedBox(height: 60),
          _buildScoreboard(p1Score, target),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 3),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: RealisticPitchPainter(ballProgress: _ballProgress))),
                  
                  // FULL FIELD TAP LAYER
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _attemptShot,
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                  // Commentary
                  Positioned(top: 20, left: 0, right: 0, child: Center(child: _buildCommentaryUI())),

                  // Ball
                  if (_isBowling && _ballDelivered)
                    Positioned(
                      top: 150 + (_ballProgress * 350), 
                      left: (MediaQuery.of(context).size.width / 2 - 10) + (_ballProgress * _ballHorizontalShift),
                      child: _buildBall(),
                    ),

                  // Batsman
                  Positioned(
                    bottom: 80, left: 0, right: 0,
                    child: Center(child: BatsmanCharacter(swingCtrl: _batCtrl)),
                  ),
                  
                  if (_hitEffectCtrl.isAnimating)
                    Center(child: ScaleTransition(scale: _hitEffectCtrl, child: const Icon(Icons.flash_on, color: Colors.yellowAccent, size: 100))),
                ],
              ),
            ),
          ),

          _buildOverDots(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCommentaryUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
      child: Text(_commentary, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildScoreboard(int score, int target) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.cyanAccent.withOpacity(0.5))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statCol("SCORE", "$score", Colors.white),
          _buildPill("BALLS: ${_overHistory.length}/6"),
          _statCol("TARGET", "$target", Colors.white70),
        ],
      ),
    );
  }

  Widget _statCol(String label, String val, Color col) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
      Text(val, style: TextStyle(color: col, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
    ]);
  }

  Widget _buildBall() {
    double size = 12 + (_ballProgress * 18);
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        color: Colors.red, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black, blurRadius: 4)]
      ),
      child: Center(child: Container(width: size, height: 2, color: Colors.white24)),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }

  Widget _buildOverDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        bool played = i < _overHistory.length;
        String val = played ? _overHistory[i] : "";
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 35, height: 35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: !played ? Colors.white10 : (val == "W" ? Colors.red : Colors.green),
            border: Border.all(color: played ? Colors.transparent : Colors.white24),
          ),
          child: Center(child: Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        );
      }),
    );
  }
}

class RealisticPitchPainter extends CustomPainter {
  final double ballProgress;
  RealisticPitchPainter({required this.ballProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height; final cx = w / 2;

    // Grass
    final grass = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), grass);

    // Perspective Pitch
    final pitchPaint = Paint()..color = const Color(0xFFE4C687);
    final path = Path();
    path.moveTo(cx - 50, h * 0.1); 
    path.lineTo(cx + 50, h * 0.1);
    path.lineTo(cx + 120, h * 0.95); 
    path.lineTo(cx - 120, h * 0.95);
    path.close();
    canvas.drawPath(path, pitchPaint);

    // Crease
    final linePaint = Paint()..color = Colors.white.withOpacity(0.8)..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 100, h * 0.88), Offset(cx + 100, h * 0.88), linePaint);

    // Strike Zone Visual
    final zonePaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.15 + (sin(ballProgress * 15).abs() * 0.2))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, h * 0.88), 45, zonePaint);
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BatsmanCharacter extends StatelessWidget {
  final AnimationController swingCtrl;
  const BatsmanCharacter({super.key, required this.swingCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100, height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Stumps
          Positioned(top: 0, child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => Container(width: 3, height: 35, margin: const EdgeInsets.symmetric(horizontal: 2), color: Colors.orange[300])))),
          // Body
          Positioned(top: 25, child: Container(width: 20, height: 35, decoration: BoxDecoration(color: Colors.blue[900], borderRadius: BorderRadius.circular(4)))),
          // Head
          Positioned(top: 5, child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.face, size: 14, color: Colors.white))),
          // Bat
          AnimatedBuilder(
            animation: swingCtrl,
            builder: (context, child) {
              double rotation = -0.4 + (swingCtrl.value * 2.8);
              return Transform.translate(
                offset: const Offset(15, 10), 
                child: Transform.rotate(
                  angle: rotation,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 10, height: 50,
                    decoration: BoxDecoration(color: const Color(0xFFD2B48C), border: Border.all(color: Colors.brown, width: 2), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}