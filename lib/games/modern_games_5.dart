import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';
import 'package:trivve/games/arcade_wrapper.dart'; // Ensure this is imported

// =============================================================================
// 1. VAULT BREAKER (Guess Number)
// =============================================================================
class GuessNumberGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const GuessNumberGameUI({super.key, required this.data, required this.controller});

  @override
  State<GuessNumberGameUI> createState() => _GuessNumberGameUIState();
}

class _GuessNumberGameUIState extends State<GuessNumberGameUI> {
  double _currentVal = 50;

  void _submitGuess() {
    if (widget.data['winner'] != null) return;
    int guess = _currentVal.round();
    int target = widget.data['state']['target'];
    String res = guess == target ? "CORRECT" : (guess < target ? "LOW" : "HIGH");
    List guesses = List.from(widget.data['state']['guesses'] ?? []);
    guesses.add({'val': guess, 'res': res});

    String? winner;
    if (guess == target) winner = widget.controller.myId;

    widget.controller.updateGame({
      'guesses': guesses,
      'turn': (widget.data['player2'] ?? 'AI') 
    }, mergeWinner: winner);
  }

  @override
  Widget build(BuildContext context) {
    List guesses = widget.data['state']['guesses'] ?? [];
    Map<String, dynamic>? lastGuess = guesses.isNotEmpty ? guesses.last : null;
    bool isMyTurn = widget.data['state']['turn'] == widget.controller.myId;

    return ArcadeWrapper(
      title: "VAULT BREAKER",
      instructions: "• Guess the hidden security code between 1 and 100.\n• Use the slider to set your attempt.\n• Feedback will tell you if the code is 'HIGHER' or 'LOWER'.\n• Be the first to unlock the vault to win.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyanAccent, width: 4),
              boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 30)],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${_currentVal.round()}", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Courier')),
                  const Text("LOCKED", style: TextStyle(color: Colors.red, letterSpacing: 2)),
                ],
              ),
            ),
          ),
          if (lastGuess != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: lastGuess['res'] == 'CORRECT' ? Colors.green : (lastGuess['res'] == 'LOW' ? Colors.blue : Colors.red))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(lastGuess['res'] == 'LOW' ? Icons.arrow_upward : (lastGuess['res'] == 'HIGH' ? Icons.arrow_downward : Icons.check), color: Colors.white),
                  const SizedBox(width: 10),
                  Text("LAST: ${lastGuess['val']} WAS ${lastGuess['res']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const Spacer(),
          Slider(
            value: _currentVal, min: 1, max: 100, divisions: 99,
            activeColor: Colors.cyanAccent,
            onChanged: isMyTurn ? (v) => setState(() => _currentVal = v) : null,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isMyTurn ? _submitGuess : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
            child: Text(isMyTurn ? "ATTEMPT UNLOCK" : "WAITING...", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. NEON HANGMAN (System Failure)
// =============================================================================
class HangmanGameUI extends StatelessWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const HangmanGameUI({super.key, required this.data, required this.controller});

  void _guessLetter(String char) {
    if (data['winner'] != null || data['state']['turn'] != controller.myId) return;
    List guesses = List.from(data['state']['guesses']);
    if (guesses.contains(char)) return;
    guesses.add(char);
    String word = data['state']['word'];
    int wrongCount = guesses.where((g) => !word.contains(g)).length;
    bool won = word.split('').every((c) => guesses.contains(c));
    String? winner;
    if (won) winner = controller.myId;
    else if (wrongCount >= 6) winner = 'AI'; 
    controller.updateGame({'guesses': guesses, 'turn': 'AI'}, mergeWinner: winner);
  }

  @override
  Widget build(BuildContext context) {
    String word = data['state']['word'];
    List guesses = data['state']['guesses'];
    int wrongCount = guesses.where((g) => !word.contains(g)).length;
    
    return ArcadeWrapper(
      title: "HANGMAN",
      instructions: "• Guess the hidden word by picking letters.\n• Every wrong guess builds a part of the gallows.\n• 6 wrong guesses leads to System Failure.\n• Complete the word to bypass security.",
      data: data,
      controller: controller,
      gameUI: Column(
        children: [
          const SizedBox(height: 60),
          Expanded(flex: 3, child: CustomPaint(painter: NeonHangmanPainter(wrongCount), child: Container())),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: word.split('').map((char) {
                bool visible = guesses.contains(char);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: visible ? Colors.greenAccent : Colors.white24, width: 2))),
                  child: Text(visible ? char : " ", style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ),
          Expanded(
            flex: 4,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 5, runSpacing: 5,
              children: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split('').map((char) {
                bool used = guesses.contains(char);
                return GestureDetector(
                  onTap: used ? null : () => _guessLetter(char),
                  child: Container(
                    width: 35, height: 35,
                    decoration: BoxDecoration(
                      color: used ? Colors.white10 : Colors.grey[900],
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: used ? Colors.white24 : Colors.cyanAccent.withOpacity(0.3)),
                    ),
                    child: Center(child: Text(char, style: TextStyle(color: used ? Colors.white24 : Colors.white))),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}

class NeonHangmanPainter extends CustomPainter {
  final int mistakes;
  NeonHangmanPainter(this.mistakes);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.purpleAccent..style = PaintingStyle.stroke..strokeWidth = 3;
    var c = Offset(size.width / 2, size.height / 4);
    canvas.drawLine(Offset(size.width/2 - 40, size.height - 20), Offset(size.width/2 + 40, size.height - 20), paint);
    canvas.drawLine(Offset(size.width/2, size.height - 20), Offset(size.width/2, 20), paint);
    canvas.drawLine(Offset(size.width/2, 20), Offset(size.width/2 + 50, 20), paint);
    canvas.drawLine(Offset(size.width/2 + 50, 20), Offset(size.width/2 + 50, 40), paint);
    if (mistakes >= 1) canvas.drawCircle(Offset(size.width/2 + 50, 60), 15, paint);
    if (mistakes >= 2) canvas.drawLine(Offset(size.width/2 + 50, 75), Offset(size.width/2 + 50, 130), paint);
    if (mistakes >= 3) canvas.drawLine(Offset(size.width/2 + 50, 85), Offset(size.width/2 + 30, 110), paint);
    if (mistakes >= 4) canvas.drawLine(Offset(size.width/2 + 50, 85), Offset(size.width/2 + 70, 110), paint); 
    if (mistakes >= 5) canvas.drawLine(Offset(size.width/2 + 50, 130), Offset(size.width/2 + 35, 170), paint); 
    if (mistakes >= 6) canvas.drawLine(Offset(size.width/2 + 50, 130), Offset(size.width/2 + 65, 170), paint); 
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =============================================================================
// 3. DATA RACE (Math Sprint)
// =============================================================================
class MathSprintGameUI extends StatefulWidget {
  final Map<String, dynamic> data;
  final GameController controller;

  const MathSprintGameUI({super.key, required this.data, required this.controller});

  @override
  State<MathSprintGameUI> createState() => _MathSprintGameUIState();
}

class _MathSprintGameUIState extends State<MathSprintGameUI> {
  String _question = "READY?";
  int _answer = 0;
  int _score = 0;
  Timer? _timer;
  double _energy = 1.0;
  bool _isPlaying = false;

  void _startGame() {
    setState(() { _score = 0; _energy = 1.0; _isPlaying = true; _nextQuestion(); });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() {
        _energy -= 0.005 + (_score * 0.0005); 
        if (_energy <= 0) _gameOver();
      });
    });
  }

  void _nextQuestion() {
    int a = Random().nextInt(10 + _score) + 1;
    int b = Random().nextInt(10 + _score) + 1;
    bool isPlus = Random().nextBool();
    setState(() { _question = isPlus ? "$a + $b" : "$a * $b"; _answer = isPlus ? a + b : a * b; });
  }

  void _handleInput(int val) {
    if (!_isPlaying) return;
    if (val == _answer) {
      setState(() { _score++; _energy = (_energy + 0.15).clamp(0.0, 1.0); });
      _nextQuestion();
    } else { setState(() => _energy -= 0.2); }
  }

  void _gameOver() {
    _timer?.cancel();
    setState(() => _isPlaying = false);
    widget.controller.updateGame({'p1Score': _score}, mergeWinner: widget.controller.myId);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    List<int> options = [_answer];
    while (options.length < 4) {
      int fake = _answer + Random().nextInt(10) - 5;
      if (!options.contains(fake) && fake > 0) options.add(fake);
    }
    options.shuffle();

    return ArcadeWrapper(
      title: "MATH SPRINT",
      instructions: "• Solve equations as fast as possible to stay powered up.\n• Correct answers replenish your energy bar.\n• Wrong answers drain energy quickly.\n• Survive as long as you can to set a high score.",
      data: widget.data,
      controller: widget.controller,
      gameUI: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: LinearProgressIndicator(value: _energy, backgroundColor: Colors.white10, color: Colors.greenAccent),
          ),
          const SizedBox(height: 20),
          Text("SCORE: $_score", style: const TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent)),
            child: Text(_isPlaying ? _question : "GO!", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 40),
          if (!_isPlaying)
            ElevatedButton(onPressed: _startGame, child: const Text("START RACE"))
          else
            Wrap(
              spacing: 15, runSpacing: 15,
              children: options.map((opt) => SizedBox(
                width: 140, height: 60,
                child: ElevatedButton(onPressed: () => _handleInput(opt), child: Text("$opt", style: const TextStyle(fontSize: 22))),
              )).toList(),
            )
        ],
      ),
    );
  }
}