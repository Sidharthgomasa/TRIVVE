import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For vibration
import 'core_engine.dart';
import 'package:trivve/services/ad_service.dart'; // Your AdService

class ArcadeWrapper extends StatelessWidget {
  final String title;
  final String instructions; 
  final Widget gameUI;
  final Map<String, dynamic> data;
  final GameController controller;

  const ArcadeWrapper({
    super.key,
    required this.title,
    required this.instructions,
    required this.gameUI,
    required this.data,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-load an ad while they are on this screen
    AdService().loadInterstitial();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Game Content
          SafeArea(
            child: Center(child: gameUI),
          ),

          // 2. The Universal HUD (Top Control Bar)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // EXIT BUTTON (With Ad Logic)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () {
                      HapticFeedback.mediumImpact(); // Feel the exit
                      
                      // Show Ad on Exit (High Gains Strategy)
                      AdService().showInterstitial();
                      
                      Navigator.pop(context);
                    },
                  ),
                  
                  // GAME TITLE
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.cyanAccent, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 3,
                      fontSize: 16,
                      shadows: [
                        Shadow(color: Colors.cyanAccent, blurRadius: 10),
                      ],
                    ),
                  ),

                  // INFO BUTTON
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact(); // Subtle click
                      _showHowToPlay(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 10)
                        ],
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Instructions",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyanAccent, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.terminal, color: Colors.cyanAccent, size: 40),
                const SizedBox(height: 15),
                Text(
                  "PROTOCOL: $title", 
                  style: const TextStyle(
                    color: Colors.cyanAccent, 
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  instructions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70, 
                    height: 1.6, 
                    fontSize: 14,
                    decoration: TextDecoration.none,
                    fontFamily: 'Courier', 
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact(); // Confirm start
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("INITIALIZE GAME", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}