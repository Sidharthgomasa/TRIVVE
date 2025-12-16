import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trivve/social/profile_screen.dart';
import 'package:trivve/login_screen.dart'; // Ensure this matches your login file name

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _bgCtrl;
  late AnimationController _enterCtrl;
  final List<SettingStar> _stars = [];
  final Random _rng = Random();

  // Settings State (Visual Only for v0.1)
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  @override
  void initState() {
    super.initState();
    // Background Animation
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    for (int i = 0; i < 40; i++) {
      _stars.add(SettingStar(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: _rng.nextDouble() * 2 + 1,
        speed: _rng.nextDouble() * 0.05 + 0.01
      ));
    }

    // Entrance Animation
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Clear stack and go to Login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()), 
        (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("SYSTEM CONFIG", style: TextStyle(letterSpacing: 2, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (ctx, child) => CustomPaint(painter: SettingsStarPainter(_stars, _bgCtrl.value)),
            ),
          ),

          // 2. SETTINGS LIST
          Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: _enterCtrl,
                builder: (context, child) {
                  return SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut)),
                    child: FadeTransition(
                      opacity: _enterCtrl,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSectionHeader("SENSORY UPLINK"),
                          _buildSwitch("AUDIO FX", Icons.volume_up, _soundEnabled, (v) => setState(() => _soundEnabled = v)),
                          _buildSwitch("HAPTIC FEEDBACK", Icons.vibration, _hapticsEnabled, (v) => setState(() => _hapticsEnabled = v)),
                          
                          const SizedBox(height: 30),
                          _buildSectionHeader("ACCOUNT GATEWAY"),
                          _buildActionTile("EDIT IDENTITY", Icons.face, Colors.cyanAccent, () {
                            Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen()));
                          }),
                          _buildActionTile("TERMINATE SESSION", Icons.power_settings_new, Colors.redAccent, _logout),
                          
                          const SizedBox(height: 40),
                          const Text("TRIVVE ARCADE v0.1", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
                        ],
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSwitch(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        secondary: Icon(icon, color: Colors.cyanAccent),
        value: value,
        activeThumbColor: Colors.cyanAccent,
        activeTrackColor: Colors.cyanAccent.withOpacity(0.3),
        inactiveTrackColor: Colors.black,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 15),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }
}

// --- INDEPENDENT STAR SYSTEM ---
class SettingStar { double x, y, size, speed; SettingStar({required this.x, required this.y, required this.size, required this.speed}); }
class SettingsStarPainter extends CustomPainter {
  final List<SettingStar> stars; final double anim; SettingsStarPainter(this.stars, this.anim);
  @override void paint(Canvas c, Size s) {
    Paint p = Paint()..color = Colors.white;
    for (var st in stars) {
      double y = (st.y + (anim * st.speed)) % 1.0;
      p.color = Colors.white.withOpacity(0.3 + (sin(anim * 6 + st.x * 10) + 1) / 4);
      c.drawCircle(Offset(st.x * s.width, y * s.height), st.size, p);
    }
  }
  @override bool shouldRepaint(old) => true;
}