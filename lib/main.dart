import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // IMPORT THIS

// --- IMPORT YOUR MODULES ---
import 'trrive_map_module.dart';       
import 'trrive_social_arcade.dart';    
import 'package:trivve/trrive_squad_module.dart';
import 'package:trivve/gamepage.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ⚠️ YOUR FIREBASE KEYS MUST BE HERE
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
      // ✅ FIX: Wait for Auth before loading the app
      home: const AuthWrapper(), 
    );
  }
}

// =============================================================================
// AUTH WRAPPER (Prevents Null Errors on Startup)
// =============================================================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If Firebase is checking... show loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
          );
        }

        // 2. If User is NOT logged in... show Login Screen directly
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 3. If User IS logged in... show the App
        return const ResponsiveContainer(child: TrivveMainScaffold());
      },
    );
  }
}

// =============================================================================
// SIMPLE LOGIN SCREEN (If user is not logged in)
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
                  await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
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
// 📱 RESPONSIVE WRAPPER
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
// THE MAIN NAVIGATION DOCK
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
    const GameLobby(),          
    const ToolboxScreen(),      
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
            BottomNavigationBarItem(
              icon: Icon(Icons.gamepad_outlined),
              activeIcon: Icon(Icons.gamepad, shadows: [Shadow(color: Colors.greenAccent, blurRadius: 10)]),
              label: "ARCADE",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.handyman_outlined),
              activeIcon: Icon(Icons.handyman, shadows: [Shadow(color: Colors.orangeAccent, blurRadius: 10)]),
              label: "TOOLS",
            ),
          ],
        ),
      ),
    );
  }
}