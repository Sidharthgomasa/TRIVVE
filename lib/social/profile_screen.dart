import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameCtrl = TextEditingController();
  
  // 🎭 Cyber Avatar Collection
  final List<String> _avatars = [
    "🤖", "👽", "🦊", "🐯", "🦁", "💀", "👻", "👾", 
    "🐱", "🦄", "🐲", "⚡", "🔥", "💎", "🎮", "🚀"
  ];
  
  String _selectedAvatar = "🤖";
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    if (user == null) return;
    
    // 1. Get from Auth (Fastest)
    _nameCtrl.text = user!.displayName ?? "Player";
    
    // 2. Get from Firestore (For Avatar)
    var doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists && doc.data() != null) {
      if (mounted) {
        setState(() {
          _selectedAvatar = doc['avatar'] ?? "🤖";
        });
      }
    }
  }

  void _saveProfile() async {
    if (user == null) return;
    setState(() => _isSaving = true);

    String newName = _nameCtrl.text.trim();
    if (newName.isEmpty) newName = "Anon";

    try {
      // 1. Update Auth (Basic Info)
      await user!.updateDisplayName(newName);
      
      // 2. Update Firestore (Extended Info)
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'uid': user!.uid,
        'displayName': newName,
        'avatar': _selectedAvatar,
        'email': user!.email,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
        Navigator.pop(context, true); // Return true to refresh lobby
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("IDENTITY LINK"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. AVATAR PREVIEW
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[900],
                border: Border.all(color: Colors.cyanAccent, width: 2),
                boxShadow: const [BoxShadow(color: Colors.cyanAccent, blurRadius: 20)]
              ),
              alignment: Alignment.center,
              child: Text(_selectedAvatar, style: const TextStyle(fontSize: 50)),
            ),
            const SizedBox(height: 30),

            // 2. NAME INPUT
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                hintText: "CODENAME",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
              ),
            ),
            const SizedBox(height: 30),

            // 3. AVATAR SELECTOR GRID
            const Text("SELECT AVATAR", style: TextStyle(color: Colors.grey, letterSpacing: 2, fontSize: 12)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _avatars.length,
              itemBuilder: (c, i) => GestureDetector(
                onTap: () => setState(() => _selectedAvatar = _avatars[i]),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedAvatar == _avatars[i] ? Colors.cyanAccent.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: _selectedAvatar == _avatars[i] ? Border.all(color: Colors.cyanAccent) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(_avatars[i], style: const TextStyle(fontSize: 30)),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 4. SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text("ESTABLISH LINK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}