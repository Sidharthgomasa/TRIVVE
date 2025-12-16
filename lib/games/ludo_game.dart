import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

// =============================================================================
// 🎲 ROYAL LUDO (Final Realistic Edition - 4 Player Ready)
// =============================================================================

class LudoGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const LudoGameUI({super.key, required this.data, required this.controller});

  @override
  State<LudoGameUI> createState() => _LudoGameUIState();
}

class _LudoGameUIState extends State<LudoGameUI> with TickerProviderStateMixin {
  late AnimationController _diceCtrl;
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _diceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _diceCtrl.dispose();
    super.dispose();
  }

  // --- LOGIC ---
  void _rollDice() {
    // Only allow roll if it's MY turn
    if (_isRolling || widget.data['state']['turn'] != widget.controller.myId) return;
    if (widget.data['state']['canRoll'] == false) return;

    setState(() => _isRolling = true);
    _diceCtrl.forward(from: 0).then((_) {
      setState(() => _isRolling = false);
      
      int result = Random().nextInt(6) + 1;
      
      // Get my tokens to see if I can move
      String myId = widget.controller.myId;
      List myTokens = [];
      
      // Determine which token list is mine based on Player ID
      if (myId == widget.data['host']) myTokens = List.from(widget.data['state']['p1Tokens']);
      else if (myId == widget.data['player2']) myTokens = List.from(widget.data['state']['p2Tokens']);
      else if (myId == widget.data['player3']) myTokens = List.from(widget.data['state']['p3Tokens'] ?? []);
      else if (myId == widget.data['player4']) myTokens = List.from(widget.data['state']['p4Tokens'] ?? []);
      else if (myId == 'P1') myTokens = List.from(widget.data['state']['p1Tokens']); // Local Fallback

      bool canMove = myTokens.any((t) => _canMove(t, result));

      Map<String, dynamic> update = {
        'dice': result,
        'canRoll': false,
      };

      if (!canMove) {
        // Simple 2-player pass logic (Expand for 4 players later if needed)
        // For now, we assume if you can't move, pass to P2/AI
        String nextPlayer = (widget.data['player2'] ?? 'AI'); 
        update['turn'] = nextPlayer;
        update['canRoll'] = true;
      }
      widget.controller.updateGame(update);
    });
  }

  void _moveToken(int index, String playerId) {
    if (widget.data['state']['turn'] != widget.controller.myId) return;
    if (widget.data['state']['canRoll']) return; 

    // Determine which list to update
    String fieldName = 'p1Tokens';
    if (playerId == widget.data['player2']) fieldName = 'p2Tokens';
    if (playerId == widget.data['player3']) fieldName = 'p3Tokens';
    if (playerId == widget.data['player4']) fieldName = 'p4Tokens';

    List tokens = List.from(widget.data['state'][fieldName]);
    int dice = widget.data['state']['dice'];
    int currentPos = tokens[index];

    if (!_canMove(currentPos, dice)) return;

    if (currentPos == 0) {
      tokens[index] = 1; 
    } else {
      tokens[index] += dice; 
    }

    bool won = tokens.every((t) => t >= 57);

    // Calculate Next Turn (Simple Toggle for P1/P2)
    String nextTurn = (widget.data['player2'] ?? 'AI');
    if (dice == 6) nextTurn = widget.controller.myId; // Roll again on 6

    widget.controller.updateGame({
      fieldName: tokens,
      'turn': nextTurn,
      'canRoll': true
    }, mergeWinner: won ? widget.controller.myId : null);
  }

  bool _canMove(int pos, int dice) {
    if (pos == 0) return dice == 6; 
    if (pos + dice > 57) return false; 
    return true;
  }

  @override
  Widget build(BuildContext context) {
    int diceVal = _isRolling ? (Random().nextInt(6) + 1) : (widget.data['state']['dice'] ?? 1);
    bool isMyTurn = widget.data['state']['turn'] == widget.controller.myId;
    
    // Safely get tokens
    List p1Tokens = widget.data['state']['p1Tokens'] ?? [0,0,0,0];
    List p2Tokens = widget.data['state']['p2Tokens'] ?? [0,0,0,0];
    List p3Tokens = widget.data['state']['p3Tokens'] ?? [0,0,0,0]; // Green
    List p4Tokens = widget.data['state']['p4Tokens'] ?? [0,0,0,0]; // Blue

    // Check who is playing
    String p1Id = widget.data['host'] ?? 'P1';
    String? p2Id = widget.data['player2'];
    String? p3Id = widget.data['player3'];
    String? p4Id = widget.data['player4'];

    double screenWidth = MediaQuery.of(context).size.width;
    double boardSize = min(screenWidth - 20, 380); 

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. THE BOARD FRAME
        Container(
          width: boardSize, height: boardSize,
          decoration: BoxDecoration(
            color: const Color(0xFF222222), 
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              const BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
              BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 2, spreadRadius: 1, offset: const Offset(-1, -1))
            ],
            border: Border.all(color: Colors.grey[800]!, width: 4)
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
               color: Colors.white, 
               child: Stack(
                 children: [
                   // A. The High-Def Board Painting
                   Positioned.fill(
                     child: CustomPaint(painter: RoyalLudoPainter()),
                   ),

                   // B. P1 Tokens (Red)
                   ...List.generate(4, (i) => _buildToken(p1Tokens[i], i, p1Id, 'P1', const Color(0xFFD32F2F), isMyTurn, boardSize)),

                   // C. P2 Tokens (Yellow)
                   if (p2Id != null || widget.data['player2'] == 'AI')
                     ...List.generate(4, (i) => _buildToken(p2Tokens[i], i, p2Id ?? 'AI', 'P2', const Color(0xFFFBC02D), false, boardSize)),

                   // D. P3 Tokens (Green)
                   if (p3Id != null)
                     ...List.generate(4, (i) => _buildToken(p3Tokens[i], i, p3Id, 'P3', const Color(0xFF43A047), false, boardSize)),

                   // E. P4 Tokens (Blue)
                   if (p4Id != null)
                     ...List.generate(4, (i) => _buildToken(p4Tokens[i], i, p4Id, 'P4', const Color(0xFF1E88E5), false, boardSize)),
                 ],
               ),
            ),
          ),
        ),

        const SizedBox(height: 30),

        // 2. CONTROLS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: isMyTurn ? _rollDice : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70, height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isMyTurn ? [Colors.redAccent, Colors.red[900]!] : [Colors.grey[400]!, Colors.grey[700]!],
                    begin: Alignment.topLeft, end: Alignment.bottomRight
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isMyTurn 
                    ? [BoxShadow(color: Colors.red.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 5))] 
                    : [const BoxShadow(color: Colors.black26, blurRadius: 5)],
                  border: Border.all(color: Colors.white24, width: 1)
                ),
                child: Center(
                  child: _isRolling 
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                    : _buildDiceFace(diceVal),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMyTurn ? "YOUR TURN" : "WAITING...", style: TextStyle(color: isMyTurn ? Colors.greenAccent : Colors.white54, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(widget.data['state']['canRoll'] ? "Tap dice to roll" : "Move a token", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            )
          ],
        ),
      ],
    );
  }

  // --- TOKEN RENDERER (Corrected) ---
  Widget _buildToken(int step, int index, String playerId, String playerSlot, Color color, bool interactive, double boardWidth) {
    // Get Grid Coordinates
    Offset pos = LudoPathMap.getPos(step, index, playerSlot);
    
    // Grid Math
    double cellSize = boardWidth / 15.0;
    double tokenSize = cellSize * 0.75; 
    
    double left = (pos.dx * cellSize) - (tokenSize / 2);
    double top = (pos.dy * cellSize) - (tokenSize / 2);

    int dice = widget.data['state']['dice'] ?? 0;
    
    // Only interactive if it's MY token and MY turn
    bool isMe = playerId == widget.controller.myId;
    bool highlight = isMe && interactive && _canMove(step, dice) && !widget.data['state']['canRoll'];

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      left: left, 
      top: top,
      width: tokenSize, height: tokenSize,
      child: GestureDetector(
        onTap: (highlight) ? () => _moveToken(index, playerId) : null,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(2, 2), blurRadius: 3),
               if (highlight) BoxShadow(color: color.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)
            ],
            gradient: RadialGradient(
              colors: [Colors.white.withOpacity(0.9), color, Colors.black.withOpacity(0.5)],
              stops: const [0.0, 0.5, 1.0],
              center: const Alignment(-0.3, -0.3), 
            ),
            border: Border.all(color: Colors.black12, width: 0.5)
          ),
          child: highlight 
            ? Center(child: Icon(Icons.keyboard_arrow_up, color: Colors.white, size: tokenSize * 0.8))
            : null,
        ),
      ),
    );
  }

  Widget _buildDiceFace(int val) {
    return SizedBox(
      width: 40, height: 40,
      child: CustomPaint(painter: DiceDotsPainter(val)),
    );
  }
}

