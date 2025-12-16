import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  
  // Animation Controllers
  late AnimationController _bgCtrl;
  final List<LoginStar> _stars = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    // Initialize Starfield
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    for (int i = 0; i < 60; i++) {
      _stars.add(LoginStar(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: _rng.nextDouble() * 2 + 1,
        speed: _rng.nextDouble() * 0.05 + 0.01
      ));
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // 1. Trigger Google Sign In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }

      // 2. Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase
      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      
      // 5. Create/Update User Doc in Firestore (Essential for your app logic)
      if (userCred.user != null) {
        DocumentReference ref = FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid);
        var doc = await ref.get();
        
        if (!doc.exists) {
          // New User Setup
          await ref.set({
            'uid': userCred.user!.uid,
            'email': userCred.user!.email,
            'displayName': userCred.user!.displayName,
            'photoUrl': userCred.user!.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'aura': 100, // Starter bonus
            'xp': 0,
            'gamesPlayed': 0,
            'wins': 0,
            'ownedItems': [],
          });
        }
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Failed: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. ANIMATED BACKGROUND
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (ctx, child) => CustomPaint(painter: LoginStarPainter(_stars, _bgCtrl.value)),
            ),
          ),

          // 2. MAIN CONTENT
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // APP LOGO / TITLE
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 50, spreadRadius: 10)]
                    ),
                    child: const Icon(Icons.hub, size: 80, color: Colors.cyanAccent),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "TRIVVE",
                    style: TextStyle(
                      fontFamily: 'Courier', 
                      fontSize: 40, 
                      fontWeight: FontWeight.w900, 
                      color: Colors.white, 
                      letterSpacing: 5,
                      shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 20)]
                    ),
                  ),
                  const Text(
                    "THE SOCIAL ARCADE",
                    style: TextStyle(color: Colors.grey, letterSpacing: 3, fontSize: 12),
                  ),

                  const SizedBox(height: 60),

                  // GOOGLE LOGIN BUTTON
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.cyanAccent)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: Image.network("https://img.icons8.com/color/48/google-logo.png", height: 24),
                        label: const Text("CONTINUE WITH GOOGLE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 10,
                          shadowColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),

                  const Spacer(),

                  // 3. THE SAFE NOTE (Your Request)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white10)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security, color: Colors.greenAccent, size: 30),
                            const SizedBox(width: 15),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("SECURE LOGIN ENVIRONMENT", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                  SizedBox(height: 2),
                                  Text(
                                    "Developed by a Computer Science Engineer. We use Google's Official Secure Servers. Your credentials never touch our database.",
                                    style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.2),
                                  ),
                                ],
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

// --- LOGIN STAR SYSTEM (Independent) ---
class LoginStar { double x, y, size, speed; LoginStar({required this.x, required this.y, required this.size, required this.speed}); }
class LoginStarPainter extends CustomPainter {
  final List<LoginStar> stars; final double anim; LoginStarPainter(this.stars, this.anim);
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