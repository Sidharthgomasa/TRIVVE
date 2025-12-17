import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';
import 'package:trivve/games/arcade_wrapper.dart';

// =============================================================================
// 🎲 ROYAL LUDO (Realistic Edition - Capturing & Info Integrated)
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

  // --- DICE LOGIC ---
  void _rollDice() {
    if (_isRolling || widget.data['state']['turn'] != widget.controller.myId) return;
    if (widget.data['state']['canRoll'] == false) return;

    setState(() => _isRolling = true);
    _diceCtrl.forward(from: 0).then((_) {
      setState(() => _isRolling = false);
      int result = Random().nextInt(6) + 1;
      
      String myId = widget.controller.myId;
      List myTokens = (myId == widget.data['host'] || myId == 'P1') 
          ? List.from(widget.data['state']['p1Tokens']) 
          : List.from(widget.data['state']['p2Tokens']);

      bool canMove = myTokens.any((t) => _canMove(t, result));

      Map<String, dynamic> update = {'dice': result, 'canRoll': false};

      if (!canMove) {
        // Auto-pass turn if no moves possible
        update['turn'] = (widget.data['player2'] ?? 'AI');
        update['canRoll'] = true;
      }
      widget.controller.updateGame(update);
    });
  }

  // --- TOKEN MOVEMENT & CAPTURING ---
  void _moveToken(int index, String playerId) {
    if (widget.data['state']['turn'] != widget.controller.myId) return;
    if (widget.data['state']['canRoll']) return; 

    String myField = (playerId == widget.data['host'] || playerId == 'P1') ? 'p1Tokens' : 'p2Tokens';
    String oppField = (myField == 'p1Tokens') ? 'p2Tokens' : 'p1Tokens';

    List tokens = List.from(widget.data['state'][myField]);
    List oppTokens = List.from(widget.data['state'][oppField] ?? [0,0,0,0]);
    int dice = widget.data['state']['dice'];
    int currentPos = tokens[index];

    if (!_canMove(currentPos, dice)) return;

    // 1. Calculate New Position
    int nextPos = (currentPos == 0) ? 1 : currentPos + dice;
    tokens[index] = nextPos;

    // 2. Capture Logic (Kill opponent)
    bool didCapture = false;
    // Safe spots relative to track: 1, 9, 14, 22, 27, 35, 40, 48
    List safeSpots = [1, 9, 14, 22, 27, 35, 40, 48];
    
    if (nextPos <= 51 && !safeSpots.contains(nextPos)) {
      int globalPos = _getGlobalTrackPos(nextPos, myField);
      for (int i = 0; i < oppTokens.length; i++) {
        if (oppTokens[i] > 0 && oppTokens[i] <= 51) {
          int oppGlobal = _getGlobalTrackPos(oppTokens[i], oppField);
          if (globalPos == oppGlobal && !safeSpots.contains(oppTokens[i])) {
            oppTokens[i] = 0; // Send back to base
            didCapture = true;
          }
        }
      }
    }

    bool won = tokens.every((t) => t >= 57);
    String nextTurn = (dice == 6 || didCapture) ? widget.controller.myId : (widget.data['player2'] ?? 'AI');

    widget.controller.updateGame({
      myField: tokens,
      oppField: oppTokens,
      'turn': nextTurn,
      'canRoll': true
    }, mergeWinner: won ? widget.controller.myId : null);
  }

  int _getGlobalTrackPos(int pos, String field) {
    if (field == 'p1Tokens') return pos;
    return (pos + 26) % 52 == 0 ? 52 : (pos + 26) % 52;
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
    double boardSize = min(MediaQuery.of(context).size.width - 20, 380); 

    return ArcadeWrapper(
      title: "ROYAL LUDO",
      instructions: "• Roll a 6 to deploy a token.\n• Move all 4 tokens to the center Home to win.\n• Landing on an enemy token sends them back to base (unless on a ★ star).\n• Capturing a token or rolling a 6 gives an extra turn.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            width: boardSize, height: boardSize,
            decoration: BoxDecoration(
              color: const Color(0xFF222222), 
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[800]!, width: 4)
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: Colors.white, 
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: RoyalLudoPainter())),
                    ..._buildAllTokens(boardSize, isMyTurn),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildDiceUI(diceVal, isMyTurn),
        ],
      ),
    );
  }

  List<Widget> _buildAllTokens(double boardSize, bool isMyTurn) {
    List<Widget> list = [];
    Map s = widget.data['state'];
    
    // P1 - Red
    for(int i=0; i<4; i++) {
      list.add(_buildToken(s['p1Tokens'][i], i, widget.data['host'], 'P1', const Color(0xFFD32F2F), isMyTurn, boardSize));
    }
    // P2 - Yellow
    for(int i=0; i<4; i++) {
      list.add(_buildToken(s['p2Tokens'][i], i, widget.data['player2'] ?? 'AI', 'P2', const Color(0xFFFBC02D), false, boardSize));
    }
    return list;
  }

  Widget _buildToken(int step, int index, String playerId, String slot, Color color, bool interactive, double boardWidth) {
    Offset pos = LudoPathMap.getPos(step, index, slot);
    double cell = boardWidth / 15.0;
    double tSize = cell * 0.7; 
    
    bool isMe = playerId == widget.controller.myId;
    int dice = widget.data['state']['dice'] ?? 0;
    bool canMove = isMe && !widget.data['state']['canRoll'] && _canMove(step, dice);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      left: (pos.dx * cell) - (tSize / 2),
      top: (pos.dy * cell) - (tSize / 2),
      width: tSize, height: tSize,
      child: GestureDetector(
        onTap: canMove ? () => _moveToken(index, playerId) : null,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(2,2)),
              if (canMove) BoxShadow(color: color, blurRadius: 12, spreadRadius: 2)
            ],
            gradient: RadialGradient(colors: [Colors.white70, color, Colors.black26]),
            border: Border.all(color: Colors.black12)
          ),
          child: canMove ? const Icon(Icons.touch_app, color: Colors.white, size: 12) : null,
        ),
      ),
    );
  }

  Widget _buildDiceUI(int val, bool isMyTurn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: isMyTurn ? _rollDice : null,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: isMyTurn ? Colors.redAccent : Colors.grey,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)]
            ),
            child: Center(child: _isRolling ? const CircularProgressIndicator(color: Colors.white) : CustomPaint(size: const Size(30,30), painter: DiceDotsPainter(val))),
          ),
        ),
        const SizedBox(width: 20),
        Text(isMyTurn ? "YOUR TURN" : "WAITING...", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
      ],
    );
  }
}

