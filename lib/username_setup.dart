import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trivve/main.dart'; 

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = "";
  bool _showForceSave = false; 

  Future<void> _submitUsername({bool force = false}) async {
    String username = _controller.text.trim().toLowerCase(); 
    
    if (username.isEmpty || username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Username too short!")));
      return;
    }

    final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validCharacters.hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid characters. Use letters & numbers only.")));
      return;
    }

    setState(() { 
      _isLoading = true; 
      _statusMessage = "Checking availability..."; 
      _showForceSave = false;
    });

    try {
      if (!force) {
        // 1. CHECK UNIQUENESS
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: username)
            .get()
            .timeout(const Duration(seconds: 4));

        if (query.docs.isNotEmpty) {
          setState(() {
            _isLoading = false;
            _statusMessage = "❌ Username taken.";
          });
          return;
        }
      }

      // 2. SAVE TO DATABASE (CRITICAL FIX HERE)
      setState(() => _statusMessage = "Saving identity...");
      
      User user = FirebaseAuth.instance.currentUser!;
      
      // ✅ FIX: Use .set with merge: true instead of .update
      // This creates the document if it was missing!
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': username,
        'usernameSet': true, 
        'displayName': (user.displayName == null || user.displayName == "Unknown Agent") 
            ? username 
            : user.displayName,
        'email': user.email,     // Ensure these exist
        'photoUrl': user.photoURL,
        'uid': user.uid,
      }, SetOptions(merge: true)); 

      // 3. SUCCESS NAVIGATE
      setState(() => _statusMessage = "Success! Entering Trivve...");
      if(mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TrivveApp()),
          (route) => false
        );
      }

    } on TimeoutException catch (_) {
      setState(() {
        _isLoading = false;
        _statusMessage = "⚠️ Connection Slow. Skip check?";
        _showForceSave = true; 
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error: $e";
        _showForceSave = true; 
      });
      print("ERROR LOG: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: Colors.cyanAccent),
            const SizedBox(height: 20),
            const Text(
              "IDENTITY REQUIRED",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 10),
            const Text(
              "Choose a unique Agent ID.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "username",
                hintStyle: TextStyle(color: Colors.grey[800]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.cyanAccent)),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(_statusMessage, style: TextStyle(color: _statusMessage.startsWith("Error") || _statusMessage.startsWith("❌") ? Colors.red : Colors.cyanAccent)),
            const SizedBox(height: 20),

            if (_showForceSave)
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  icon: const Icon(Icons.warning, color: Colors.white),
                  label: const Text("FORCE SAVE (FIX ERROR)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _submitUsername(force: true),
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                onPressed: _isLoading ? null : () => _submitUsername(force: false),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text("CONFIRM IDENTITY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}