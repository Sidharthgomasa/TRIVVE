import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  final List<SettingStar> _stars = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    // Subtle background animation (calm, not flashy)
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..repeat();

    for (int i = 0; i < 30; i++) {
      _stars.add(
        SettingStar(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          size: _rng.nextDouble() * 1.5 + 0.5,
          speed: _rng.nextDouble() * 0.03 + 0.005,
        ),
      );
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Soft animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => CustomPaint(
                painter: SettingsStarPainter(_stars, _bgCtrl.value),
              ),
            ),
          ),

          // Content
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sectionTitle("Account"),

              _cardTile(
                icon: Icons.person_outline,
                title: "Signed in",
                subtitle: "Your identity is protected",
              ),

              _cardTile(
                icon: Icons.security,
                title: "Privacy",
                subtitle:
                    "We don’t sell your data or track personal activity",
              ),

              const SizedBox(height: 30),

              _sectionTitle("Session"),

              _actionTile(
                icon: Icons.logout,
                title: "Log out",
                color: Colors.redAccent,
                onTap: _logout,
              ),

              const SizedBox(height: 40),

              Center(
                child: Text(
                  "TRIVVE • Real-time local discovery",
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- UI HELPERS ----------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _cardTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------- BACKGROUND --------

class SettingStar {
  double x, y, size, speed;
  SettingStar({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}

class SettingsStarPainter extends CustomPainter {
  final List<SettingStar> stars;
  final double anim;

  SettingsStarPainter(this.stars, this.anim);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var star in stars) {
      final y = (star.y + anim * star.speed) % 1.0;
      paint.color = Colors.white.withOpacity(0.15);
      canvas.drawCircle(
        Offset(star.x * size.width, y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
