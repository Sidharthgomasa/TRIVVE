import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

// =============================================================================
// 1. PRO CARROM (Realistic Physics & Controls)
// =============================================================================
class CarromGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const CarromGameUI({super.key, required this.data, required this.controller});

  @override
  State<CarromGameUI> createState() => _CarromGameUIState();
}

class _CarromGameUIState extends State<CarromGameUI> with TickerProviderStateMixin {
  List<CarromPiece> pieces = [];
  CarromPiece? striker;
  
  // Game State
  bool isMyTurn = false;
  bool isMoving = false;
  
  // Controls
  double strikerX = 0.5; // 0.0 to 1.0 along the baseline
  Offset? dragStart;
  Offset? dragCurrent;
  
  late AnimationController _loopCtrl;
  
  // Constants
  final double FRICTION = 0.985;
  final double WALL_BOUNCE = 0.7; // Lose energy on wall hit
  final double STOP_THRESHOLD = 0.0005;

  @override
  void initState() {
    super.initState();
    _resetBoard();
    _loopCtrl = AnimationController(vsync: this, duration: const Duration(hours: 1))
      ..addListener(_physicsLoop)
      ..forward();
  }

  void _resetBoard() {
    // 1. Striker (Locked to Baseline initially)
    striker = CarromPiece(x: 0.5, y: 0.82, r: 0.055, mass: 2.0, color: Colors.yellow[100]!, isStriker: true);
    
    // 2. Coins Setup (Standard Hexagon/Flower Pattern)
    pieces = [];
    double cx = 0.5;
    double cy = 0.5;
    double r = 0.035; // Coin radius
    
    // Center Queen (Red/Pink)
    pieces.add(CarromPiece(x: cx, y: cy, r: r, mass: 1.0, color: Colors.pinkAccent, type: 'queen'));
    
    // Inner Circle (6 coins)
    for (int i = 0; i < 6; i++) {
      double angle = i * (pi / 3);
      double dist = 0.075;
      pieces.add(CarromPiece(
        x: cx + cos(angle) * dist, 
        y: cy + sin(angle) * dist, 
        r: r, 
        mass: 1.0, 
        color: i % 2 == 0 ? Colors.white : Colors.black, 
        type: i % 2 == 0 ? 'white' : 'black'
      ));
    }
    
    // Outer Circle (12 coins)
    for (int i = 0; i < 12; i++) {
      double angle = i * (pi / 6);
      double dist = 0.145;
      pieces.add(CarromPiece(
        x: cx + cos(angle) * dist, 
        y: cy + sin(angle) * dist, 
        r: r, 
        mass: 1.0, 
        color: (i % 2 != 0) ? Colors.white : Colors.black, 
        type: (i % 2 != 0) ? 'white' : 'black'
      ));
    }
  }

  @override
  void dispose() {
    _loopCtrl.dispose();
    super.dispose();
  }

