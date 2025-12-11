# TRIVVE — The Social Arcade & Live Map (Updated README)

> A Gen-Z–focused Super App that blends real-world location interaction, multiplayer arcade games, social features, and an AI companion — built in Flutter + Firebase.

---

## Table of contents

* [Project overview](#project-overview)
* [Main features](#main-features)
* [Tech stack](#tech-stack)
* [Repository structure](#repository-structure)
* [Quick start (run locally)](#quick-start-run-locally)

  * [Prerequisites](#prerequisites)
  * [1) Clone & install](#1-clone--install)
  * [2) Firebase setup](#2-firebase-setup)
  * [3) Gemini / AI setup (Oracle)](#3-gemini--ai-setup-oracle)
  * [4) Environment variables example](#4-environment-variables-example)
  * [5) Run for web (recommended)](#5-run-for-web-recommended)
* [Development notes & tips](#development-notes--tips)
* [Testing](#testing)
* [CI / GitHub Actions suggestions](#ci--github-actions-suggestions)
* [Security, privacy & legal](#security-privacy--legal)
* [Roadmap & recommended improvements](#roadmap--recommended-improvements)
* [Contribution guide](#contribution-guide)
* [License & contact](#license--contact)

---

## Project overview

TRIVVE is a single codebase Flutter project (web + mobile) intended as a "super app" for social location-based interactions and casual multiplayer arcade gaming. It intentionally ships with a neon/cyberpunk UI and aims to provide features like a live map (Neon World), the Arcade hub (multiple casual games and Dare mode), a Cricket score module, ephemeral social pulses (stories), Squads (private groups with map view), Vault (XP store), and Oracle — an integrated generative AI chatbot.

This README is an updated, practical guide for developers based on the current repository content and code layout.

---

## Main features

* Live map with dark map tiles and dynamic markers (Neon World)
* Multiplayer & single-player casual games: Tic-Tac-Toe, Rock-Paper-Scissors, Connect 4, Gomoku, Memory Match, etc.
* Dare/Challenge mode with blurred host images and reveal mechanics
* Cricket scoring engine and full manual scorer UI
* Ephemeral "Pulse" feed (24h), Squads with 6-digit join codes
* Vault (store) for XP items, daily quests and gamified progression
* Oracle: built-in Gemini AI chat interface

---

## Tech stack

* Flutter (Dart)
* Firebase services: Authentication, Cloud Firestore, (Hosting / Functions optional)
* Map rendering: `flutter_map` + `latlong2` using CartoDB / OpenStreetMap tiles
* Packages used (examples from `pubspec.yaml`): `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_generative_ai` (Gemini), `geolocator`, `confetti`, `share_plus`, and others.

---

## Repository structure (high-level)

```
TRIVVE/
├─ .firebase/
├─ android/
├─ ios/
├─ lib/
│  ├─ main.dart
│  ├─ trrive_social_arcade.dart
│  ├─ trrive_map_module.dart
│  ├─ trrive_cricket_module.dart
│  └─ (other UI screens & helpers)
├─ web/
├─ test/
├─ pubspec.yaml
├─ pubspec.lock
├─ firebase.json
└─ README.md  <-- (this file - updated)
```

**Key files to inspect quickly:** `lib/trrive_social_arcade.dart`, `lib/trrive_map_module.dart`, `lib/trrive_cricket_module.dart`, `lib/main.dart`.

---

## Quick start (run locally)

### Prerequisites

* Flutter SDK (recommend stable; specify version in local dev notes). Example: Flutter 3.10+ or later.
* A Firebase project for web/mobile with Firestore and Authentication enabled.
* (Optional) An API key for Gemini / Google Generative AI if you plan to use the Oracle feature.

> NOTE: The repository currently contains references where Firebase config and GeminI API keys may be set in code. **Do not commit** your real keys to the repository.

### 1) Clone & install

```bash
git clone https://github.com/Sidharthgomasa/TRIVVE.git
cd TRIVVE
flutter pub get
```

### 2) Firebase setup

1. Create a Firebase project at the Firebase console.
2. Add a web app (or Android/iOS depending on your target) and copy the config keys.
3. In your local project, DO NOT paste keys directly into committed code. Instead use environment variables or a local file that is gitignored.

**If you prefer quick testing** and understand the risk, the repo previously expected Firebase config to be available in `lib/main.dart`. Replace the placeholder config values with your project's config for development only.

**Firestore rules (recommended):** Add `firestore.rules` in repo root and configure to allow only authenticated reads/writes in production. Example:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 3) Gemini / AI setup (Oracle)

* The OracleScreen (in `trrive_social_arcade.dart`) references using Google Generative AI (Gemini) via a package like `google_generative_ai`.
* **Do not store** your API key in the repo. Use a local env file or a server-side proxy that holds the key.
* If you want to test without Gemini, stub the Oracle responses or disable the screen.

### 4) Environment variables example

Use `.env` (with `flutter_dotenv`) or a JSON file loaded at runtime (gitignored).

Example `.env` (DO NOT CHECK IN):

```
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_project.appspot.com
FIREBASE_MESSAGING_SENDER_ID=xxxx
FIREBASE_APP_ID=1:xxxx:web:yyyy
GEMINI_API_KEY=your_gemini_api_key
```

**Add `.env` to `.gitignore`** and keep a sample `.env.example` in repo for contributors.

### 5) Run for web (recommended)

```bash
flutter run -d web-server
# or
flutter run -d edge  # if targeting Edge as the README suggests
```

To build a production web artifact:

```bash
flutter build web
# then serve the contents of build/web (or use Firebase Hosting)
```

---

## Development notes & tips

* The map module uses tile servers (CartoDB Dark Matter). Check rate-limits and attribution requirements for the tile provider you choose.
* Location updates can cause many Firestore writes. Implement throttling/debouncing and only write when necessary.
* The arcade games and cricket scorer are mostly client-side. If you need competitive correctness, add server-side authoritative checks.
* Dare/wagering features carry legal considerations. If you plan to add real money wagers, consult legal counsel and integrate a secure, KYC-compliant payment provider.

---

## Testing

* There is a `test/` folder but the repo currently lacks a comprehensive test-suite. Add unit tests for:

  * Cricket scoring calculations and boundary conditions
  * Game victory/draw logic (TicTacToe, Connect4, Gomoku)
  * Squad join/create flow
  * Map marker serialization/deserialization

Run tests with:

```bash
flutter test
```

---

## CI / GitHub Actions suggestions

Add a workflow that runs on PRs and `push` to main:

* `flutter analyze`
* `flutter test`
* `flutter build web` (or a matrix of platforms)

A sample minimal workflow in `.github/workflows/ci.yml` is recommended.

---

## Security, privacy & legal

* **Secrets**: Rotate any keys already exposed in commits. Remove hardcoded API keys and use secure storage.
* **Location data**: Treat user location as sensitive. Implement explicit consent, allow users to disable location sharing, and remove precise location from public feeds by default.
* **User content moderation**: Add reporting, automated moderation (keyword filters), and the ability to remove/appeal content.
* **Firestore rules**: Lock down read/write to authenticated users and separate public vs private documents.
* **Wagers / Monetary features**: Avoid adding real-money wagers without legal compliance and proper payment provider integrations.

---

## Roadmap & recommended improvements

Practical short-term improvements:

1. Extract Firebase and API keys into environment variables and add `.env.example`.
2. Add Firestore rules and example `firebaserc` targeting dev/staging/prod.
3. Add unit tests for the cricket module and at least one arcade game's logic.
4. Add GitHub Actions for lint & tests.
5. Add an Analytics + Crashlytics integration for monitoring.
6. Implement server-side proxy (Cloud Function) for Gemini requests to keep keys secret and enable quota control.

Longer term / product ideas:

* Offline-first cricket scorer with local persistence and sync.
* Rate-limited location broadcasting and heatmap aggregation to save costs.
* Admin moderation console for map events and pulses.
* Monetization: XP packs, cosmetics, and non-gambling virtual items.

---

## Contribution guide

If you want others to contribute, add these files & policies:

* `CONTRIBUTING.md` with PR template and coding style
* `CODE_OF_CONDUCT.md`
* `ISSUE_TEMPLATE.md` and `PULL_REQUEST_TEMPLATE.md`
* `analysis_options.yaml` for lint rules (consider enabling strict lints)

A recommended PR flow:

1. Fork repo
2. Create feature branch
3. Add tests for new logic
4. Create a PR with description, screenshots, and test results

---

## License & contact

* **License:** MIT (as indicated in the repository)
* **Author / Contact:** Sidharth Gomasa — [sidharthgomasa04@gmail.com](mailto:sidharthgomasa04@gmail.com)

---

## Final notes

This README is written to reflect the repository's current layout and code usage. Before production deployment, rotate any exposed keys, add server-side protections for AI keys, and implement privacy safeguards for location and user-generated content.

If you want, I can now:

* Create example `.env.example` and `.gitignore` additions, OR
* Create a GitHub Actions CI workflow file, OR
* Generate a small unit test for the cricket scorer (choose a file) — tell me which and I'll add it.
