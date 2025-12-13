import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math'; // 👈 Add this line!

// --- NAVIGATION IMPORTS ---
import 'package:trivve/gamepage.dart'; // 👈 LINKS TO NEW GAMES
import 'package:trivve/trrive_map_module.dart';
import 'package:trivve/trrive_yearbook.dart'; 
import 'package:trivve/trrive_echo_module.dart'; 
import 'package:trivve/trrive_squad_module.dart';
// Note: Ensure trrive_cricket_module.dart is imported inside ToolboxScreen if used directly, 
// or you can import it here if needed for the toolbox navigation below.
import 'package:trivve/trrive_cricket_module.dart'; 

// =============================================================================
// 1. HOME SCREEN (THE HUB)
// =============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? _currentUser;
  bool _isLoggingIn = false; 

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) setState(() => _currentUser = user);
    });
  }

  // 🔐 LOGIN LOGIC
  Future<void> _handleLogin() async {
    setState(() => _isLoggingIn = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
        setState(() => _isLoggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛑 STATE 1: NOT LOGGED IN
    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              const Text("TRIVVE OS LOCKED", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3)),
              const SizedBox(height: 10),
              const Text("Identity verification required.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              
              if (_isLoggingIn)
                const CircularProgressIndicator(color: Colors.cyanAccent)
              else
                ElevatedButton.icon(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                  ),
                  icon: const Icon(Icons.power, color: Colors.black),
                  label: const Text("JACK IN (LOGIN)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
            ],
          ),
        ),
      );
    }

    // ✅ STATE 2: LOGGED IN (SHOW HUB)
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("ＴＲＩＶＶＥ", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 24, color: Colors.cyanAccent)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TheYearbookScreen())),
              child: CircleAvatar(
                backgroundImage: _currentUser!.photoURL != null ? NetworkImage(_currentUser!.photoURL!) : null,
                backgroundColor: Colors.grey[800],
                radius: 15,
                child: _currentUser!.photoURL == null ? const Icon(Icons.person, size: 15, color: Colors.white) : null,
              ),
            ),
          )
        ],
      ),
      
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          String bio = "Ready to play!";
          int wins = 0;
          int xp = 0;

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            bio = data['bio'] ?? bio;
            wins = data['wins'] ?? 0;
            xp = data['xp'] ?? 0;
          }

          int level = (xp / 500).floor() + 1; 

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- CLICKABLE PROFILE HEADER ---
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TheYearbookScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 10)]
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: _currentUser!.photoURL != null ? NetworkImage(_currentUser!.photoURL!) : null,
                            backgroundColor: Colors.black,
                            child: _currentUser!.photoURL == null ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("HELLO, ${_currentUser?.displayName?.split(' ')[0].toUpperCase() ?? 'NOMAD'}", 
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                                const SizedBox(height: 5),
                                Text(bio, style: const TextStyle(color: Colors.cyanAccent, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16)
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // --- STATS BAR ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.purpleAccent.withOpacity(0.2), Colors.blueAccent.withOpacity(0.2)]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem("LEVEL", "$level", Colors.yellowAccent),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _statItem("WINS", "$wins", Colors.cyanAccent),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _statItem("AURA", "$xp", Colors.purpleAccent),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // --- NAVIGATION CARDS ---
                  _dashboardCard("TOOLBOX", "Utilities for hangouts", Icons.handyman_outlined, [Colors.grey[800]!, Colors.grey[900]!],
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ToolboxScreen()))),
                  
                  const SizedBox(height: 15),
                  
                  _dashboardCard("LIVE EVENTS", "Find active Trivves", Icons.map_outlined, [Colors.cyanAccent, Colors.blueAccent],
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrriveNeonMap()))),
                  
                  const SizedBox(height: 15),
                  
                  _dashboardCard("ARCADE", "10 Multiplayer Games", Icons.gamepad_outlined, [Colors.purpleAccent, Colors.deepPurple],
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GameLobby()))), // 👈 LINKS TO NEW GAMEPAGE.DART
                  
                  const SizedBox(height: 15),

                  _dashboardCard("THE PULSE", "Global Vibe Check", Icons.bolt, [Colors.pinkAccent, Colors.orangeAccent],
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PulseScreen()))),

                  const SizedBox(height: 15), 

                  _dashboardCard("THE SQUAD", "Map • Plot • Rank", Icons.groups, [Colors.indigo, Colors.blueAccent],
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SquadScreen()))),
                  
                  const SizedBox(height: 15),

                  _dashboardCard("THE ECHO", "Location Secrets", Icons.spatial_audio_off, [Colors.teal, Colors.tealAccent],
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EchoScreen()))),

                  const SizedBox(height: 20),
                  
                  // YEARBOOK LINK (Bottom)
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TheYearbookScreen())),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.amber[900]!, Colors.black]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                        boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 10)]
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text("THE YEARBOOK 🆔", style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                           Icon(Icons.arrow_forward, color: Colors.amberAccent)
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _dashboardCard(String title, String sub, IconData icon, List<Color> colors, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            height: 100, 
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: colors[0].withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Stack(children: [
              Positioned(right: -10, bottom: -10, child: Icon(icon, size: 100, color: Colors.white.withOpacity(0.10))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                  child: Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon, color: Colors.white, size: 24)),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12))
                          ],
                        )
                      ]))
            ])));
  }
}

