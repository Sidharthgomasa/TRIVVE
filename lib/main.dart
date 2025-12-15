import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ REQUIRED IMPORT
import 'package:trivve/trivve_college_spaces.dart';
// ... other imports
import 'package:trivve/the_hunt.dart'; // ✅ Add this line

// --- MODULE IMPORTS ---
import 'package:trivve/trrive_map_module.dart';
import 'package:trivve/trrive_social_arcade.dart';
import 'package:trivve/trrive_friends_module.dart'; // Make sure this is imported
import 'package:trivve/gamepage.dart';
import 'package:trivve/trrive_squad_module.dart';
import 'package:trivve/username_setup.dart';
import 'package:google_fonts/google_fonts.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCyTu2zhg2qpULwkvtKj__txLGJ6v4gl5g",
      authDomain: "rally-app-6fb75.firebaseapp.com",
      projectId: "rally-app-6fb75",
      storageBucket: "rally-app-6fb75.firebasestorage.app",
      messagingSenderId: "589537709752",
      appId: "1:589537709752:web:abbb40f34130ed53e16e4d",
    ),
  ); 
  
  runApp(const TrivveApp());
}

class TrivveApp extends StatelessWidget {
  const TrivveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivve',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.cyan,
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 20,
        )
      ),
      home: const AuthWrapper(), 
    );
  }
}

// =============================================================================
// AUTH WRAPPER
// =============================================================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // USER IS LOGGED IN -> CHECK IF USERNAME IS SET
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)));
            }

            // If user doc exists AND has 'username' field -> Go to App
            if (userSnap.data != null && userSnap.data!.exists) {
              Map<String, dynamic>? data = userSnap.data!.data() as Map<String, dynamic>?;
              if (data != null && data.containsKey('username')) {
                return const ResponsiveContainer(child: TrivveMainScaffold());
              }
            }
            
            // Otherwise -> Go to Setup
            return const UsernameSetupScreen();
          },
        );
      },
    );
  }
}

// =============================================================================
// LOGIN SCREEN (FIXED: CREATES USER IN DB)
// =============================================================================

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("ＴＲＩＶＶＥ", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 5, fontSize: 40, color: Colors.cyanAccent)),
            const SizedBox(height: 10),
            const Text("Social Arcade & Live Map", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              icon: const Icon(Icons.login, color: Colors.black),
              label: const Text("SIGN IN WITH GOOGLE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
              ),
              onPressed: () async {
                try {
                  // 1. Sign In
                  UserCredential cred = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
                  User? user = cred.user;

                  if (user != null) {
                    // 2. CHECK IF USER EXISTS
                    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

                    if (!doc.exists) {
                      // 3. CREATE PROFILE IF NEW
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                        'displayName': user.displayName ?? "Unknown Agent",
                        'email': user.email,
                        'photoUrl': user.photoURL,
                        'uid': user.uid,
                        'createdAt': FieldValue.serverTimestamp(),
                        'wins': 0,
                        'aura': 0,
                        'xp': 0,
                      });
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e")));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// RESPONSIVE CONTAINER
// =============================================================================

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  const ResponsiveContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return Scaffold(
            backgroundColor: const Color(0xFF050505),
            body: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: Image.network(
                      "https://img.freepik.com/free-vector/dark-hexagonal-background-with-gradient-color_79603-1409.jpg", 
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(color: Colors.black),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 500,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      boxShadow: [
                        BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 30, spreadRadius: 5),
                        BoxShadow(color: Colors.purpleAccent.withOpacity(0.1), blurRadius: 50, spreadRadius: -10),
                      ],
                      border: Border.symmetric(vertical: BorderSide(color: Colors.white.withOpacity(0.1), width: 1))
                    ),
                    child: ClipRRect(child: child),
                  ),
                ),
              ],
            ),
          );
        }
        return child;
      },
    );
  }
}

// =============================================================================
// MAIN NAVIGATION DOCK
// =============================================================================

class TrivveMainScaffold extends StatefulWidget {
  const TrivveMainScaffold({super.key});

  @override
  State<TrivveMainScaffold> createState() => _TrivveMainScaffoldState();
}

class _TrivveMainScaffoldState extends State<TrivveMainScaffold> {
  int _currentIndex = 1;

  final List<Widget> _screens = [
    const TrriveNeonMap(),
    const HomeScreen(),
    const TheHuntScreen(),
    const GameLobby(),
    const SquadScreen(),
    const CollegeSpacesHub(),
    const FriendsScreen(), // Added Friends Screen as 5th Tab
   
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map, shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)]),
              label: "WORLD",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, shadows: [Shadow(color: Colors.purpleAccent, blurRadius: 10)]),
              label: "HUB",
            ),
            // ✅ 3. THE HUNT (NEW ITEM)
            BottomNavigationBarItem(
              icon: Icon(Icons.gps_fixed), // Target Icon
              activeIcon: Icon(Icons.gps_fixed, color: Colors.redAccent, shadows: [Shadow(color: Colors.red, blurRadius: 15)]),
              label: "HUNT",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gamepad_outlined),
              activeIcon: Icon(Icons.gamepad, shadows: [Shadow(color: Colors.greenAccent, blurRadius: 10)]),
              label: "ARCADE",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield, shadows: [Shadow(color: Colors.orangeAccent, blurRadius: 10)]),
              label: "SQUAD",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school, shadows: [Shadow(color: Colors.yellowAccent, blurRadius: 10)]),
              label: "CAMPUS",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people, shadows: [Shadow(color: Colors.pinkAccent, blurRadius: 10)]),
              label: "SOCIAL",
            ),
            
          ],
        ),
      ),
    );
  }
}