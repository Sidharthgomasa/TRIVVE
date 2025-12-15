import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// ==============================================================================
// 1. DATA MODELS
// ==============================================================================

enum MatchType { T20, ODI, Test, Custom }
enum PitchType { Dry, Green, Dusty, Flat }
enum Weather { Sunny, Overcast, Rainy }
enum TossDecision { Bat, Bowl }
enum MatchStatus { NotStarted, Live, SelectBatsman, SelectBowler, InningsBreak, Completed, Abandoned }
enum Role { Batsman, Bowler, AllRounder, WicketKeeper }
enum DismissalType { NotOut, Bowled, Caught, LBW, RunOut, Stumped, HitWicket, RetiredHurt }
enum ExtraType { None, Wide, NoBall, Bye, LegBye, Penalty }

class MatchInfo {
  String matchId;
  String matchName;
  MatchType matchType;
  int oversLimit;
  int ballsPerOver;
  int maxBouncersPerOver;
  String venue;
  String city;
  String country;
  PitchType pitchType;
  Weather weather;
  String tossWinner;
  TossDecision tossDecision;
  String umpire1;
  String umpire2;
  String matchReferee;
  DateTime startTime;
  MatchStatus status;

  MatchInfo({
    required this.matchId, required this.matchName, required this.matchType,
    this.oversLimit = 20, this.ballsPerOver = 6, this.maxBouncersPerOver = 1,
    this.venue = "Stadium", this.city = "City", this.country = "Country",
    this.pitchType = PitchType.Flat, this.weather = Weather.Sunny,
    this.tossWinner = "", this.tossDecision = TossDecision.Bat,
    this.umpire1 = "Umpire 1", this.umpire2 = "Umpire 2", this.matchReferee = "Ref",
    required this.startTime, this.status = MatchStatus.NotStarted
  });

  Map<String, dynamic> toMap() {
    return {
      'match_id': matchId, 'match_name': matchName, 'match_type': matchType.name,
      'overs_limit': oversLimit, 'venue': venue, 'city': city, 'country': country,
      'pitch_type': pitchType.name, 'weather': weather.name, 'toss_winner': tossWinner,
      'toss_decision': tossDecision.name, 'start_time': startTime.toIso8601String(),
      'status': status.name
    };
  }
}

class Player {
  String playerId;
  String playerName;
  int jerseyNumber;
  Role role;
  String battingStyle;
  String bowlingStyle;
  bool isCaptain;
  bool isWicketKeeper;
  bool isPlaying;

  // Live Stats
  int runsScored = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;
  DismissalType dismissalType = DismissalType.NotOut;
  String dismissedBy = "";
  
  // Bowling Stats
  int ballsBowledLegal = 0;
  int runsConceded = 0;
  int wicketsTaken = 0;
  int wides = 0;
  int noBalls = 0;
  int dotBalls = 0;

  bool hasBatted = false; // To filter list
  bool isCurrentlyBatting = false;

  Player({
    required this.playerId, required this.playerName, this.jerseyNumber = 0,
    this.role = Role.Batsman, this.battingStyle = "Right", this.bowlingStyle = "Medium",
    this.isCaptain = false, this.isWicketKeeper = false, this.isPlaying = true
  });

  Map<String, dynamic> toMap() {
    return {
      'id': playerId, 'name': playerName, 'runs': runsScored, 'balls': ballsFaced,
      '4s': fours, '6s': sixes, 'out': dismissalType.name,
      'bowl_runs': runsConceded, 'wickets': wicketsTaken, 'overs': "${ballsBowledLegal~/6}.${ballsBowledLegal%6}"
    };
  }
}

class Team {
  String teamId;
  String teamName;
  String shortName;
  List<Player> playingXI;
  int totalRuns = 0;
  int totalWickets = 0;
  int legalBalls = 0;
  List<String> fallOfWickets = []; 

  Team({required this.teamId, required this.teamName, required this.shortName, required this.playingXI});

