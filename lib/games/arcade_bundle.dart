import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trivve/games/core_engine.dart';

class ArcadeMasterWrapper extends StatelessWidget {
  final Widget gameUI;
  final Map<String, dynamic> data;
  final GameController controller;
  final String gameType;
  final String instructions;

  const ArcadeMasterWrapper({
    super.key,
    required this.gameUI,
    required this.data,
    required this.controller,
    required this.gameType,
    required this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    final state = data['state'] ?? {};
    final String? winner = data['winner'];
    final bool isMyTurn = state['turn'] == controller.myId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. THE GAME CONTENT
          Column(
            children: [
              _buildNeonHUD(context, state, isMyTurn),
              Expanded(child: SafeArea(top: false, child: gameUI)),
            ],
          ),

          // 2. HELP BUTTON (Top Right - Overlaying HUD)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 15,
            child: GestureDetector(
              onTap: () => _showHelp(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                ),
                child: const Icon(Icons.help_outline, color: Colors.cyanAccent, size: 22),
              ),
            ),
          ),

          // 3. THE WINNER VERDICT (Locked Overlay)
          if (winner != null) _buildVerdictOverlay(context, winner),
        ],
      ),
    );
  }

  Widget _buildNeonHUD(BuildContext context, Map state, bool isMyTurn) {
    // Determine scores based on game state keys
    final String p1Score = "${state['p1Score'] ?? state['score'] ?? 0}";
    final String p2Score = "${state['p2Score'] ?? state['enemyScore'] ?? 0}";

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 15,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Colors.cyanAccent.withOpacity(0.1), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statBox("USER_LOCAL", p1Score, Colors.greenAccent, isMyTurn),
          const Text("VS", style: TextStyle(color: Colors.white12, fontWeight: FontWeight.w900, letterSpacing: 2)),
          _statBox("CORE_AI", p2Score, Colors.pinkAccent, !isMyTurn),
        ],
      ),
    );
  }

  Widget _statBox(String label, String val, Color color, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: active ? color.withOpacity(0.05) : Colors.transparent,
        border: Border.all(color: active ? color.withOpacity(0.5) : Colors.white10),
        boxShadow: active ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 15)] : [],
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: active ? color : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          Text(val, style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Courier')),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Rules",
      barrierColor: Colors.black87,
      pageBuilder: (context, anim1, anim2) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.cyanAccent, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, color: Colors.cyanAccent, size: 40),
                const SizedBox(height: 15),
                Text("${gameType.toUpperCase()} PROTOCOL", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.none)),
                const SizedBox(height: 20),
                Text(instructions, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5, decoration: TextDecoration.none, fontWeight: FontWeight.normal)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("ACKNOWLEDGED", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerdictOverlay(BuildContext context, String winner) {
    bool iWon = winner == controller.myId;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glitch Effect Icon
              Icon(iWon ? Icons.verified_user : Icons.gpp_bad, color: iWon ? Colors.greenAccent : Colors.redAccent, size: 100),
              const SizedBox(height: 10),
              Text(
                iWon ? "TRANSACTION SECURED" : "ENCRYPTION FAILED",
                style: TextStyle(color: iWon ? Colors.greenAccent : Colors.redAccent, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(height: 5),
              Text(
                iWon ? "Aura +10 successfully mined" : "Aura reduction sequence initiated",
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 40),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Column(
                  children: [
                    _overlayButton("REBOOT MATCH", () => controller.requestRematch(), Colors.white, Colors.black),
                    const SizedBox(height: 15),
                    _overlayButton("TERMINATE SESSION", () => Navigator.pop(context), Colors.transparent, Colors.white, border: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayButton(String label, VoidCallback action, Color bg, Color text, {bool border = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          elevation: 0,
          side: border ? const BorderSide(color: Colors.white24) : null,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}