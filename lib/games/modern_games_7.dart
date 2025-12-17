import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';
import 'package:trivve/games/arcade_wrapper.dart';
import 'package:flutter/services.dart';

// =============================================================================
// PRO CARROM (Realistic Physics & Official Board Layout)
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
  bool isMoving = false;
  double strikerX = 0.5;
  Offset? dragStart;
  Offset? dragCurrent;
  late AnimationController _loopCtrl;

  final double FRICTION = 0.985;
  final double WALL_BOUNCE = 0.7;
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
    striker = CarromPiece(x: 0.5, y: 0.78, r: 0.055, mass: 2.0, color: Colors.amber[100]!, isStriker: true);
    pieces = [];
    _setupCoins();
  }

  void _setupCoins() {
    double cx = 0.5; double cy = 0.5; double r = 0.035;
    pieces.add(CarromPiece(x: cx, y: cy, r: r, mass: 1.1, color: Colors.pinkAccent, type: 'queen'));
    for (int i = 0; i < 6; i++) {
      double angle = i * (pi / 3);
      pieces.add(CarromPiece(x: cx + cos(angle) * 0.075, y: cy + sin(angle) * 0.075, r: r, color: i % 2 == 0 ? Colors.white : Colors.black87));
    }
    for (int i = 0; i < 12; i++) {
      double angle = i * (pi / 6);
      pieces.add(CarromPiece(x: cx + cos(angle) * 0.145, y: cy + sin(angle) * 0.145, r: r, color: (i % 2 != 0) ? Colors.white : Colors.black87));
    }
  }

  void _physicsLoop() {
    if (!mounted) return;
    bool anyMoving = false;
    List<CarromPiece> all = [striker!, ...pieces];

    for (var p in all) {
      if (p.vx != 0 || p.vy != 0) {
        anyMoving = true;
        p.x += p.vx; p.y += p.vy;
        p.vx *= FRICTION; p.vy *= FRICTION;

        if (_checkPocket(p)) {
          p.vx = 0; p.vy = 0;
          if (p.isStriker) { 
             _resetStriker(); 
          } else {
            String turn = widget.data['state']['turn'];
            bool p1Turn = (turn == widget.data['host']);
            bool correctColor = (p1Turn && p.color == Colors.white) || (!p1Turn && p.color == Colors.black87);

            if (correctColor || p.type == 'queen') {
               widget.controller.updateGame({'turn': turn});
            } else {
               widget.controller.updateGame({'turn': p1Turn ? 'AI' : widget.data['host']});
            }
            pieces.remove(p);
            break; 
          }
        }

        if (p.vx.abs() + p.vy.abs() < STOP_THRESHOLD) { p.vx = 0; p.vy = 0; }
        
        if (p.x - p.r < 0) { p.x = p.r; p.vx = -p.vx * WALL_BOUNCE; }
        if (p.x + p.r > 1) { p.x = 1 - p.r; p.vx = -p.vx * WALL_BOUNCE; }
        if (p.y - p.r < 0) { p.y = p.r; p.vy = -p.vy * WALL_BOUNCE; }
        if (p.y + p.r > 1) { p.y = 1 - p.r; p.vy = -p.vy * WALL_BOUNCE; }
      }
    }

    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) { _resolveCollision(all[i], all[j]); }
    }

    if (isMoving != anyMoving) {
      setState(() {
        isMoving = anyMoving;
        if (!isMoving) {
          striker!.vx = 0; striker!.vy = 0;
          striker!.x = strikerX; striker!.y = 0.78;
        }
      });
    }
    if (anyMoving) setState(() {});
  }

  void _resetStriker() {
    striker!.vx = 0; striker!.vy = 0;
    striker!.x = strikerX; striker!.y = 0.78;
  }

  bool _checkPocket(CarromPiece p) {
    double pr = 0.08;
    return (dist(p.x, p.y, 0, 0) < pr || dist(p.x, p.y, 1, 0) < pr || dist(p.x, p.y, 0, 1) < pr || dist(p.x, p.y, 1, 1) < pr);
  }

  double dist(double x1, double y1, double x2, double y2) => sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));

  void _resolveCollision(CarromPiece p1, CarromPiece p2) {
    double dx = p2.x - p1.x; double dy = p2.y - p1.y;
    double distance = sqrt(dx*dx + dy*dy);
    if (distance < p1.r + p2.r) {
      double nx = dx / distance; double ny = dy / distance;
      double tx = -ny; double ty = nx;
      double dpTan1 = p1.vx * tx + p1.vy * ty; double dpTan2 = p2.vx * tx + p2.vy * ty;
      double dpNorm1 = p1.vx * nx + p1.vy * ny; double dpNorm2 = p2.vx * nx + p2.vy * ny;
      double m1 = (dpNorm1 * (p1.mass - p2.mass) + 2 * p2.mass * dpNorm2) / (p1.mass + p2.mass);
      double m2 = (dpNorm2 * (p2.mass - p1.mass) + 2 * p1.mass * dpNorm1) / (p1.mass + p2.mass);
      p1.vx = tx * dpTan1 + nx * m1; p1.vy = ty * dpTan1 + ny * m1;
      p2.vx = tx * dpTan2 + nx * m2; p2.vy = ty * dpTan2 + ny * m2;
      double overlap = (p1.r + p2.r - distance) / 2;
      p1.x -= overlap * nx; p1.y -= overlap * ny; p2.x += overlap * nx; p2.y += overlap * ny;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeWrapper(
      title: "PRO CARROM",
      instructions: "• Use slider to position.\n• Drag back to aim.\n• P1 pots White, P2 pots Black.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          GestureDetector(
            onPanStart: (d) => !isMoving ? setState(() { dragStart = d.localPosition; dragCurrent = d.localPosition; }) : null,
            onPanUpdate: (d) => dragStart != null ? setState(() => dragCurrent = d.localPosition) : null,
            onPanEnd: (d) {
              if (dragStart != null && dragCurrent != null) {
                double dx = (dragStart!.dx - dragCurrent!.dx).clamp(-200.0, 200.0);
                double dy = (dragStart!.dy - dragCurrent!.dy).clamp(-200.0, 200.0);
                striker!.vx = dx * 0.0006; striker!.vy = dy * 0.0006;
                if (striker!.vy > 0) striker!.vy = -0.01; 
                setState(() { isMoving = true; dragStart = null; dragCurrent = null; });
              }
            },
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                color: const Color(0xFFD7B899),
                border: Border.all(color: const Color(0xFF4A2C2A), width: 12),
                boxShadow: [const BoxShadow(color: Colors.black54, blurRadius: 20)],
              ),
              child: CustomPaint(painter: CarromBoardPainter(pieces, striker!, dragStart, dragCurrent)),
            ),
          ),
          const SizedBox(height: 20),
          if (!isMoving) Slider(value: strikerX, min: 0.18, max: 0.82, activeColor: Colors.yellowAccent, 
             onChanged: (v) => setState(() { strikerX = v; striker!.x = v; })),
        ],
      ),
    );
  }
}