  Map<String, dynamic> toMap() {
    return {
      'id': teamId, 'name': teamName, 'score': totalRuns, 'wickets': totalWickets,
      'overs': "${legalBalls~/6}.${legalBalls%6}", 'players': playingXI.map((p) => p.toMap()).toList()
    };
  }
}

class BallEvent {
  int overNumber;
  int ballNumber;
  String bowlerName;
  String batsmanName;
  int runsOffBat;
  ExtraType extraType;
  int extraRuns;
  bool isWicket;
  String commentary;
  DateTime timestamp;

  BallEvent({
    required this.overNumber, required this.ballNumber, required this.bowlerName,
    required this.batsmanName, required this.runsOffBat, required this.extraType,
    required this.extraRuns, required this.isWicket, required this.commentary,
    required this.timestamp
  });

  Map<String, dynamic> toMap() {
    return {
      'over': "$overNumber.$ballNumber", 'bowler': bowlerName, 'batter': batsmanName,
      'runs': runsOffBat, 'extra': extraType.name, 'wicket': isWicket, 'comm': commentary
    };
  }
}

// ==============================================================================
// 2. LOGIC ENGINE
// ==============================================================================

class CricketEngine extends ChangeNotifier {
  late MatchInfo matchInfo;
  late Team homeTeam;
  late Team awayTeam;
  
  // State
  bool isSecondInnings = false;
  int? targetScore;
  Team? battingTeam;
  Team? bowlingTeam;
  
  // Indices
  int strikerIndex = 0;
  int nonStrikerIndex = 1;
  int bowlerIndex = 10; 
  int previousBowlerIndex = -1; // For consecutive over rule

  // Stats
  int currentPartnershipRuns = 0;
  int currentPartnershipBalls = 0;
  List<String> last6Balls = [];
  List<BallEvent> matchHistory = [];
  String matchResultText = "";
  int totalExtras = 0;

  // --- INITIALIZATION ---
  void initMatch(MatchInfo info, Team t1, Team t2) {
    matchInfo = info;
    homeTeam = t1;
    awayTeam = t2;
    
    // Toss Logic
    if (info.tossDecision == TossDecision.Bat) {
       _setInnings(info.tossWinner == t1.teamName ? t1 : t2, info.tossWinner == t1.teamName ? t2 : t1);
    } else {
       _setInnings(info.tossWinner == t1.teamName ? t2 : t1, info.tossWinner == t1.teamName ? t1 : t2);
    }
    matchInfo.status = MatchStatus.Live;
    notifyListeners();
  }

  void _setInnings(Team bat, Team bowl) {
    battingTeam = bat;
    bowlingTeam = bowl;
    
    // Set Openers flags
    strikerIndex = 0; 
    nonStrikerIndex = 1;
    bat.playingXI[0].hasBatted = true; bat.playingXI[0].isCurrentlyBatting = true;
    bat.playingXI[1].hasBatted = true; bat.playingXI[1].isCurrentlyBatting = true;
    
    // Auto-select last player as bowler (Can be changed immediately)
    bowlerIndex = bowl.playingXI.length - 1;
    previousBowlerIndex = -1;
    
    currentPartnershipRuns = 0;
    currentPartnershipBalls = 0;
    last6Balls.clear();
  }

