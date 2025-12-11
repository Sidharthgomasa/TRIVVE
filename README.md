⚡ TRIVVE: The Social Arcade & Live Map
Trivve is a Gen Z-focused "Super App" that blends Real-World Geolocation, Multiplayer Arcade Gaming, and Social Networking into a single Cyberpunk-themed experience. It is built with Flutter and powered by Firebase.

🚀 Key Features
🗺️ 1. The Neon World (Live Map)
Cyberpunk Styling: Dark mode map using CartoDB Dark Matter tiles.

Universal Event Tracking: View live user-generated events (Sports, Parties, Food) on a global map.

Dynamic Markers: Markers change color based on category (e.g., Orange for Sports, Pink for Party).

Permanent Zones: Includes "Trivve Stadium" (Cricket) and "Mystery Crates" (Loot).

Interactive HUD: Glass-morphism headers and pulsing user avatar.

🎮 2. The Arcade (Gaming Hub)
Live Lobby: See active games waiting for players in a horizontal "Story-style" feed.

Dare Mode (Blind Date):

Play a "Best of 3" series.

The Wager: The host's profile photo is Blurred.

The Reveal: If the opponent wins the series, the photo is unblurred via a popup.

Casual Games: Tic-Tac-Toe, Rock Paper Scissors, Connect 4, Gomoku, Memory Match.

Cricket Module: A professional-grade Cricket Scorer with manual squad entry, partnership stats, and commentary.

🏠 3. The Hub (Social & Profile)
The Pulse: An ephemeral social feed (24h expiry) where users post "Vibes."

The Squad: Create or join clans using unique 6-digit codes. View squad members on a private map.

The Vault: A gamified store to spend XP earned in games. Buy trails, borders, and tags.

The Hustle: Daily quests system (e.g., "Win 3 Games") to earn XP.

🤖 4. The Oracle
AI Companion: A built-in chatbot powered by Google Gemini AI.

Persona: Witty, futuristic, and helpful assistant for the app.

🛠️ Tech Stack & Dependencies
Framework: Flutter (Web/Edge Optimized) Backend: Firebase (Firestore Database, Authentication)

Key Packages:

flutter_map & latlong2 (OpenStreetMap rendering)

firebase_core, firebase_auth, cloud_firestore (Backend)

google_generative_ai (Gemini AI integration)

confetti (Win animations)

share_plus (Sharing game codes)

geolocator (Real-time GPS)

📂 Project Structure
The app logic is divided into modular files for easier maintenance.

File Name	Description
lib/main.dart	The Traffic Controller. Initializes Firebase, sets up the Theme, and manages the Bottom Navigation Dock (Tabs).
lib/trrive_social_arcade.dart	The Core Logic. Contains the Dashboard, Game Lobby, Arcade Logic (TicTacToe/RPS), The Vault, The Oracle, and Squads.
lib/trrive_map_module.dart	The Map System. Handles OpenStreetMap rendering, Live Event markers, and Location logic.
lib/trrive_cricket_module.dart	The Sports Engine. A dedicated module for the Cricket Scoring feature.
⚙️ Installation & Setup
1. Clone the Repository
Bash
git clone https://github.com/yourusername/trivve.git
cd trivve
2. Install Dependencies
Bash
flutter pub get
3. Firebase Configuration (CRITICAL)
Since this is a Web App, keys are hardcoded in main.dart.

Go to Firebase Console.

Create a project -> Add Web App.

Copy the firebaseConfig object.

Open lib/main.dart and replace the placeholder keys inside Firebase.initializeApp:

Dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_BUCKET.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID",
  ),
);
4. Gemini AI Setup
Get a free API key from Google AI Studio.

Open lib/trrive_social_arcade.dart.

Find the OracleScreen class and replace _apiKey:

Dart
final String _apiKey = "YOUR_GEMINI_API_KEY";
5. Run the App
Bash
flutter run -d edge
🎲 Game Logic Breakdown
"Dare To?" (Blind Date Mode)
Creation: Host selects "Best of 3". Firestore creates a game doc with mode: 'dare' and saves the Host's photo URL.

Visuals: The opponent sees a Blurred Circle in the top bar.

Gameplay: Scores are tracked in hostWins and p2Wins in Firestore.

Victory: If p2Wins >= 2, the app triggers _showRevealPopup().

Reveal: The blur is removed, and the Host's photo is displayed in a large dialog.

🔮 Future Roadmap
Trivve FM: A built-in Lofi music player that syncs across the squad.

AR Graffiti: Leave persistent digital messages on real-world walls.

Tournament Brackets: Automated league management for the Cricket module.

The Black Market: A time-sensitive store (10 PM - 4 AM) for "illegal" game boosters.

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

Created by Sidharth Gomasa
sidharthgomasa04@gmail.com