// Ensure you include your existing CarromPiece and CarromBoardPainter classes here too...
class CarromPiece {
  double x, y, r, mass, vx = 0, vy = 0; Color color; bool isStriker; String type;
  CarromPiece({required this.x, required this.y, required this.r, required this.color, this.mass=1.0, this.isStriker=false, this.type=''});
}

class CarromBoardPainter extends CustomPainter {
  final List<CarromPiece> pieces; final CarromPiece striker; final Offset? dragStart, dragEnd;
  CarromBoardPainter(this.pieces, this.striker, this.dragStart, this.dragEnd);

  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width; double h = size.height;
    _drawBoardDesign(canvas, w, h);
    for (var pc in pieces) { _drawPiece(canvas, pc, size, false); }
    _drawPiece(canvas, striker, size, true);

    if (dragStart != null && dragEnd != null) {
      Offset sPos = Offset(striker.x * w, striker.y * h);
      canvas.drawLine(sPos, sPos - (dragStart! - dragEnd!), Paint()..color=Colors.white70..strokeWidth=2);
    }
  }

  void _drawBoardDesign(Canvas canvas, double w, double h) {
    Paint p = Paint()..color = const Color(0xFF261414);
    // Pockets (Holes)
    canvas.drawCircle(const Offset(0,0), w*0.08, p);
    canvas.drawCircle(Offset(w,0), w*0.08, p);
    canvas.drawCircle(Offset(0,h), w*0.08, p);
    canvas.drawCircle(Offset(w,h), w*0.08, p);

    // Official Baselines
    Paint lineP = Paint()..style=PaintingStyle.stroke..strokeWidth=1.5..color=Colors.black54;
    canvas.drawLine(Offset(w*0.18, h*0.75), Offset(w*0.82, h*0.75), lineP);
    canvas.drawLine(Offset(w*0.18, h*0.81), Offset(w*0.82, h*0.81), lineP);
    // Red Circles on Baselines
    canvas.drawCircle(Offset(w*0.18, h*0.78), 6, Paint()..color=Colors.red);
    canvas.drawCircle(Offset(w*0.82, h*0.78), 6, Paint()..color=Colors.red);
  }

  void _drawPiece(Canvas canvas, CarromPiece p, Size size, bool isStriker) {
    Offset center = Offset(p.x * size.width, p.y * size.height);
    double radius = p.r * size.width;
    
    // Coin Reflection/Shadow
    canvas.drawCircle(center + const Offset(1, 2), radius, Paint()..color=Colors.black26);
    
    // Main Body
    canvas.drawCircle(center, radius, Paint()..color=p.color);
    
    // Inner Rings for Detail
    canvas.drawCircle(center, radius * 0.8, Paint()..style=PaintingStyle.stroke..color=Colors.black12);
    if (isStriker) {
      canvas.drawCircle(center, radius * 0.5, Paint()..style=PaintingStyle.stroke..color=Colors.black26);
    }
  }

  @override bool shouldRepaint(old) => true;
}
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
  final List<String> _vocab = ["FLUTTER", "CODE", "DART", "WIDGET", "DEBUG", "ASYNC", "STATE"];

  void _startGame() {
    setState(() { score = 0; words = []; isPlaying = true; }); 
    _focus.requestFocus();
    _loop = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) return;
      setState(() {
        if (Random().nextInt(100) < 4) {
          words.add(FallingWord(
            text: _vocab[Random().nextInt(_vocab.length)], 
            x: Random().nextDouble() * 0.7 + 0.1, 
            y: -0.1
          ));
        }
        for (var w in words) {
          w.y += 0.005 + (score * 0.0001);
        }
        if (words.any((w) => w.y > 0.9)) _gameOver();
        words.removeWhere((w) => w.y > 0.9);
      });
    });
  }

  void _checkInput(String val) {
    int idx = words.indexWhere((w) => w.text == val.toUpperCase());
    if (idx != -1) { 
      setState(() { words.removeAt(idx); score += 10; _textCtrl.clear(); }); 
    }
  }

  void _gameOver() { 
    _loop?.cancel(); 
    setState(() => isPlaying = false); 
    widget.controller.updateGame({'p1Score': score}, mergeWinner: widget.controller.myId); 
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeWrapper(
      title: "CYBER TYPER",
      instructions: "Type the falling words exactly to destroy them. If one hits the bottom, it's game over!",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (!isPlaying) Center(child: ElevatedButton(onPressed: _startGame, child: const Text("START"))),
                ...words.map((w) => Positioned(
                  left: w.x * MediaQuery.of(context).size.width, 
                  top: w.y * MediaQuery.of(context).size.height * 0.7, 
                  child: Text(w.text, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 20))
                )),
              ],
            ),
          ),
          TextField(controller: _textCtrl, focusNode: _focus, onChanged: _checkInput),
        ],
      ),
    );
  }
}

class FallingWord { String text; double x, y; FallingWord({required this.text, required this.x, required this.y}); }