// =============================================================================
// 🎨 ROYAL LUDO PAINTER
// =============================================================================
class RoyalLudoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double cell = w / 15;

    final Paint stroke = Paint()..style = PaintingStyle.stroke..color = Colors.black12..strokeWidth = 1;
    final Paint fill = Paint()..style = PaintingStyle.fill;
    
    final Color red = const Color(0xFFE53935);
    final Color green = const Color(0xFF43A047);
    final Color yellow = const Color(0xFFFDD835);
    final Color blue = const Color(0xFF1E88E5);

    // 1. Grid
    for (int i = 0; i <= 15; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, w), stroke);
      canvas.drawLine(Offset(0, i * cell), Offset(w, i * cell), stroke);
    }

    // 2. Bases
    _drawBase(canvas, 0, 9, cell, red);     // Red (Bottom-Left)
    _drawBase(canvas, 0, 0, cell, green);   // Green (Top-Left)
    _drawBase(canvas, 9, 0, cell, yellow);  // Yellow (Top-Right)
    _drawBase(canvas, 9, 9, cell, blue);    // Blue (Bottom-Right)

    // 3. Home Runs
    _drawStrip(canvas, cell, 6, 13, 1, -5, red);    
    _drawStrip(canvas, cell, 1, 6, 5, 1, green);    
    _drawStrip(canvas, cell, 8, 1, 1, 5, yellow);   
    _drawStrip(canvas, cell, 13, 8, -5, 1, blue);   

    // 4. Center
    _drawCenter(canvas, cell, red, green, yellow, blue);

    // 5. Start Arrows
    _drawArrow(canvas, cell, 1, 6, green);
    _drawArrow(canvas, cell, 8, 1, yellow);
    _drawArrow(canvas, cell, 13, 8, blue);
    _drawArrow(canvas, cell, 6, 13, red);
    
    // 6. Safe Spots
    _drawStar(canvas, cell, 2, 8);
    _drawStar(canvas, cell, 6, 2);
    _drawStar(canvas, cell, 12, 6);
    _drawStar(canvas, cell, 8, 12);
  }

  void _drawBase(Canvas canvas, int col, int row, double cell, Color color) {
    canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, 6 * cell, 6 * cell), Paint()..color = color);
    canvas.drawRect(Rect.fromLTWH((col+1)*cell, (row+1)*cell, 4*cell, 4*cell), Paint()..color = Colors.white);
    
    Paint circlePaint = Paint()..color = color;
    double r = cell / 2.5;
    List<Offset> centers = [
      Offset((col+1.5)*cell, (row+1.5)*cell),
      Offset((col+4.5)*cell, (row+1.5)*cell),
      Offset((col+1.5)*cell, (row+4.5)*cell),
      Offset((col+4.5)*cell, (row+4.5)*cell)
    ];
    for(var c in centers) {
      canvas.drawCircle(c, r, circlePaint);
      canvas.drawCircle(c, r, Paint()..color=Colors.black12..style=PaintingStyle.stroke..strokeWidth=1);
    }
  }

  void _drawStrip(Canvas canvas, double cell, int col, int row, int dx, int dy, Color color) {
    Paint p = Paint()..color = color;
    int c = col, r = row;
    for(int i=0; i<5; i++) {
      if (dx != 0) c = col + (dx > 0 ? i : -i);
      if (dy != 0) r = row + (dy > 0 ? i : -i);
      canvas.drawRect(Rect.fromLTWH(c*cell, r*cell, cell, cell), p);
    }
  }

  void _drawArrow(Canvas canvas, double cell, int col, int row, Color color) {
    canvas.drawRect(Rect.fromLTWH(col*cell, row*cell, cell, cell), Paint()..color=color);
    TextPainter tp = TextPainter(text: const TextSpan(text: "➤", style: TextStyle(fontSize: 14, color: Colors.white)), textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(col*cell + cell*0.2, row*cell + cell*0.2));
  }

  void _drawStar(Canvas canvas, double cell, int col, int row) {
    TextPainter tp = TextPainter(text: const TextSpan(text: "★", style: TextStyle(fontSize: 16, color: Colors.grey)), textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(col*cell + cell*0.2, row*cell + cell*0.1));
  }

  void _drawCenter(Canvas canvas, double cell, Color r, Color g, Color y, Color b) {
    double cx = 7.5 * cell;
    double cy = 7.5 * cell;
    Paint p = Paint()..style = PaintingStyle.fill;
    Path path = Path();

    p.color = r; path.reset(); path.moveTo(cx, cy); path.lineTo(6*cell, 9*cell); path.lineTo(9*cell, 9*cell); canvas.drawPath(path, p);
    p.color = g; path.reset(); path.moveTo(cx, cy); path.lineTo(6*cell, 6*cell); path.lineTo(6*cell, 9*cell); canvas.drawPath(path, p);
    p.color = y; path.reset(); path.moveTo(cx, cy); path.lineTo(6*cell, 6*cell); path.lineTo(9*cell, 6*cell); canvas.drawPath(path, p);
    p.color = b; path.reset(); path.moveTo(cx, cy); path.lineTo(9*cell, 6*cell); path.lineTo(9*cell, 9*cell); canvas.drawPath(path, p);
  }

  @override bool shouldRepaint(old) => false;
}

