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
  bool _allowSaveAnyway = false;

  Future<void> _submitUsername({bool skipCheck = false}) async {
    final username = _controller.text.trim().toLowerCase();

    if (username.length < 3) {
      _showSnack("Username must be at least 3 characters");
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      _showSnack("Only letters, numbers and underscores allowed");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Checking availability…";
      _allowSaveAnyway = false;
    });

    try {
      if (!skipCheck) {
        final check = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: username)
            .get()
            .timeout(const Duration(seconds: 4));

        if (check.docs.isNotEmpty) {
          setState(() {
            _isLoading = false;
            _statusMessage = "This username is already taken";
          });
          return;
        }
      }

      setState(() => _statusMessage = "Saving your profile…");

      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'username': username,
        'usernameSet': true,
        'displayName': user.displayName ?? username,
        'email': user.email,
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TrivveApp()),
        (_) => false,
      );
    } on TimeoutException {
      setState(() {
        _isLoading = false;
        _statusMessage = "Connection seems slow.";
        _allowSaveAnyway = true;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Something went wrong. Please try again.";
        _allowSaveAnyway = true;
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline,
                size: 72, color: Colors.cyanAccent),
            const SizedBox(height: 24),

            const Text(
              "Choose your username",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "This will be visible to others on Trivve.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),

            const SizedBox(height: 36),

            TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "username",
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains("wrong")
                    ? Colors.redAccent
                    : Colors.cyanAccent,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 24),

            if (_allowSaveAnyway)
              TextButton(
                onPressed: () => _submitUsername(skipCheck: true),
                child: const Text(
                  "Save anyway",
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitUsername,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        "Continue",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
