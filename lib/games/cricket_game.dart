import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

// =============================================================================
// 🏏 REALISTIC CRICKET (Safe Mode)
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
  
  String _commentary = "MATCH STARTING...";
  bool _isBowling = false;
  bool _ballDelivered = false;
  double _ballProgress = 0.0; 
  
  List<String> _overHistory = [];

  @override
  void initState() {
    super.initState();
    _ballCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _ballCtrl.addListener(() {
      setState(() {
        _ballProgress = _ballCtrl.value;
        if (_ballProgress == 1.0 && _isBowling) _handleShot(missed: true);
      });
    });

    _batCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _hitEffectCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    
    if (_isMyBatting()) _startDelivery();
  }

  @override
  void didUpdateWidget(CricketGameUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Safe check for turn
    String turn = widget.data['state']['turn'] ?? '';
    if (turn == widget.controller.myId && !_isBowling) {
       _startDelivery();
    }
  }

  @override
  void dispose() {
    _ballCtrl.dispose();
    _batCtrl.dispose();
    _hitEffectCtrl.dispose();
    super.dispose();
  }

  bool _isMyBatting() {
    return widget.data['state']['turn'] == widget.controller.myId;
  }

  void _startDelivery() async {
    if (_isBowling || !_isMyBatting()) return;
    
    setState(() {
      _isBowling = true;
      _ballDelivered = false;
      _commentary = "Bowler running in...";
      _ballProgress = 0;
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    setState(() {
      _commentary = "Ball delivered!";
      _ballDelivered = true;
    });
    _ballCtrl.forward(from: 0);
  }

  void _attemptShot() {
    if (!_isBowling || !_ballDelivered) return;

    _batCtrl.forward(from: 0).then((_) => _batCtrl.reverse());
    
    double p = _ballProgress;
    _ballCtrl.stop(); 
    
    int runs = 0;
    String outcome = "";
    
    if (p < 0.6) {
      outcome = "Too Early! Missed!";
      runs = 0; 
    } else if (p < 0.8) {
      outcome = "Edged... 1 Run";
      runs = 1;
    } else if (p >= 0.8 && p <= 0.95) {
      if (Random().nextBool()) {
        outcome = "HUGE! SIX RUNS! 🎆";
        runs = 6;
      } else {
        outcome = "CRACKING SHOT! 4 RUNS";
        runs = 4;
      }
      _hitEffectCtrl.forward(from: 0);
    } else {
      outcome = "CLEAN BOWLED! ❌";
      runs = -1; 
    }

    _handleShot(score: runs, text: outcome);
  }

  void _handleShot({int score = 0, String text = "Missed!", bool missed = false}) {
    if (missed) {
      score = -1; text = "Too Late! Bowled!";
    }

    setState(() {
      _isBowling = false;
      _commentary = text;
      _overHistory.add(score == -1 ? "W" : "$score");
      if (_overHistory.length > 6) _overHistory.clear();
    });

    // ✅ SAFE INTEGER READING (The Fix)
    int currentScore = (widget.data['state']['p1Score'] ?? -1);
    if (currentScore == -1) currentScore = 0; // Normalize -1 to 0 for calculation

    Map<String, dynamic> update = {};
    
    if (score == -1) {
      update['turn'] = widget.data['player2'] ?? 'AI';
    } else {
      update['p1Score'] = currentScore + score;
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.controller.updateGame(update);
        if (_isMyBatting() && score != -1) _startDelivery();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ SAFE INTEGER READING (The Fix)
    // If database value is null, assume -1 (Not Started/Batting)
    int p1Score = widget.data['state']['p1Score'] ?? -1;
    int p2Score = widget.data['state']['p2Score'] ?? -1;
    
    String p1Text = p1Score == -1 ? "0" : "$p1Score";
    String p2Text = p2Score == -1 ? "0" : "$p2Score";

    return Column(
      children: [
        // SCOREBOARD
        Container(
          height: 80,
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.cyanAccent)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat("YOU", p1Text, Colors.yellow),
              const Text("VS", style: TextStyle(color: Colors.white24)),
              _buildStat("OPP", p2Text, Colors.redAccent),
            ],
          ),
        ),

        // STADIUM
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.green[800],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)] 
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: CricketFieldPainter())),
                
                Positioned(top: 20, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: Text(_commentary, style: const TextStyle(color: Colors.white, fontSize: 14))))),

                if (_isBowling && _ballDelivered)
                  Positioned(
                    top: 100 + (_ballProgress * 300), 
                    left: MediaQuery.of(context).size.width / 2 - 25,
                    child: Container(
                      width: 15, height: 15,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black, blurRadius: 2)]),
                    ),
                  ),

                Positioned(
                  bottom: 80,
                  left: 0, right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _attemptShot, 
                      child: BatsmanCharacter(swingCtrl: _batCtrl),
                    ),
                  ),
                ),
                
                if (_hitEffectCtrl.isAnimating)
                  Center(child: ScaleTransition(scale: _hitEffectCtrl, child: const Icon(Icons.star, color: Colors.yellowAccent, size: 80))),
                  
                const Positioned(
                  bottom: 20, left: 0, right: 0,
                  child: Center(child: Text("TAP PLAYER TO HIT", style: TextStyle(color: Colors.white54, fontSize: 12))),
                )
              ],
            ),
          ),
        ),

        // OVERS
        Container(
          height: 40,
          margin: const EdgeInsets.all(10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: _overHistory.map((s) => Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: s=="W"?Colors.red:Colors.blue, shape: BoxShape.circle), child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList()),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String score, Color c) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)), Text(score, style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold))]);
  }
}