class DiceDotsPainter extends CustomPainter {
  final int val;
  DiceDotsPainter(this.val);
  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()..color = Colors.white;
    double r = size.width * 0.1;
    double c = size.width / 2;
    double q1 = size.width * 0.25;
    double q3 = size.width * 0.75;

    List<Offset> dots = [];
    if(val%2!=0) dots.add(Offset(c,c));
    if(val>1) { dots.add(Offset(q1,q1)); dots.add(Offset(q3,q3)); }
    if(val>3) { dots.add(Offset(q3,q1)); dots.add(Offset(q1,q3)); }
    if(val==6) { dots.add(Offset(q1,c)); dots.add(Offset(q3,c)); }
    
    for(var d in dots) {
      canvas.drawCircle(d, r, p);
      canvas.drawCircle(d, r, Paint()..style=PaintingStyle.stroke..color=Colors.black12..strokeWidth=0.5);
    }
  }
  @override bool shouldRepaint(old) => true;
}

// =============================================================================
// 🗺️ PATH MAP (Precise Centers for 4 Players)
// =============================================================================
class LudoPathMap {
  // Returns the CENTER of the grid cell
  static Offset getPos(int step, int tokenIndex, String playerSlot) {
    // 1. BASE POSITIONS
    if (step == 0) {
       if (playerSlot == 'P1') return _baseOffsets(1.5, 10.5)[tokenIndex]; // Red (Bottom Left)
       if (playerSlot == 'P2') return _baseOffsets(10.5, 1.5)[tokenIndex]; // Yellow (Top Right)
       if (playerSlot == 'P3') return _baseOffsets(1.5, 1.5)[tokenIndex];  // Green (Top Left)
       if (playerSlot == 'P4') return _baseOffsets(10.5, 10.5)[tokenIndex]; // Blue (Bottom Right)
    }

    // 2. PATH MAPPING
    int index = step - 1;
    
    // Offset logic relative to Red (P1)
    // Red starts at 0.
    // Green (P3) starts 13 steps ahead.
    // Yellow (P2) starts 26 steps ahead.
    // Blue (P4) starts 39 steps ahead.
    
    int shift = 0;
    if (playerSlot == 'P3') shift = 13;
    if (playerSlot == 'P2') shift = 26;
    if (playerSlot == 'P4') shift = 39;
    
    index = (index + shift) % 52; 
    
    // 3. HOME RUN LOGIC
    if (step > 51) { 
       int d = step - 51; 
       if (playerSlot == 'P1') return Offset(6.5, 13.5 - d); // Red Up
       if (playerSlot == 'P3') return Offset(1.5 + d, 6.5);  // Green Right
       if (playerSlot == 'P2') return Offset(8.5, 1.5 + d);  // Yellow Down
       if (playerSlot == 'P4') return Offset(13.5 - d, 8.5); // Blue Left
    }
    
    return _track[index];
  }