// =============================================================================
// 2. THE PULSE (SOCIAL FEED)
// =============================================================================

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});
  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  final TextEditingController _vibeController = TextEditingController();

  void _postVibe() {
    if (_vibeController.text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    FirebaseFirestore.instance.collection('pulse').add({
      'text': _vibeController.text,
      'uid': user?.uid,
      'author': user?.displayName ?? 'Anon',
      'avatar': user?.photoURL,
      'timestamp': FieldValue.serverTimestamp(),
      'expiry': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
    });
    _vibeController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("THE PULSE ⚡"), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vibeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Drop a vibe...",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20)
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(onPressed: _postVibe, icon: const Icon(Icons.send), style: IconButton.styleFrom(backgroundColor: Colors.pinkAccent))
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pulse')
                  .where('expiry', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
                  .orderBy('expiry', descending: true) 
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                var docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("Dead silence...", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: data['avatar'] != null ? NetworkImage(data['avatar']) : null,
                          backgroundColor: Colors.grey[800],
                          child: data['avatar'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(data['author'], style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                        subtitle: Text(data['text'], style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// =============================================================================
// 3. UTILITIES & TOOLBOX
// =============================================================================

class ToolboxScreen extends StatelessWidget {
  const ToolboxScreen({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("TOOLBOX"), backgroundColor: Colors.black, foregroundColor: Colors.white), 
      body: GridView.count(crossAxisCount: 2, padding: const EdgeInsets.all(20), crossAxisSpacing: 15, mainAxisSpacing: 15, children: [
          _toolCard(context, "Sports Board", Icons.sports_cricket, Colors.orange, const TrriveProScorecard()), 
          _toolCard(context, "Neon Splitter", Icons.attach_money, Colors.greenAccent, const NeonSplitterTool()), // No const!
          _toolCard(context, "Quantum Decider", Icons.casino, Colors.purpleAccent, const DecisionMakerTool()),   // No const!
          _toolCard(context, "Hyper Focus", Icons.timer, Colors.blueAccent, const HyperFocusTool()),             // No const!
          // Inside ToolboxScreen -> build -> GridView children:
          _toolCard(context, "Spin The Bottle", Icons.wine_bar, Colors.pinkAccent, const SpinTheBottleTool()),
          _toolCard(context, "The Jury", Icons.gavel, Colors.amberAccent, const TheJuryTool()),
    ]));
  }
  Widget _toolCard(BuildContext context, String title, IconData icon, Color color, Widget destination) => GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)), child: Container(decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 40, color: color), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))])));
}
// =============================================================================
// 3.1. ⏳ HYPER FOCUS (Custom Timer)
// =============================================================================