  void processBall(int runs, ExtraType extra, bool isWicket, DismissalType dismissal) {
    if (matchInfo.status != MatchStatus.Live) return;

    int runsScored = runs;
    int extrasConceded = 0;
    bool isLegal = true;

    if (extra == ExtraType.Wide || extra == ExtraType.NoBall) {
      isLegal = false;
      extrasConceded = 1 + runs; 
      if (extra == ExtraType.Wide) runsScored = 0; 
    } else if (extra == ExtraType.Bye || extra == ExtraType.LegBye) {
      extrasConceded = runs; runsScored = 0;
    }

    int totalBallRuns = runsScored + extrasConceded;
    
    // Update Team Score
    battingTeam!.totalRuns += totalBallRuns;
    totalExtras += extrasConceded;
    if (isLegal) battingTeam!.legalBalls++;

    // Update Batsman
    Player striker = battingTeam!.playingXI[strikerIndex];
    if (extra != ExtraType.Wide) striker.ballsFaced++;
    striker.runsScored += runsScored;
    if (runsScored == 4) striker.fours++;
    if (runsScored == 6) striker.sixes++;

    // Update Bowler
    Player bowler = bowlingTeam!.playingXI[bowlerIndex];
    bowler.runsConceded += totalBallRuns;
    if (extra == ExtraType.Bye || extra == ExtraType.LegBye) bowler.runsConceded -= totalBallRuns; 

    if (isLegal) {
      bowler.ballsBowledLegal++;
      if (totalBallRuns == 0) bowler.dotBalls++;
    } else {
      if (extra == ExtraType.Wide) bowler.wides++;
      if (extra == ExtraType.NoBall) bowler.noBalls++;
    }

    // --- WICKET LOGIC (MANUAL SELECTION TRIGGER) ---
    if (isWicket) {
      battingTeam!.totalWickets++;
      striker.dismissalType = dismissal;
      striker.dismissedBy = bowler.playerName;
      striker.isCurrentlyBatting = false; // He is out!
      if (dismissal != DismissalType.RunOut) bowler.wicketsTaken++;
      
      battingTeam!.fallOfWickets.add("${battingTeam!.totalRuns}/${battingTeam!.totalWickets} (${_getOvers()})");
      currentPartnershipRuns = 0;
      currentPartnershipBalls = 0;

      // TRIGGER MANUAL SELECTION
      if (battingTeam!.totalWickets < 10) {
        matchInfo.status = MatchStatus.SelectBatsman; // 🛑 PAUSE GAME
      }
    } else {
      currentPartnershipRuns += totalBallRuns;
      if (isLegal) currentPartnershipBalls++;
    }

    // History
    String comm = _generateCommentary(runsScored, extra, isWicket, striker.playerName);
    matchHistory.add(BallEvent(
      overNumber: battingTeam!.legalBalls ~/ 6,
      ballNumber: battingTeam!.legalBalls % 6,
      bowlerName: bowler.playerName,
      batsmanName: striker.playerName,
      runsOffBat: runsScored,
      extraType: extra,
      extraRuns: extrasConceded,
      isWicket: isWicket,
      commentary: comm,
      timestamp: DateTime.now()
    ));
    last6Balls.add(isWicket ? "W" : "$totalBallRuns");
    if (last6Balls.length > 6) last6Balls.removeAt(0);

    // Swap Strike
    if (runsScored % 2 != 0) _swapStrike();
    
    // --- OVER END LOGIC (MANUAL SELECTION TRIGGER) ---
    if (isLegal && battingTeam!.legalBalls % 6 == 0) {
      _swapStrike();
      // Only ask for new bowler if innings NOT over
      if (battingTeam!.totalWickets < 10 && (battingTeam!.legalBalls ~/ 6) < matchInfo.oversLimit) {
         matchInfo.status = MatchStatus.SelectBowler; // 🛑 PAUSE GAME
         previousBowlerIndex = bowlerIndex; // Remember who bowled last
      }
    }

    _checkMatchStatus();
    notifyListeners();
  }

  // --- SELECTION FUNCTIONS (CALLED FROM UI) ---
  void selectNewBatsman(int index) {
    strikerIndex = index;
    battingTeam!.playingXI[index].hasBatted = true;
    battingTeam!.playingXI[index].isCurrentlyBatting = true;
    matchInfo.status = MatchStatus.Live; // RESUME GAME
    notifyListeners();
  }

  void selectNewBowler(int index) {
    bowlerIndex = index;
    matchInfo.status = MatchStatus.Live; // RESUME GAME
    notifyListeners();
  }

  void _swapStrike() {
    int temp = strikerIndex; strikerIndex = nonStrikerIndex; nonStrikerIndex = temp;
  }

  String _getOvers() => "${battingTeam!.legalBalls ~/ 6}.${battingTeam!.legalBalls % 6}";