  static List<Offset> _baseOffsets(double cx, double cy) {
    return [
      Offset(cx, cy), Offset(cx+3, cy), Offset(cx, cy+3), Offset(cx+3, cy+3)
    ];
  }

  // The 52 Steps of the Main Loop (Starting from Red's Start going Clockwise)
  static final List<Offset> _track = [
    // Red Leg (Up)
    const Offset(6.5, 13.5), const Offset(6.5, 12.5), const Offset(6.5, 11.5), const Offset(6.5, 10.5), const Offset(6.5, 9.5),
    // Turn Left into Green Leg
    const Offset(5.5, 8.5), const Offset(4.5, 8.5), const Offset(3.5, 8.5), const Offset(2.5, 8.5), const Offset(1.5, 8.5), const Offset(0.5, 8.5),
    // Turn Up
    const Offset(0.5, 7.5), const Offset(0.5, 6.5),
    // Move Right (Green Home Run stretch)
    const Offset(1.5, 6.5), const Offset(2.5, 6.5), const Offset(3.5, 6.5), const Offset(4.5, 6.5), const Offset(5.5, 6.5),
    // Turn Up (Yellow Leg)
    const Offset(6.5, 5.5), const Offset(6.5, 4.5), const Offset(6.5, 3.5), const Offset(6.5, 2.5), const Offset(6.5, 1.5), const Offset(6.5, 0.5),
    // Turn Right
    const Offset(7.5, 0.5), const Offset(8.5, 0.5),
    // Turn Down
    const Offset(8.5, 1.5), const Offset(8.5, 2.5), const Offset(8.5, 3.5), const Offset(8.5, 4.5), const Offset(8.5, 5.5),
    // Turn Right (Blue Leg)
    const Offset(9.5, 6.5), const Offset(10.5, 6.5), const Offset(11.5, 6.5), const Offset(12.5, 6.5), const Offset(13.5, 6.5), const Offset(14.5, 6.5),
    // Turn Down
    const Offset(14.5, 7.5), const Offset(14.5, 8.5),
    // Turn Left
    const Offset(13.5, 8.5), const Offset(12.5, 8.5), const Offset(11.5, 8.5), const Offset(10.5, 8.5), const Offset(9.5, 8.5),
    // Turn Down (Red Leg return)
    const Offset(8.5, 9.5), const Offset(8.5, 10.5), const Offset(8.5, 11.5), const Offset(8.5, 12.5), const Offset(8.5, 13.5), const Offset(8.5, 14.5),
    // Turn Left to Start
    const Offset(7.5, 14.5), const Offset(6.5, 14.5)
  ];
}