class HyperFocusTool extends StatefulWidget {
  const HyperFocusTool({super.key});
  @override
  State<HyperFocusTool> createState() => _HyperFocusToolState();
}

class _HyperFocusToolState extends State<HyperFocusTool> {
  final TextEditingController _inputCtrl = TextEditingController(text: "25"); // Default 25 min
  Timer? _timer;
  int _totalSeconds = 1500;
  int _currentSeconds = 1500;
  bool _isRunning = false;
  bool _isFinished = false;

  @override
  void dispose() {
    _timer?.cancel();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    // Hide keyboard if open
    FocusScope.of(context).unfocus();

    if (!_isRunning) {
      // If we are at the start (or finished), parse the input to set time
      if (_currentSeconds == _totalSeconds || _isFinished) {
        int mins = int.tryParse(_inputCtrl.text) ?? 25;
        setState(() {
          _totalSeconds = mins * 60;
          _currentSeconds = _totalSeconds;
          _isFinished = false;
        });
      }

      setState(() => _isRunning = true);

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_currentSeconds > 0) {
          setState(() => _currentSeconds--);
        } else {
          _complete();
        }
      });
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    // Reset to whatever is in the text box
    int mins = int.tryParse(_inputCtrl.text) ?? 25;
    setState(() {
      _isRunning = false;
      _isFinished = false;
      _totalSeconds = mins * 60;
      _currentSeconds = _totalSeconds;
    });
  }

  void _complete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isFinished = true;
    });
    // Optional: Add sound or vibration here
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    double progress = _totalSeconds == 0 ? 0 : (_currentSeconds / _totalSeconds);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("HYPER FOCUS"), 
        backgroundColor: Colors.grey[900], 
        foregroundColor: Colors.blueAccent
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            // --- ⏳ TIMER VISUAL ---
            Stack(
              alignment: Alignment.center,
              children: [
                // Background Circle
                SizedBox(
                  width: 280, height: 280,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 15,
                    color: Colors.grey[900],
                  ),
                ),
                // Active Progress Circle
                SizedBox(
                  width: 280, height: 280,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 15,
                    color: _isFinished ? Colors.greenAccent : Colors.blueAccent,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                // Digital Time Display
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isFinished ? "COMPLETE" : (_isRunning ? "FOCUSING" : "READY"),
                      style: TextStyle(
                        color: _isFinished ? Colors.green : Colors.grey, 
                        letterSpacing: 2, 
                        fontSize: 12
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatTime(_currentSeconds),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 60, 
                        fontFamily: 'Courier', 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 50),

            // --- ⌨️ INPUT FIELD (Only editable when stopped) ---
            if (!_isRunning && !_isFinished)
              Column(
                children: [
                  const Text("SET DURATION (MINUTES)", style: TextStyle(color: Colors.grey, fontSize: 10)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _inputCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true, fillColor: Colors.grey[900],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        hintText: "25",
                        hintStyle: TextStyle(color: Colors.grey[600])
                      ),
                      onChanged: (val) {
                        // Update the display immediately as user types
                        int mins = int.tryParse(val) ?? 0;
                        setState(() {
                          _totalSeconds = mins * 60;
                          _currentSeconds = _totalSeconds;
                        });
                      },
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 40),

            // --- 🎛️ CONTROLS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // START / PAUSE
                if (!_isFinished)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: (_isRunning ? Colors.amber : Colors.blueAccent).withOpacity(0.3), blurRadius: 20)]
                    ),
                    child: IconButton(
                      iconSize: 80,
                      icon: Icon(
                        _isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: _isRunning ? Colors.amber : Colors.blueAccent,
                      ),
                      onPressed: _isRunning ? _pauseTimer : _startTimer,
                    ),
                  ),
                
                // RESET
                if (_currentSeconds != _totalSeconds || _isFinished) ...[
                  const SizedBox(width: 30),
                  IconButton(
                    iconSize: 60,
                    icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                    onPressed: _resetTimer,
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3.2. 🍾 SPIN THE BOTTLE (Precision Edition)
// =============================================================================

class SpinTheBottleTool extends StatefulWidget {
  const SpinTheBottleTool({super.key});

  @override
  State<SpinTheBottleTool> createState() => _SpinTheBottleToolState();
}

class _SpinTheBottleToolState extends State<SpinTheBottleTool> with SingleTickerProviderStateMixin {
  int _playerCount = 4;
  double _bottleAngle = 0;
  int? _selectedPlayerIndex;
  bool _isSpinning = false;
  late AnimationController _spinCtrl;
  late Animation<double> _spinAnimation;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _spin() {
    setState(() {
      _isSpinning = true;
      _selectedPlayerIndex = null;
    });

    Random rnd = Random();
    
    // 1. Pick the Winner randomly first
    int winnerIndex = rnd.nextInt(_playerCount);

    // 2. Calculate the exact angle for that player
    // Player 0 is at 0 degrees (Top/12 o'clock relative to bottle). 
    // Players are spaced by (2 * pi / count).
    double segment = (2 * pi) / _playerCount;
    double targetRotation = winnerIndex * segment;

    // 3. Add 5-8 full spins for effect
    int fullSpins = 5 + rnd.nextInt(3);
    double spinAmount = (fullSpins * 2 * pi) + targetRotation;

    // 4. Ensure smooth continuation from current angle
    // We remove the current modulus to find the "base" 0, then add our target.
    double currentMod = _bottleAngle % (2 * pi);
    double adjustment = targetRotation - currentMod;
    if (adjustment < 0) adjustment += (2 * pi); // Always rotate forward
    
    double finalAngle = _bottleAngle + adjustment + (fullSpins * 2 * pi);

    _spinAnimation = Tween<double>(begin: _bottleAngle, end: finalAngle).animate(
      CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOutCirc) // Stops sharply
    );

    _spinCtrl.forward(from: 0).whenComplete(() {
      setState(() {
        _isSpinning = false;
        _bottleAngle = finalAngle;
        _selectedPlayerIndex = winnerIndex;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("SPIN THE BOTTLE"), backgroundColor: Colors.grey[900], foregroundColor: Colors.pinkAccent),
      body: Column(
        children: [
          // 🎛️ CONTROLS
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[900],
            child: Column(
              children: [
                const Text("SQUAD SIZE", style: TextStyle(color: Colors.grey, letterSpacing: 1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.remove_circle, color: Colors.pinkAccent), onPressed: _isSpinning || _playerCount <= 2 ? null : () => setState(() => _playerCount--)),
                    Text(" $_playerCount ", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.pinkAccent), onPressed: _isSpinning || _playerCount >= 12 ? null : () => setState(() => _playerCount++)),
                  ],
                ),
              ],
            ),
          ),

          // 🍾 GAME AREA
          Expanded(
            child: Center(
              child: SizedBox(
                width: 320, height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // --- PLAYERS (CIRCLE) ---
                    ...List.generate(_playerCount, (index) {
                      // Place players starting from 12 o'clock (Top)
                      double angle = (2 * pi * index) / _playerCount - (pi / 2);
                      double radius = 140;
                      double x = radius * cos(angle);
                      double y = radius * sin(angle);
                      
                      bool isWinner = _selectedPlayerIndex == index;

                      return Transform.translate(
                        offset: Offset(x, y),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isWinner ? 60 : 40,
                          height: isWinner ? 60 : 40,
                          decoration: BoxDecoration(
                            color: isWinner ? Colors.pinkAccent : Colors.grey[900],
                            shape: BoxShape.circle,
                            border: Border.all(color: isWinner ? Colors.white : Colors.grey, width: 2),
                            boxShadow: isWinner ? [const BoxShadow(color: Colors.pinkAccent, blurRadius: 30, spreadRadius: 5)] : []
                          ),
                          child: Center(child: Text("P${index + 1}", style: TextStyle(color: isWinner ? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
                        ),
                      );
                    }),

                    // --- THE BOTTLE & POINTER ---
                    AnimatedBuilder(
                      animation: _spinCtrl,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _isSpinning ? _spinAnimation.value : _bottleAngle,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // The Bottle Icon
                              const Icon(Icons.wine_bar, size: 120, color: Colors.cyanAccent),
                              
                              // The "Sharp" Neck Pointer (Red Triangle)
                              Positioned(
                                top: 0,
                                child: Container(
                                  width: 20, height: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle, // Using circle as a precise "dot" tip
                                    boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 10)]
                                  ),
                                  child: const Icon(Icons.keyboard_arrow_up, size: 20, color: Colors.black),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ▶️ SPIN BUTTON
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSpinning ? null : _spin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 10,
                  shadowColor: Colors.pinkAccent.withOpacity(0.5)
                ),
                child: Text(_isSpinning ? "CALCULATING..." : "SPIN BOTTLE", style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
// =============================================================================
// 3.3. ⚖️ THE JURY (Cyberpunk Polling System)
// =============================================================================

class TheJuryTool extends StatefulWidget {
  const TheJuryTool({super.key});

  @override
  State<TheJuryTool> createState() => _TheJuryToolState();
}

class _TheJuryToolState extends State<TheJuryTool> {
  // Navigation State
  String _view = 'menu'; // menu, create, join, live, vote
  String? _activePollId;
  bool _isHost = false;

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case 'create': return _JuryCreationScreen(onCancel: () => setState(() => _view = 'menu'), onLaunch: (id) => setState(() { _activePollId = id; _isHost = true; _view = 'live'; }));
      case 'join': return _JuryJoinScreen(onCancel: () => setState(() => _view = 'menu'), onJoin: (id, hasVoted) => setState(() { _activePollId = id; _isHost = false; _view = hasVoted ? 'live' : 'vote'; }));
      case 'live': return _JuryLiveResultsScreen(pollId: _activePollId!, isHost: _isHost, onExit: () => setState(() => _view = 'menu'));
      case 'vote': return _JuryVotingScreen(pollId: _activePollId!, onVoted: () => setState(() => _view = 'live'));
      default: return _buildMenu();
    }
  }

  Widget _buildMenu() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("THE JURY ⚖️"), backgroundColor: Colors.grey[900], foregroundColor: Colors.amberAccent),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gavel, size: 80, color: Colors.amberAccent),
            const SizedBox(height: 20),
            const Text("CROWD VERDICT SYSTEM", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 10),
            const Text("Resolve disputes via democratic protocol.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 50),
            
            _neonButton("CREATE NEW CASE", Icons.add_circle_outline, () => setState(() => _view = 'create')),
            const SizedBox(height: 20),
            _neonButton("JOIN JURY (ENTER CODE)", Icons.qr_code_scanner, () => setState(() => _view = 'join')),
          ],
        ),
      ),
    );
  }

  Widget _neonButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.amberAccent.withOpacity(0.1),
          border: Border.all(color: Colors.amberAccent),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.amberAccent.withOpacity(0.2), blurRadius: 10)]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.amberAccent),
            const SizedBox(width: 15),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// A. CREATION SCREEN (IMPROVED)