// =============================================================================
// PAINTERS & MAPS
// =============================================================================

class RoyalLudoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cell = size.width / 15;
    final Paint p = Paint()..style = PaintingStyle.fill;
    
    _drawRect(canvas, 0, 0, 6, 6, const Color(0xFF43A047), cell); // Green
    _drawRect(canvas, 9, 0, 6, 6, const Color(0xFFFDD835), cell); // Yellow
    _drawRect(canvas, 0, 9, 6, 6, const Color(0xFFE53935), cell); // Red
    _drawRect(canvas, 9, 9, 6, 6, const Color(0xFF1E88E5), cell); // Blue
    
    // Home Stretches
    for(int i=1; i<6; i++) {
      _drawCell(canvas, i, 7, const Color(0xFF43A047), cell);
      _drawCell(canvas, 7, i, const Color(0xFFFDD835), cell);
      _drawCell(canvas, 14-i, 7, const Color(0xFF1E88E5), cell);
      _drawCell(canvas, 7, 14-i, const Color(0xFFE53935), cell);
    }
  }
  void _drawRect(Canvas canvas, double x, double y, double w, double h, Color c, double cell) {
    canvas.drawRect(Rect.fromLTWH(x*cell, y*cell, w*cell, h*cell), Paint()..color=c);
  }
  void _drawCell(Canvas canvas, int x, int y, Color c, double cell) {
    canvas.drawRect(Rect.fromLTWH(x*cell, y*cell, cell, cell), Paint()..color=c);
  }
  @override bool shouldRepaint(old) => false;
}



class LudoPathMap {
  static Offset getPos(int step, int index, String slot) {
    if (step == 0) {
      if (slot == 'P1') return [Offset(1.5, 10.5), Offset(4.5, 10.5), Offset(1.5, 13.5), Offset(4.5, 13.5)][index];
      return [Offset(10.5, 1.5), Offset(13.5, 1.5), Offset(10.5, 4.5), Offset(13.5, 4.5)][index];
    }
    if (step > 51) {
      int d = step - 51;
      if (slot == 'P1') return Offset(7.5, 14.5 - d);
      return Offset(7.5, 0.5 + d);
    }
    return _track[(step - 1 + (slot == 'P1' ? 0 : 26)) % 52];
  }

  static final List<Offset> _track = [
    Offset(6.5, 13.5), Offset(6.5, 12.5), Offset(6.5, 11.5), Offset(6.5, 10.5), Offset(6.5, 9.5),
    Offset(5.5, 8.5), Offset(4.5, 8.5), Offset(3.5, 8.5), Offset(2.5, 8.5), Offset(1.5, 8.5), Offset(0.5, 8.5),
    Offset(0.5, 7.5), Offset(0.5, 6.5), Offset(1.5, 6.5), Offset(2.5, 6.5), Offset(3.5, 6.5), Offset(4.5, 6.5), Offset(5.5, 6.5),
    Offset(6.5, 5.5), Offset(6.5, 4.5), Offset(6.5, 3.5), Offset(6.5, 2.5), Offset(6.5, 1.5), Offset(6.5, 0.5),
    Offset(7.5, 0.5), Offset(8.5, 0.5), Offset(8.5, 1.5), Offset(8.5, 2.5), Offset(8.5, 3.5), Offset(8.5, 4.5), Offset(8.5, 5.5),
    Offset(9.5, 6.5), Offset(10.5, 6.5), Offset(11.5, 6.5), Offset(12.5, 6.5), Offset(13.5, 6.5), Offset(14.5, 6.5),
    Offset(14.5, 7.5), Offset(14.5, 8.5), Offset(13.5, 8.5), Offset(12.5, 8.5), Offset(11.5, 8.5), Offset(10.5, 8.5), Offset(9.5, 8.5),
    Offset(8.5, 9.5), Offset(8.5, 10.5), Offset(8.5, 11.5), Offset(8.5, 12.5), Offset(8.5, 13.5), Offset(8.5, 14.5),
    Offset(7.5, 14.5), Offset(6.5, 14.5)
  ];
}

class DiceDotsPainter extends CustomPainter {
  final int val;
  DiceDotsPainter(this.val);
  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()..color = Colors.white;
    double c = size.width/2;
    if(val%2!=0) canvas.drawCircle(Offset(c,c), 3, p);
    if(val>1) { canvas.drawCircle(Offset(c-8,c-8), 3, p); canvas.drawCircle(Offset(c+8,c+8), 3, p); }
    if(val>3) { canvas.drawCircle(Offset(c+8,c-8), 3, p); canvas.drawCircle(Offset(c-8,c+8), 3, p); }
    if(val==6) { canvas.drawCircle(Offset(c-8,c), 3, p); canvas.drawCircle(Offset(c+8,c), 3, p); }
  }
  @override bool shouldRepaint(old) => true;
}