// =============================================================================
// 🧍 THE ANIMATED BATSMAN WIDGET
// =============================================================================
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
          Positioned(
            top: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Container(width: 4, height: 40, margin: const EdgeInsets.symmetric(horizontal: 2), color: Colors.yellow[700])),
            ),
          ),
          
          Positioned(
            top: 30,
            child: Container(width: 20, height: 35, color: Colors.blue[800]),
          ),
          
          Positioned(
            top: 10,
            child: Container(
              width: 18, height: 18, 
              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              child: const Icon(Icons.face, size: 14, color: Colors.white),
            ),
          ),

          Positioned(top: 65, left: 35, child: Container(width: 8, height: 25, color: Colors.white)), 
          Positioned(top: 65, left: 57, child: Container(width: 8, height: 25, color: Colors.white)), 

          AnimatedBuilder(
            animation: swingCtrl,
            builder: (context, child) {
              double rotation = -0.5 + (swingCtrl.value * 2.5);
              return Transform.translate(
                offset: const Offset(15, 10), 
                child: Transform.rotate(
                  angle: rotation,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 10, height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2B48C), 
                      border: Border.all(color: Colors.brown),
                      borderRadius: BorderRadius.circular(2)
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(width: 4, height: 15, color: Colors.black), 
                    ),
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

class CricketFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width; final double h = size.height; final double cx = w / 2;
    Paint pitchPaint = Paint()..color = const Color(0xFFE4C687);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, h/2), width: w * 0.4, height: h * 0.7), pitchPaint);
    Paint linePaint = Paint()..color = Colors.white.withOpacity(0.8)..strokeWidth = 2..style = PaintingStyle.stroke;
    double topY = h * 0.2; double botY = h * 0.8;
    canvas.drawLine(Offset(cx - 40, topY), Offset(cx + 40, topY), linePaint);
    canvas.drawLine(Offset(cx - 40, botY), Offset(cx + 40, botY), linePaint);
    canvas.drawLine(Offset(cx - 60, topY), Offset(cx - 60, botY), linePaint);
    canvas.drawLine(Offset(cx + 60, topY), Offset(cx + 60, botY), linePaint);
    Paint grass = Paint()..color = Colors.black.withOpacity(0.05);
    for (double i = 0; i < h; i += 20) canvas.drawLine(Offset(0, i), Offset(w, i), grass);
  }
  @override bool shouldRepaint(old) => false;
}