  String _generateCommentary(int runs, ExtraType extra, bool out, String bat) {
    if (out) return "WICKET! $bat is gone.";
    if (runs == 4) return "FOUR! $bat finds the gap.";
    if (runs == 6) return "SIX! Huge hit by $bat.";
    if (extra == ExtraType.Wide) return "Wide ball.";
    return "$runs runs to $bat.";
  }

  void _checkMatchStatus() {
    // 1. Check Win Condition 2nd Innings
    if (isSecondInnings && battingTeam!.totalRuns >= targetScore!) {
        matchInfo.status = MatchStatus.Completed;
        matchResultText = "${battingTeam!.teamName} WON by ${10 - battingTeam!.totalWickets} wickets!";
        return;
    }

    // 2. Check End of Innings (All Out or Overs Done)
    if (battingTeam!.totalWickets == 10 || (battingTeam!.legalBalls ~/ 6) >= matchInfo.oversLimit) {
      if (isSecondInnings) {
        matchInfo.status = MatchStatus.Completed;
        if (battingTeam!.totalRuns < targetScore! - 1) {
           matchResultText = "${bowlingTeam!.teamName} WON by ${(targetScore! - 1) - battingTeam!.totalRuns} runs!";
        } else {
           matchResultText = "MATCH TIED!";
        }
      } else {
        matchInfo.status = MatchStatus.InningsBreak;
        targetScore = battingTeam!.totalRuns + 1;
        isSecondInnings = true;
        // Swap Teams Logic will handle reset
      }
    }
  }
  
  void startSecondInnings() {
    Team temp = battingTeam!; battingTeam = bowlingTeam!; bowlingTeam = temp;
    _setInnings(battingTeam!, bowlingTeam!); // Reset indices
    matchInfo.status = MatchStatus.Live;
    notifyListeners();
  }