// -----------------------------------------------------------------------------
class _JuryCreationScreen extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(String) onLaunch;
  const _JuryCreationScreen({required this.onCancel, required this.onLaunch});

  @override
  State<_JuryCreationScreen> createState() => _JuryCreationScreenState();
}

class _JuryCreationScreenState extends State<_JuryCreationScreen> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionsCtrl = [TextEditingController(), TextEditingController()]; 
  bool _isCreating = false; // Loading state

  void _addOption() {
    if (_optionsCtrl.length < 5) setState(() => _optionsCtrl.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionsCtrl.length > 2) setState(() => _optionsCtrl.removeAt(index));
  }

  void _launch() async {
    // 1. Validation
    if (_questionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a question!")));
      return;
    }
    if (_optionsCtrl.any((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill in all options!")));
      return;
    }

    setState(() => _isCreating = true);

    try {
      String code = String.fromCharCodes(Iterable.generate(4, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(32))));
      
      Map<String, int> initialOptions = {};
      for (var ctrl in _optionsCtrl) {
        initialOptions[ctrl.text.trim()] = 0;
      }

      // 2. Create in Firestore
      await FirebaseFirestore.instance.collection('polls').doc(code).set({
        'question': _questionCtrl.text.trim(),
        'options': initialOptions,
        'host': FirebaseAuth.instance.currentUser!.uid,
        'voters': [],
        'created': FieldValue.serverTimestamp(),
        'status': 'active'
      });

      // 3. Success! Navigate
      if (mounted) widget.onLaunch(code);

    } catch (e) {
      // 4. Handle Errors
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("NEW CASE FILE"), backgroundColor: Colors.grey[900], leading: IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("THE QUESTION", style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
            TextField(controller: _questionCtrl, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: "e.g. Who pays for dinner?", hintStyle: TextStyle(color: Colors.grey), border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)))),
            const SizedBox(height: 30),
            
            const Text("VERDICT OPTIONS (2-5)", style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
            const SizedBox(height: 10),
            ..._optionsCtrl.asMap().entries.map((entry) {
              int idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Option ${idx + 1}",
                          filled: true, fillColor: Colors.grey[900],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
                        ),
                      ),
                    ),
                    if (_optionsCtrl.length > 2) IconButton(icon: const Icon(Icons.remove_circle, color: Colors.redAccent), onPressed: () => _removeOption(idx))
                  ],
                ),
              );
            }),
            
            if (_optionsCtrl.length < 5)
              TextButton.icon(onPressed: _addOption, icon: const Icon(Icons.add, color: Colors.amberAccent), label: const Text("ADD OPTION", style: TextStyle(color: Colors.amberAccent))),

            const SizedBox(height: 40),
            
            // ACTION BUTTON WITH LOADING STATE
            ElevatedButton(
              onPressed: _isCreating ? null : _launch,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
              child: _isCreating 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text("LAUNCH JURY PROTOCOL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// B. VOTING SCREEN (For The Jury)
// -----------------------------------------------------------------------------
class _JuryVotingScreen extends StatelessWidget {
  final String pollId;
  final VoidCallback onVoted;
  const _JuryVotingScreen({required this.pollId, required this.onVoted});

  void _submitVote(String option) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('polls').doc(pollId);
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception("Poll closed");
      
      List voters = snapshot.data()!['voters'];
      if (voters.contains(uid)) return; // Already voted

      // Update count
      Map<String, dynamic> options = snapshot.data()!['options'];
      options[option] = (options[option] ?? 0) + 1;

      transaction.update(ref, {
        'options': options,
        'voters': FieldValue.arrayUnion([uid])
      });
    });
    
    onVoted();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('polls').doc(pollId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
        var data = snapshot.data!.data() as Map<String, dynamic>;
        Map<String, dynamic> options = data['options'];

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(title: const Text("CAST VOTE"), backgroundColor: Colors.black, automaticallyImplyLeading: false),
          body: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(data['question'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                ...options.keys.map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: ElevatedButton(
                    onPressed: () => _submitVote(opt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900], 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: Colors.amberAccent)
                    ),
                    child: Text(opt.toUpperCase(), style: const TextStyle(fontSize: 18, letterSpacing: 2)),
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// C. LIVE RESULTS SCREEN (Host & Voter View)
// -----------------------------------------------------------------------------
class _JuryLiveResultsScreen extends StatelessWidget {
  final String pollId;
  final bool isHost;
  final VoidCallback onExit;
  const _JuryLiveResultsScreen({required this.pollId, required this.isHost, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('polls').doc(pollId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
        var data = snapshot.data!.data() as Map<String, dynamic>;
        
        Map<String, dynamic> options = data['options'];
        int totalVotes = 0;
        options.forEach((k, v) => totalVotes += (v as int));

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text("LIVE VERDICT"), 
            backgroundColor: Colors.grey[900], 
            actions: [IconButton(icon: const Icon(Icons.exit_to_app), onPressed: onExit)]
          ),
          body: Column(
            children: [
              // ACCESS CODE HEADER
              if (isHost)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.amberAccent,
                  child: Column(
                    children: [
                      const Text("JURY ACCESS CODE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      Text(pollId, style: const TextStyle(color: Colors.black, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 5)),
                      const Text("Share this code with your squad", style: TextStyle(color: Colors.black87, fontSize: 10)),
                    ],
                  ),
                ),
              
              // CHART
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(data['question'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text("$totalVotes VOTES CAST", style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 30),
                      
                      ...options.entries.map((e) {
                        double pct = totalVotes == 0 ? 0 : (e.value / totalVotes);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(e.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text("${(pct * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.amberAccent)),
                              ]),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 10,
                                  backgroundColor: Colors.grey[800],
                                  color: Colors.amberAccent,
                                ),
                              )
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// D. JOIN SCREEN
// -----------------------------------------------------------------------------
class _JuryJoinScreen extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(String, bool) onJoin;
  const _JuryJoinScreen({required this.onCancel, required this.onJoin});

  @override
  State<_JuryJoinScreen> createState() => _JuryJoinScreenState();
}

class _JuryJoinScreenState extends State<_JuryJoinScreen> {
  final _codeCtrl = TextEditingController();

  void _attemptJoin() async {
    String code = _codeCtrl.text.trim().toUpperCase();
    var doc = await FirebaseFirestore.instance.collection('polls').doc(code).get();
    
    if (doc.exists) {
      List voters = doc.data()!['voters'];
      bool hasVoted = voters.contains(FirebaseAuth.instance.currentUser!.uid);
      widget.onJoin(code, hasVoted);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case file not found!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("JOIN JURY"), backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("ENTER ACCESS CODE", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(controller: _codeCtrl, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, letterSpacing: 5), decoration: const InputDecoration(filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _attemptJoin,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              child: const Text("ACCESS CASE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
// =============================================================================
// 3.4. 🎲 DECISION MAKER (Quantum Decider)
// =============================================================================

class DecisionMakerTool extends StatefulWidget {
  const DecisionMakerTool({super.key});

  @override
  State<DecisionMakerTool> createState() => _DecisionMakerToolState();
}

class _DecisionMakerToolState extends State<DecisionMakerTool> {
  final TextEditingController _inputCtrl = TextEditingController();
  
  // Default options so it's not empty
  final List<String> _options = ["Pizza", "Burger", "Sushi", "Tacos"]; 
  
  String _displayText = "AWAITING INPUT";
  bool _isProcessing = false;
  Color _textColor = Colors.grey;

  void _addOption() {
    if (_inputCtrl.text.trim().isNotEmpty) {
      setState(() {
        _options.add(_inputCtrl.text.trim());
        _inputCtrl.clear();
      });
    }
  }

  void _removeOption(String option) {
    setState(() {
      _options.remove(option);
    });
  }

  void _decide() async {
    if (_options.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _textColor = Colors.purpleAccent;
    });

    Random rnd = Random();
    int loops = 20; // How many times it flicks before stopping
    int delay = 50; // Speed of flicking

    // 1. Rapid Cycle Animation
    for (int i = 0; i < loops; i++) {
      await Future.delayed(Duration(milliseconds: delay));
      if (!mounted) return;
      
      setState(() {
        // Show a random option
        _displayText = _options[rnd.nextInt(_options.length)].toUpperCase();
        
        // Slow down slightly near the end
        if (i > 15) delay += 30; 
      });
    }

    // 2. Final Result
    String finalChoice = _options[rnd.nextInt(_options.length)].toUpperCase();
    
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _displayText = finalChoice;
      _textColor = Colors.greenAccent; // Success color
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("QUANTUM DECIDER"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.purpleAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 🖥️ MAIN DISPLAY SCREEN ---
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _textColor, width: 2),
                  boxShadow: [BoxShadow(color: _textColor.withOpacity(0.3), blurRadius: 20)]
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if(_isProcessing) const SizedBox(
                      width: 20, height: 20, 
                      child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2)
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _displayText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFamily: 'Courier'
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- ⌨️ INPUT AREA ---
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "ADD OPTION...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20)
                    ),
                    onSubmitted: (_) => _addOption(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add_circle, color: Colors.purpleAccent, size: 40),
                )
              ],
            ),
            
            const SizedBox(height: 20),

            // --- 📋 OPTIONS LIST ---
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _options.map((option) {
                    return Chip(
                      backgroundColor: Colors.grey[800],
                      label: Text(option, style: const TextStyle(color: Colors.white)),
                      deleteIcon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                      onDeleted: () => _removeOption(option),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), 
                        side: const BorderSide(color: Colors.white24)
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- 🚀 ACTION BUTTON ---
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isProcessing || _options.isEmpty ? null : _decide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 10,
                  shadowColor: Colors.purpleAccent.withOpacity(0.5)
                ),
                icon: const Icon(Icons.shuffle),
                label: Text(
                  _isProcessing ? "CALCULATING..." : "RUN PROTOCOL",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// =============================================================================
// 3.5. 💰 NEON SPLIT (Fixed Amount Edition)
// =============================================================================

class NeonSplitterTool extends StatefulWidget {
  const NeonSplitterTool({super.key});

  @override
  State<NeonSplitterTool> createState() => _NeonSplitterToolState();
}

class _NeonSplitterToolState extends State<NeonSplitterTool> {
  // Controllers
  final TextEditingController _billCtrl = TextEditingController();
  final TextEditingController _tipCtrl = TextEditingController(text: "0"); // Default $0 tip
  final TextEditingController _splitCtrl = TextEditingController(text: "2");

  // State variables
  double _billAmount = 0;
  double _tipAmount = 0;
  int _splitBy = 2;

  @override
  void dispose() {
    _billCtrl.dispose();
    _tipCtrl.dispose();
    _splitCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      _billAmount = double.tryParse(_billCtrl.text) ?? 0;
      _tipAmount = double.tryParse(_tipCtrl.text) ?? 0; // Direct amount now
      _splitBy = int.tryParse(_splitCtrl.text) ?? 1;
      
      if (_splitBy < 1) _splitBy = 1; 
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🧮 Math is simpler now: Just add them up
    double totalBill = _billAmount + _tipAmount;
    double perPerson = totalBill / _splitBy;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("CREDIT SPLITTER"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.greenAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 📟 HOLOGRAPHIC DISPLAY ---
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                ]
              ),
              child: Column(
                children: [
                  const Text("TOTAL PER AGENT", style: TextStyle(color: Colors.greenAccent, letterSpacing: 2, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(
                    "\$${perPerson.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Courier', 
                    ),
                  ),
                  const Divider(color: Colors.greenAccent, height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniStat("BILL", "\$${_billAmount.toStringAsFixed(2)}"),
                      _miniStat("TIP", "\$${_tipAmount.toStringAsFixed(2)}"), // Shows fixed amount
                      _miniStat("TOTAL", "\$${totalBill.toStringAsFixed(2)}"),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- ⌨️ INPUT FIELDS ---
            
            // 1. BILL AMOUNT
            _neonInputField(
              label: "BILL AMOUNT", 
              controller: _billCtrl, 
              prefix: "\$ "
            ),
            
            const SizedBox(height: 20),

            // 2. TIP AMOUNT & SPLIT
            Row(
              children: [
                Expanded(
                  child: _neonInputField(
                    label: "TIP AMOUNT", 
                    controller: _tipCtrl, 
                    prefix: "\$ " // Changed from % to $
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _neonInputField(
                    label: "SQUAD SIZE", 
                    controller: _splitCtrl, 
                    prefix: "# "
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Reset Button
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _billCtrl.clear();
                  _tipCtrl.text = "0";
                  _splitCtrl.text = "2";
                  _calculate();
                });
              },
              icon: const Icon(Icons.refresh, color: Colors.grey),
              label: const Text("RESET DATA", style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }

  // Custom Input Widget
  Widget _neonInputField({required String label, required TextEditingController controller, required String prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
          onChanged: (_) => _calculate(), 
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
