import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;

  // Animation
  late AnimationController _bgCtrl;
  final List<LoginStar> _stars = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();

    for (int i = 0; i < 60; i++) {
      _stars.add(LoginStar(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: _rng.nextDouble() * 2 + 1,
        speed: _rng.nextDouble() * 0.05 + 0.01,
      ));
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  /// Anonymous login (temporary & safe)
  Future<void> _enterTrivve() async {
    setState(() => _isLoading = true);

    try {
      final userCred = await FirebaseAuth.instance.signInAnonymously();
      final user = userCred.user;

      if (user != null) {
        final ref =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        final snap = await ref.get();
        if (!snap.exists) {
          await ref.set({
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) =>
                  CustomPaint(painter: LoginStarPainter(_stars, _bgCtrl.value)),
            ),
          ),

          // Main UI
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.3),
                          blurRadius: 50,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: const Icon(Icons.hub,
                        size: 80, color: Colors.cyanAccent),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "TRIVVE",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 5,
                      shadows: [
                        Shadow(color: Colors.cyanAccent, blurRadius: 20)
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),

                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.cyanAccent)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _enterTrivve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "ENTER TRIVVE",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Safe note
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: BackdropFilter(
                      filter:
                          ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.security,
                                color: Colors.greenAccent, size: 30),
                            SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                "Secure access. No passwords stored. Identity protected.",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- STARFIELD ----
class LoginStar {
  double x, y, size, speed;
  LoginStar(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed});
}

class LoginStarPainter extends CustomPainter {
  final List<LoginStar> stars;
  final double anim;

  LoginStarPainter(this.stars, this.anim);

  @override
  void paint(Canvas c, Size s) {
    final paint = Paint();
    for (var st in stars) {
      final y = (st.y + anim * st.speed) % 1.0;
      paint.color =
          Colors.white.withOpacity(0.3 + (sin(anim * 6) + 1) / 4);
      c.drawCircle(
          Offset(st.x * s.width, y * s.height), st.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