  Future<void> saveMatchToLegacy() async {
    try {
      final docMatch = FirebaseFirestore.instance.collection('match_legacy').doc();
      await docMatch.set({
        'match_info': matchInfo.toMap(),
        'home_team': homeTeam.toMap(),
        'away_team': awayTeam.toMap(),
        'ball_by_ball': matchHistory.map((e) => e.toMap()).toList(),
        'result': matchResultText,
        'saved_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error saving legacy: $e");
    }
  }
}

// ==============================================================================
// 3. UI - TRRIVE CRICKET MODULE
// ==============================================================================

class TrriveCricketModule extends StatefulWidget {
  const TrriveCricketModule({super.key});

  @override
  State<TrriveCricketModule> createState() => _TrriveCricketModuleState();
}

class _TrriveCricketModuleState extends State<TrriveCricketModule> {
  final CricketEngine engine = CricketEngine();
  
  // -- SETUP STATE --
  int _currentStep = 0;
  final _team1Ctrl = TextEditingController(text: "India");
  final _team2Ctrl = TextEditingController(text: "Australia");
  final _oversCtrl = TextEditingController(text: "2");
  final _venueCtrl = TextEditingController(text: "Wankhede");
  
  List<TextEditingController> team1Players = List.generate(11, (i) => TextEditingController(text: "Player A${i+1}"));
  List<TextEditingController> team2Players = List.generate(11, (i) => TextEditingController(text: "Player B${i+1}"));

  bool matchStarted = false;

  @override
  Widget build(BuildContext context) {
    if (matchStarted) {
      return AnimatedBuilder(
        animation: engine,
        builder: (ctx, child) {
          // 🛑 HANDLE MANUAL SELECTION STATES HERE
          if (engine.matchInfo.status == MatchStatus.SelectBatsman) return _buildSelectBatsmanScreen();
          if (engine.matchInfo.status == MatchStatus.SelectBowler) return _buildSelectBowlerScreen();
          if (engine.matchInfo.status == MatchStatus.InningsBreak) return _buildInningsBreakScreen();
          if (engine.matchInfo.status == MatchStatus.Completed) return _buildSummaryScreen();
          
          // DEFAULT: Live Match
          return _buildLiveScreen();
        },
      );
    }
    
    // SETUP
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("MATCH SETUP"), backgroundColor: Colors.grey[900]),
      body: Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent)),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _nextStep,
          onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
          controlsBuilder: (ctx, details) => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(children: [
               ElevatedButton(onPressed: details.onStepContinue, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black), child: Text(_currentStep == 2 ? "START MATCH" : "NEXT")),
               const SizedBox(width: 10),
               if (_currentStep > 0) TextButton(onPressed: details.onStepCancel, child: const Text("BACK")),
            ]),
          ),
          steps: [
            Step(title: const Text("Match Info"), content: Column(children: [_input(_team1Ctrl, "Home Team"), const SizedBox(height:10), _input(_team2Ctrl, "Away Team"), const SizedBox(height:10), _input(_oversCtrl, "Overs", isNum: true)]), isActive: _currentStep>=0),
            Step(title: Text("${_team1Ctrl.text} Squad"), content: Column(children: team1Players.asMap().entries.map((e)=>Padding(padding:const EdgeInsets.only(bottom:5), child:_input(e.value, "P${e.key+1}"))).toList()), isActive: _currentStep>=1),
            Step(title: Text("${_team2Ctrl.text} Squad"), content: Column(children: team2Players.asMap().entries.map((e)=>Padding(padding:const EdgeInsets.only(bottom:5), child:_input(e.value, "P${e.key+1}"))).toList()), isActive: _currentStep>=2),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _startMatch();
    }
  }

  void _startMatch() {
    Team t1 = Team(teamId: "T1", teamName: _team1Ctrl.text, shortName: "HOM", playingXI: List.generate(11, (i) => Player(playerId: "H$i", playerName: team1Players[i].text)));
    Team t2 = Team(teamId: "T2", teamName: _team2Ctrl.text, shortName: "AWY", playingXI: List.generate(11, (i) => Player(playerId: "A$i", playerName: team2Players[i].text)));
    MatchInfo info = MatchInfo(matchId: "M_${DateTime.now().millisecondsSinceEpoch}", matchName: "${t1.teamName} vs ${t2.teamName}", matchType: MatchType.T20, oversLimit: int.parse(_oversCtrl.text), venue: _venueCtrl.text, startTime: DateTime.now(), tossWinner: _team1Ctrl.text, tossDecision: TossDecision.Bat);
    engine.initMatch(info, t1, t2);
    setState(() => matchStarted = true);
  }

  // --- SELECTION SCREENS ---
  Widget _buildSelectBatsmanScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("SELECT NEW BATSMAN"), backgroundColor: Colors.redAccent, automaticallyImplyLeading: false),
      body: ListView(
        children: engine.battingTeam!.playingXI.asMap().entries.where((e) => !e.value.hasBatted && !e.value.isCurrentlyBatting).map((e) {
          return ListTile(
            title: Text(e.value.playerName, style: const TextStyle(color: Colors.white, fontSize: 18)),
            leading: const Icon(Icons.person_add, color: Colors.greenAccent),
            onTap: () => engine.selectNewBatsman(e.key),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectBowlerScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("SELECT NEXT BOWLER"), backgroundColor: Colors.orangeAccent, automaticallyImplyLeading: false),
      body: ListView(
        children: engine.bowlingTeam!.playingXI.asMap().entries.where((e) => e.key != engine.previousBowlerIndex).map((e) {
          return ListTile(
            title: Text(e.value.playerName, style: const TextStyle(color: Colors.white, fontSize: 18)),
            subtitle: Text("Figures: ${e.value.wicketsTaken}-${e.value.runsConceded}", style: const TextStyle(color: Colors.grey)),
            leading: const Icon(Icons.sports_baseball, color: Colors.orange),
            onTap: () => engine.selectNewBowler(e.key),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInningsBreakScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("INNINGS BREAK", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text("TARGET: ${engine.targetScore}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 50, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              onPressed: () => engine.startSecondInnings(),
              child: const Text("START 2nd INNINGS", style: TextStyle(fontSize: 20, color: Colors.black)),
            )
          ],
        ),
      ),
    );
  }

  // --- LIVE SCREEN ---
  Widget _buildLiveScreen() {
    Team bat = engine.battingTeam!;
    Player striker = bat.playingXI[engine.strikerIndex];
    Player nonStriker = bat.playingXI[engine.nonStrikerIndex];
    Player bowler = engine.bowlingTeam!.playingXI[engine.bowlerIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Column(children: [
          Text("${bat.teamName} vs ${engine.bowlingTeam!.teamName}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text("${bat.totalRuns}/${bat.totalWickets} (${engine._getOvers()})", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
        actions: [if (engine.isSecondInnings) Center(child: Padding(padding: const EdgeInsets.only(right: 15), child: Text("Target: ${engine.targetScore}", style: const TextStyle(color: Colors.greenAccent))))],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15)),
            child: Column(children: [
              _playerRow(striker, true), _playerRow(nonStriker, false), const Divider(color: Colors.white24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Bowler: ${bowler.playerName}", style: const TextStyle(color: Colors.orangeAccent)), Text("${bowler.wicketsTaken}-${bowler.runsConceded} (${bowler.ballsBowledLegal~/6}.${bowler.ballsBowledLegal%6})", style: const TextStyle(color: Colors.white))]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Part: ${engine.currentPartnershipRuns} (${engine.currentPartnershipBalls})", style: const TextStyle(color: Colors.grey)), Row(children: engine.last6Balls.map((e) => Container(margin: const EdgeInsets.only(left: 5), padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)), child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 10)))).toList())])
            ]),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFF111111), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_btn("0", ()=>engine.processBall(0, ExtraType.None, false, DismissalType.NotOut)), _btn("1", ()=>engine.processBall(1, ExtraType.None, false, DismissalType.NotOut)), _btn("2", ()=>engine.processBall(2, ExtraType.None, false, DismissalType.NotOut)), _btn("4", ()=>engine.processBall(4, ExtraType.None, false, DismissalType.NotOut), c:Colors.green)]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_btn("6", ()=>engine.processBall(6, ExtraType.None, false, DismissalType.NotOut), c:Colors.cyan), _btn("WD", ()=>engine.processBall(0, ExtraType.Wide, false, DismissalType.NotOut), c:Colors.orange), _btn("NB", ()=>engine.processBall(0, ExtraType.NoBall, false, DismissalType.NotOut), c:Colors.orange), _btn("OUT", ()=>engine.processBall(0, ExtraType.None, true, DismissalType.Caught), c:Colors.red)])
            ]),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
         const Icon(Icons.emoji_events, size: 80, color: Colors.amber), const SizedBox(height: 20),
         Text("MATCH COMPLETED", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 30)), const SizedBox(height: 10),
         Text(engine.matchResultText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.cyanAccent, fontSize: 20)), const SizedBox(height: 40),
         ElevatedButton.icon(icon: const Icon(Icons.cloud_upload), label: const Text("SAVE TO LEGACY"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () async { await engine.saveMatchToLegacy(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Match Saved to Legacy Database!"))); }),
         TextButton(child: const Text("Close"), onPressed: () => Navigator.pop(context))
      ])),
    );
  }

  Widget _input(TextEditingController c, String l, {bool isNum=false}) { return TextField(controller: c, keyboardType: isNum?TextInputType.number:TextInputType.text, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.grey[900])); }
  Widget _playerRow(Player p, bool strike) { return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${p.playerName}${strike?' *':''}", style: TextStyle(color: strike?Colors.cyanAccent:Colors.white, fontWeight: strike?FontWeight.bold:FontWeight.normal)), Text("${p.runsScored}(${p.ballsFaced})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]); }
  Widget _btn(String t, VoidCallback tap, {Color c=Colors.grey}) { return InkWell(onTap: tap, child: Container(width: 70, height: 60, alignment: Alignment.center, decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: c)), child: Text(t, style: TextStyle(color: c==Colors.grey?Colors.white:c, fontSize: 20, fontWeight: FontWeight.bold)))); }
}