  // --- PHYSICS ENGINE ---
  void _physicsLoop() {
    if (!mounted) return;
    
    bool anyMoving = false;
    List<CarromPiece> all = [striker!, ...pieces];

    // 1. Movement & Wall Collision
    for (var p in all) {
      if (p.vx != 0 || p.vy != 0) {
        anyMoving = true;
        
        p.x += p.vx;
        p.y += p.vy;
        
        // Friction
        p.vx *= FRICTION;
        p.vy *= FRICTION;
        
        // Stop threshold
        if (p.vx.abs() + p.vy.abs() < STOP_THRESHOLD) {
          p.vx = 0; p.vy = 0;
        }

        // Wall Bounce (With energy loss)
        if (p.x - p.r < 0) { p.x = p.r; p.vx = -p.vx * WALL_BOUNCE; }
        if (p.x + p.r > 1) { p.x = 1 - p.r; p.vx = -p.vx * WALL_BOUNCE; }
        if (p.y - p.r < 0) { p.y = p.r; p.vy = -p.vy * WALL_BOUNCE; }
        if (p.y + p.r > 1) { p.y = 1 - p.r; p.vy = -p.vy * WALL_BOUNCE; }

        // Pockets
        if (_checkPocket(p)) {
          p.vx = 0; p.vy = 0;
          if (p.isStriker) {
            // Foul - Will reset in stop logic
            p.x = -10; // Hide temporarily
          } else {
            // Coin Potted
            pieces.remove(p);
            // Check Win
            if (pieces.isEmpty) widget.controller.updateGame({}, mergeWinner: widget.controller.myId);
            break; 
          }
        }
      }
    }

    // 2. Circle-Circle Collision
    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) {
        _resolveCollision(all[i], all[j]);
      }
    }

    // 3. State Management (Stop/Reset)
    if (isMoving != anyMoving) {
      setState(() => isMoving = anyMoving);
      
      // ✅ FIX: If movement JUST stopped, reset striker to baseline
      if (!isMoving) {
         striker!.vx = 0;
         striker!.vy = 0;
         striker!.x = strikerX; // Use the slider value
         striker!.y = 0.82;     // Lock Y to baseline
         
         // If it was AI's turn, pass back to player (Logic Placeholder)
         // In real play, turns toggle if no coin potted.
      }
    }
    
    if (anyMoving) setState(() {});
  }

  bool _checkPocket(CarromPiece p) {
    double pr = 0.06; 
    if (dist(p.x, p.y, 0, 0) < pr) return true;
    if (dist(p.x, p.y, 1, 0) < pr) return true;
    if (dist(p.x, p.y, 0, 1) < pr) return true;
    if (dist(p.x, p.y, 1, 1) < pr) return true;
    return false;
  }

  double dist(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  void _resolveCollision(CarromPiece p1, CarromPiece p2) {
    double dx = p2.x - p1.x;
    double dy = p2.y - p1.y;
    double distance = sqrt(dx*dx + dy*dy);
    
    if (distance < p1.r + p2.r) {
      double nx = dx / distance;
      double ny = dy / distance;
      double tx = -ny;
      double ty = nx;
      
      double dpTan1 = p1.vx * tx + p1.vy * ty;
      double dpTan2 = p2.vx * tx + p2.vy * ty;
      
      double dpNorm1 = p1.vx * nx + p1.vy * ny;
      double dpNorm2 = p2.vx * nx + p2.vy * ny;
      
      double m1 = (dpNorm1 * (p1.mass - p2.mass) + 2 * p2.mass * dpNorm2) / (p1.mass + p2.mass);
      double m2 = (dpNorm2 * (p2.mass - p1.mass) + 2 * p1.mass * dpNorm1) / (p1.mass + p2.mass);
      
      p1.vx = tx * dpTan1 + nx * m1;
      p1.vy = ty * dpTan1 + ny * m1;
      p2.vx = tx * dpTan2 + nx * m2;
      p2.vy = ty * dpTan2 + ny * m2;
      
      double overlap = (p1.r + p2.r - distance) / 2;
      p1.x -= overlap * nx; p1.y -= overlap * ny;
      p2.x += overlap * nx; p2.y += overlap * ny;
    }
  }

  // --- CONTROLS ---
  
  void _onSliderChanged(double val) {
    if (isMoving) return;
    setState(() {
      strikerX = val;
      striker!.x = val;
      // Clamp inside baseline
      if (striker!.x < 0.15) striker!.x = 0.15;
      if (striker!.x > 0.85) striker!.x = 0.85;
    });
  }

  void _onPanStart(DragStartDetails d) {
    if (isMoving || widget.data['winner'] != null) return;
    dragStart = d.localPosition;
    dragCurrent = d.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (dragStart != null) {
      setState(() => dragCurrent = d.localPosition);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (dragStart != null && dragCurrent != null) {
      double dx = dragStart!.dx - dragCurrent!.dx;
      double dy = dragStart!.dy - dragCurrent!.dy;
      
      double power = 0.0006; 
      
      if (dx.abs() > 150) dx = 150 * (dx.sign);
      if (dy.abs() > 150) dy = 150 * (dy.sign);

      striker!.vx = dx * power;
      striker!.vy = dy * power;
      
      // ✅ FIX: Ensure shot goes UP (cannot shoot backwards from baseline)
      if (striker!.vy > 0) striker!.vy = -0.01; 

      setState(() {
        isMoving = true;
        dragStart = null;
        dragCurrent = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canInteract = !isMoving && (widget.data['winner'] == null);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(isMoving ? "WAITING..." : "YOUR TURN", style: TextStyle(color: isMoving ? Colors.grey : Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        GestureDetector(
          onPanStart: canInteract ? _onPanStart : null,
          onPanUpdate: canInteract ? _onPanUpdate : null,
          onPanEnd: canInteract ? _onPanEnd : null,
          child: Container(
            width: 360, height: 360,
            decoration: BoxDecoration(
              color: const Color(0xFFE8DCCA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF5D4037), width: 12),
              boxShadow: [const BoxShadow(color: Colors.black54, blurRadius: 20)]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                painter: CarromBoardPainter(pieces, striker!, (dragStart != null), dragStart, dragCurrent),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (canInteract)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                const Text("POSITION STRIKER", style: TextStyle(color: Colors.white54, fontSize: 10)),
                Slider(
                  value: striker!.x,
                  min: 0.15, max: 0.85,
                  activeColor: Colors.yellow,
                  inactiveColor: Colors.grey[800],
                  onChanged: _onSliderChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CarromPiece {
  double x, y, r, mass;
  double vx = 0, vy = 0;
  Color color;
  bool isStriker;
  String type;
  CarromPiece({required this.x, required this.y, required this.r, required this.color, this.mass=1.0, this.isStriker=false, this.type=''});
}

class CarromBoardPainter extends CustomPainter {
  final List<CarromPiece> pieces;
  final CarromPiece striker;
  final bool isAiming;
  final Offset? dragStart, dragEnd;

  CarromBoardPainter(this.pieces, this.striker, this.isAiming, this.dragStart, this.dragEnd);

  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width;
    double h = size.height;
    Paint p = Paint();
    
    // 1. Pockets
    p.color = const Color(0xFF212121);
    double pr = w * 0.06;
    canvas.drawCircle(Offset(0,0), pr, p);
    canvas.drawCircle(Offset(w,0), pr, p);
    canvas.drawCircle(Offset(0,h), pr, p);
    canvas.drawCircle(Offset(w,h), pr, p);

    // 2. Baselines (Red & Black)
    _drawBaselines(canvas, w, h);

    // 3. Pieces
    for (var piece in pieces) _drawPiece(canvas, piece, size);

    // 4. Striker (Always draw on top)
    _drawPiece(canvas, striker, size);

    // 5. Aim Line
    if (isAiming && dragStart != null && dragEnd != null) {
      Paint aimPaint = Paint()..color=Colors.white.withOpacity(0.6)..strokeWidth=2..style=PaintingStyle.stroke;
      Paint dashPaint = Paint()..color=Colors.yellow.withOpacity(0.4)..strokeWidth=1..style=PaintingStyle.stroke;
      
      Offset sPos = Offset(striker.x * w, striker.y * h);
      double dx = dragStart!.dx - dragEnd!.dx;
      double dy = dragStart!.dy - dragEnd!.dy;
      
      // Draw pullback line
      canvas.drawLine(sPos, sPos - Offset(dx, dy), aimPaint);
      // Draw trajectory prediction
      canvas.drawLine(sPos, sPos + Offset(dx*2, dy*2), dashPaint);
    }
  }

  void _drawBaselines(Canvas canvas, double w, double h) {
    Paint lineP = Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.black87;
    double g = w * 0.14;
    
    // Player Baseline (Bottom)
    canvas.drawLine(Offset(g, h-g), Offset(w-g, h-g), lineP);
    canvas.drawLine(Offset(g, h-g*0.8), Offset(w-g, h-g*0.8), lineP);
    canvas.drawCircle(Offset(g, h-g*0.9), 6, Paint()..color=Colors.red..style=PaintingStyle.stroke);
    canvas.drawCircle(Offset(w-g, h-g*0.9), 6, Paint()..color=Colors.red..style=PaintingStyle.stroke);

    // Top Baseline
    canvas.drawLine(Offset(g, g), Offset(w-g, g), lineP);
    canvas.drawLine(Offset(g, g*0.8), Offset(w-g, g*0.8), lineP);
    
    // Center Design
    canvas.drawCircle(Offset(w/2, h/2), w*0.15, lineP..color=Colors.red.withOpacity(0.2)..style=PaintingStyle.fill);
    canvas.drawCircle(Offset(w/2, h/2), w*0.15, lineP..color=Colors.black..style=PaintingStyle.stroke);
  }

  void _drawPiece(Canvas canvas, CarromPiece p, Size size) {
    Offset center = Offset(p.x * size.width, p.y * size.height);
    double radius = p.r * size.width;

    // Shadow
    canvas.drawCircle(center + const Offset(2,2), radius, Paint()..color=Colors.black26..maskFilter=const MaskFilter.blur(BlurStyle.normal, 2));

    // Body
    canvas.drawCircle(center, radius, Paint()..color=p.color);
    // Detail
    canvas.drawCircle(center, radius * 0.8, Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.black12);
  }

  @override bool shouldRepaint(old) => true;
}

// ... TyperGameUI stays same below ...
class TyperGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;
  const TyperGameUI({super.key, required this.data, required this.controller});
  @override State<TyperGameUI> createState() => _TyperGameUIState();
}
class _TyperGameUIState extends State<TyperGameUI> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  List<FallingWord> words = [];
  int score = 0;
  bool isPlaying = false;
  Timer? _loop;
  final List<String> _vocab = ["FLUTTER", "CODE", "DART", "WIDGET", "DEBUG", "ASYNC", "FUTURE", "STREAM", "BUILD", "STATE", "NULL", "VOID"];
  @override void dispose() { _loop?.cancel(); _textCtrl.dispose(); _focus.dispose(); super.dispose(); }
  void _startGame() { setState(() { score = 0; words = []; isPlaying = true; }); _focus.requestFocus(); _loop = Timer.periodic(const Duration(milliseconds: 50), (t) { if (!mounted) return; setState(() { if (Random().nextInt(100) < 3) { words.add(FallingWord(text: _vocab[Random().nextInt(_vocab.length)], x: Random().nextDouble() * 0.8 + 0.1, y: -0.1)); } for (var w in words) { w.y += 0.003 + (score * 0.0001); } if (words.any((w) => w.y > 1.0)) { _gameOver(); } words.removeWhere((w) => w.y > 1.0); }); }); }
  void _checkInput(String val) { val = val.toUpperCase(); int idx = words.indexWhere((w) => w.text == val); if (idx != -1) { setState(() { words.removeAt(idx); score += 10; _textCtrl.clear(); }); } }
  void _gameOver() { _loop?.cancel(); setState(() => isPlaying = false); widget.controller.updateGame({'p1Score': score}, mergeWinner: widget.controller.myId); }
  @override Widget build(BuildContext context) { return Column(children: [Expanded(child: Stack(children: [Container(color: Colors.black87), if (!isPlaying) Center(child: ElevatedButton(onPressed: _startGame, child: const Text("START HACKING"))), Positioned(top: 20, right: 20, child: Text("SCORE: $score", style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold))), ...words.map((w) => Positioned(left: w.x * MediaQuery.of(context).size.width, top: w.y * 400, child: Text(w.text, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 18))))])), Container(padding: const EdgeInsets.all(10), color: Colors.grey[900], child: TextField(controller: _textCtrl, focusNode: _focus, onChanged: _checkInput, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 2), decoration: const InputDecoration(hintText: "TYPE TO DESTROY", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none)))] ); }
}
class FallingWord { String text; double x, y; FallingWord({required this.text, required this.x, required this.y}); }