import 'package:flutter/material.dart';

// ==============================================================================
// 1. DATA MODELS (Editable & Comprehensive)
// ==============================================================================

enum DismissalType {
  notOut, bowled, caught, lbw, runOut, stumped, hitWicket, retiredHurt, timedOut
}

enum ExtraType { none, wide, noBall, bye, legBye, penalty }

class MatchSettings {
  int totalOvers;
  int maxOversPerBowler;
  int maxBouncersPerOver;
  bool wideReball; // usually true
  bool noBallReball; // usually true

  MatchSettings({
    this.totalOvers = 20,
    this.maxOversPerBowler = 4,
    this.maxBouncersPerOver = 2,
    this.wideReball = true,
    this.noBallReball = true,
  });
}

class Player {
  String id;
  String name;
  String role; // 'Batsman', 'Bowler', 'All-Rounder', 'WK'
  
  Player({required this.id, required this.name, this.role = 'Batsman'});
}

class Team {
  String id;
  String name;
  List<Player> squad;
  
  Team({required this.id, required this.name, required this.squad});
}

// --- Granular Ball Data for Undo/Replay ---
class BallData {
  final int ballIndex;
  final String overDisplay; // 0.1, 0.2
  final String bowlerId;
  final String strikerId;
  final String nonStrikerId;
  final int runsScored; // Runs off bat
  final int extras;
  final ExtraType extraType;
  final bool isWicket;
  final DismissalType dismissalType;
  final String? wicketPlayerId; // Who got out
  final bool isBouncer;
  final bool isFreeHit;

  BallData({
    required this.ballIndex, required this.overDisplay, required this.bowlerId,
    required this.strikerId, required this.nonStrikerId, required this.runsScored,
    required this.extras, required this.extraType, this.isWicket = false,
    this.dismissalType = DismissalType.notOut, this.wicketPlayerId,
    this.isBouncer = false, this.isFreeHit = false
  });
}

class InningsState {
  int inningsNo;
  String battingTeamId;
  String bowlingTeamId;
  
  // Scoring
  int totalRuns = 0;
  int totalWickets = 0;
  int legalBalls = 0;
  
  // Over Logic
  int currentBouncersInOver = 0;
  bool isFreeHitPending = false;
  
  List<BallData> history = [];
  List<String> fallOfWickets = [];
  
  // Player Stats Maps
  Map<String, int> batRuns = {};
  Map<String, int> batBalls = {};
  Map<String, int> bowlRuns = {};
  Map<String, int> bowlWickets = {};
  Map<String, int> bowlLegalBalls = {}; // To track overs bowled
  
  InningsState(this.inningsNo, this.battingTeamId, this.bowlingTeamId);
  
  String get oversDisplay => "${legalBalls ~/ 6}.${legalBalls % 6}";
  double get runRate => legalBalls > 0 ? (totalRuns / (legalBalls/6)) : 0.0;
}

// ==============================================================================
// 2. LOGIC ENGINE (Rules Implementation)
// ==============================================================================

class TrriveScoringEngine extends ChangeNotifier {
  MatchSettings settings = MatchSettings();
  Team? teamA;
  Team? teamB;
  
  InningsState? currentInnings;
  
  // Live Pointers
  String currentStrikerId = "";
  String currentNonStrikerId = "";
  String currentBowlerId = "";
  
  // Undo Stack (List of Snapshots could go here, for now using direct reversal logic)

  // --- A. MATCH SETUP ---
  void startMatch(Team a, Team b, MatchSettings matchSettings) {
    teamA = a;
    teamB = b;
    settings = matchSettings;
    
    // Auto-calculate max overs if Custom
    if (settings.totalOvers != 20 && settings.totalOvers != 50) {
      settings.maxOversPerBowler = (settings.totalOvers / 5).ceil();
    }
    
    _startInnings(1, teamA!, teamB!); // Assume Team A bats first for demo
  }

  void _startInnings(int no, Team batTeam, Team bowlTeam) {
    currentInnings = InningsState(no, batTeam.id, bowlTeam.id);
    
    // Auto-select first two players
    currentStrikerId = batTeam.squad[0].id;
    currentNonStrikerId = batTeam.squad[1].id;
    
    // Force user to select bowler via UI, but we initialize to index 0 to avoid nulls
    currentBowlerId = bowlTeam.squad[0].id;
    
    _initStats(batTeam, bowlTeam);
    notifyListeners();
  }
  
  void _initStats(Team bat, Team bowl) {
    for (var p in bat.squad) { currentInnings!.batRuns[p.id] = 0; currentInnings!.batBalls[p.id] = 0; }
    for (var p in bowl.squad) { currentInnings!.bowlRuns[p.id] = 0; currentInnings!.bowlWickets[p.id] = 0; currentInnings!.bowlLegalBalls[p.id] = 0; }
  }

  // --- B. VALIDATION ---
  String? validateBowler(String bowlerId) {
    // 1. Check Consecutive Overs
    if (currentInnings!.history.isNotEmpty) {
      String lastBowler = currentInnings!.history.last.bowlerId;
      if (lastBowler == bowlerId && currentInnings!.legalBalls % 6 == 0 && currentInnings!.legalBalls > 0) {
        return "Bowler cannot bowl consecutive overs";
      }
    }
    
    // 2. Check Max Overs
    int balls = currentInnings!.bowlLegalBalls[bowlerId] ?? 0;
    if ((balls ~/ 6) >= settings.maxOversPerBowler) {
      return "Bowler has finished quota (${settings.maxOversPerBowler})";
    }
    return null;
  }

  // --- C. CORE SCORING TRANSACTION ---
  void processDelivery({
    required int runs, 
    required ExtraType extraType, 
    required bool isWicket,
    DismissalType dismissalType = DismissalType.notOut,
    String? whoOutId, // If runout, could be striker or non-striker
    bool isBouncer = false,
  }) {
    final inn = currentInnings!;
    
    // 1. BOUNCER CHECK
    if (isBouncer) {
      inn.currentBouncersInOver++;
      if (inn.currentBouncersInOver > settings.maxBouncersPerOver) {
        // Auto-convert to No Ball
        extraType = ExtraType.noBall;
      }
    }

    // 2. CALCULATE VALUES
    int totalRunCredit = 0;
    int batRunCredit = 0;
    int bowlRunDebit = 0;
    bool isLegal = true;
    bool faceBall = true;

    // --- LOGIC MATRIX ---
    switch (extraType) {
      case ExtraType.none:
        batRunCredit = runs;
        bowlRunDebit = runs;
        totalRunCredit = runs;
        break;
      case ExtraType.wide:
        isLegal = false;
        faceBall = false;
        totalRunCredit = 1 + runs; // 1 wide + runs ran
        bowlRunDebit = 1 + runs;
        // Runs ran on wide go to extras in strict rules, or bowler? 
        // Trrive Rule: Wide + Runs counts as Extras total.
        break;
      case ExtraType.noBall:
        isLegal = false;
        faceBall = true; // NB counts as ball faced by batsman for stats
        batRunCredit = runs; // Runs off bat count
        totalRunCredit = 1 + runs;
        bowlRunDebit = 1 + runs;
        inn.isFreeHitPending = true; // Trigger Free Hit
        break;
      case ExtraType.bye:
        faceBall = true;
        totalRunCredit = runs;
        // Byes charged to extras, not bowler in strict analysis usually
        // But for simple T20, often charged to bowler economy. 
        // We will separate them:
        bowlRunDebit = 0; 
        break;
      case ExtraType.legBye:
        faceBall = true;
        totalRunCredit = runs;
        bowlRunDebit = 0;
        break;
      case ExtraType.penalty:
        totalRunCredit = runs;
        bowlRunDebit = 0;
        isLegal = false; // Usually dead ball
        faceBall = false;
        break;
    }

    // 3. UPDATE STATS
    inn.totalRuns += totalRunCredit;
    
    inn.batRuns[currentStrikerId] = (inn.batRuns[currentStrikerId] ?? 0) + batRunCredit;
    if(faceBall && extraType != ExtraType.wide) {
       inn.batBalls[currentStrikerId] = (inn.batBalls[currentStrikerId] ?? 0) + 1;
    }

    inn.bowlRuns[currentBowlerId] = (inn.bowlRuns[currentBowlerId] ?? 0) + bowlRunDebit;
    
    if (isLegal) {
      inn.legalBalls++;
      inn.bowlLegalBalls[currentBowlerId] = (inn.bowlLegalBalls[currentBowlerId] ?? 0) + 1;
      
      // Reset Free Hit if a legal ball was bowled (unless it was the free hit itself, simplistic logic)
      if (inn.isFreeHitPending && extraType == ExtraType.none) {
         inn.isFreeHitPending = false; 
      }
    }

    // 4. HANDLE WICKET
    if (isWicket) {
      inn.totalWickets++;
      
      // Credit Bowler?
      if (dismissalType != DismissalType.runOut && dismissalType != DismissalType.timedOut && dismissalType != DismissalType.retiredHurt) {
        inn.bowlWickets[currentBowlerId] = (inn.bowlWickets[currentBowlerId] ?? 0) + 1;
      }

      String dismissedId = whoOutId ?? currentStrikerId;
      inn.fallOfWickets.add("${inn.totalRuns}/${inn.totalWickets}");
      
      // Auto-replace Logic handled in UI prompt usually, but here we update pointers if needed
      if (dismissedId == currentStrikerId) {
        // Striker out
      }
    }

    // 5. HISTORY
    inn.history.add(BallData(
      ballIndex: inn.history.length,
      overDisplay: inn.oversDisplay,
      bowlerId: currentBowlerId,
      strikerId: currentStrikerId,
      nonStrikerId: currentNonStrikerId,
      runsScored: batRunCredit,
      extras: totalRunCredit - batRunCredit,
      extraType: extraType,
      isWicket: isWicket,
      dismissalType: dismissalType,
      isBouncer: isBouncer,
      isFreeHit: inn.isFreeHitPending
    ));

    // 6. STRIKE ROTATION
    // Logic: Odd runs = swap.
    // If runs were run (Byes, Legbyes, Wides+Runs, NoBall+Runs) -> Swap
    int runsRan = batRunCredit;
    if (extraType == ExtraType.bye || extraType == ExtraType.legBye) runsRan = runs;
    if (extraType == ExtraType.wide || extraType == ExtraType.noBall) runsRan = runs; // Approx

    if (runsRan % 2 != 0) _swapEnds();

    // 7. END OF OVER
    if (isLegal && inn.legalBalls % 6 == 0) {
      _swapEnds(); // Swap at end of over
      inn.currentBouncersInOver = 0; // Reset bouncer count
      // UI must trigger "Select New Bowler" dialog
    }

    notifyListeners();
  }

  void _swapEnds() {
    String temp = currentStrikerId;
    currentStrikerId = currentNonStrikerId;
    currentNonStrikerId = temp;
  }

  void changeBowler(String newBowlerId) {
    if (validateBowler(newBowlerId) == null) {
      currentBowlerId = newBowlerId;
      notifyListeners();
    }
  }

  void replaceBatsman(String oldId, String newId) {
    if (currentStrikerId == oldId) currentStrikerId = newId;
    if (currentNonStrikerId == oldId) currentNonStrikerId = newId;
    // Init stats for new guy
    if(!currentInnings!.batRuns.containsKey(newId)) {
      currentInnings!.batRuns[newId] = 0;
      currentInnings!.batBalls[newId] = 0;
    }
    notifyListeners();
  }
}

// ==============================================================================
// 3. UI: MATCH SETUP (User Inputs)
// ==============================================================================

class TrriveMatchSetup extends StatefulWidget {
  final Function(Team, Team, MatchSettings) onStart;
  const TrriveMatchSetup({super.key, required this.onStart});

  @override
  State<TrriveMatchSetup> createState() => _TrriveMatchSetupState();
}

class _TrriveMatchSetupState extends State<TrriveMatchSetup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _teamAController = TextEditingController(text: "Team A");
  final TextEditingController _teamBController = TextEditingController(text: "Team B");
  final TextEditingController _oversController = TextEditingController(text: "20");
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("MATCH SETUP"), backgroundColor: Colors.grey[900]),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text("Team Details", style: TextStyle(color: Colors.cyanAccent, fontSize: 18)),
            const SizedBox(height: 10),
            _input(_teamAController, "Home Team Name"),
            const SizedBox(height: 10),
            _input(_teamBController, "Away Team Name"),
            
            const SizedBox(height: 20),
            const Text("Match Rules", style: TextStyle(color: Colors.cyanAccent, fontSize: 18)),
            const SizedBox(height: 10),
            _input(_oversController, "Overs Per Innings", isNumber: true),
            
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.all(15)),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // Create Dummy Squads for Demo (In real app, add a player adder loop here)
                  Team a = Team(id: "T1", name: _teamAController.text, squad: List.generate(11, (i) => Player(id: "T1P$i", name: "${_teamAController.text} Player ${i+1}")));
                  Team b = Team(id: "T2", name: _teamBController.text, squad: List.generate(11, (i) => Player(id: "T2P$i", name: "${_teamBController.text} Player ${i+1}")));
                  MatchSettings settings = MatchSettings(totalOvers: int.parse(_oversController.text));
                  
                  widget.onStart(a, b, settings);
                }
              },
              child: const Text("START MATCH", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
      ),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );
  }
}

// ==============================================================================
// 4. UI: MAIN SCORER
// ==============================================================================

class TrriveProScorecard extends StatefulWidget {
  const TrriveProScorecard({super.key});

  @override
  State<TrriveProScorecard> createState() => _TrriveProScorecardState();
}

class _TrriveProScorecardState extends State<TrriveProScorecard> {
  final TrriveScoringEngine engine = TrriveScoringEngine();
  bool isSetup = false;

  @override
  void initState() {
    super.initState();
    engine.addListener(() => setState((){}));
  }

  void _handleWicketPress() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("WICKET DETAILS", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: DismissalType.values.where((e) => e != DismissalType.notOut).map((type) => 
                ActionChip(
                  label: Text(type.name.toUpperCase()),
                  backgroundColor: Colors.red[900],
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmWicket(type);
                  },
                )
              ).toList(),
            )
          ],
        ),
      )
    );
  }

  void _confirmWicket(DismissalType type) {
    // Determine who is out (Simplified: Striker usually, unless run out logic added)
    String whoOut = engine.currentStrikerId;
    if (type == DismissalType.runOut) {
      // In a real app, ask "Who got out? Striker or Non-Striker?"
      // For demo, we assume Striker
    }
    
    engine.processDelivery(runs: 0, extraType: ExtraType.none, isWicket: true, dismissalType: type, whoOutId: whoOut);
    
    // Prompt for new batsman
    _showNewBatsmanDialog(whoOut);
  }

  void _showNewBatsmanDialog(String outPlayerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("NEW BATSMAN", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: engine.teamA!.squad.where((p) => 
            !engine.currentInnings!.batRuns.containsKey(p.id) // Only show players who haven't batted
          ).map((p) => ListTile(
            title: Text(p.name, style: const TextStyle(color: Colors.white)),
            onTap: () {
              engine.replaceBatsman(outPlayerId, p.id);
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      )
    );
  }

  void _showBowlerSelectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("SELECT BOWLER", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: engine.teamB!.squad.map((p) {
              String? error = engine.validateBowler(p.id);
              return ListTile(
                title: Text(p.name, style: TextStyle(color: error == null ? Colors.white : Colors.grey)),
                subtitle: error != null ? Text(error, style: const TextStyle(color: Colors.red, fontSize: 10)) : null,
                enabled: error == null,
                onTap: error == null ? () {
                  engine.changeBowler(p.id);
                  Navigator.pop(ctx);
                } : null,
              );
            }).toList(),
          ),
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isSetup) {
      return TrriveMatchSetup(onStart: (a, b, s) {
        engine.startMatch(a, b, s);
        setState(() => isSetup = true);
      });
    }

    final inn = engine.currentInnings!;
    bool isOverComplete = inn.legalBalls > 0 && inn.legalBalls % 6 == 0;

    // Auto-trigger bowler select at end of over
    if (isOverComplete && inn.history.last.ballIndex == inn.history.length - 1) {
      // Small delay to let UI render first
      // WidgetsBinding.instance.addPostFrameCallback((_) => _showBowlerSelectDialog());
      // Note: In manual apps, usually user clicks "Start Next Over" button
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("${engine.teamA!.name} vs ${engine.teamB!.name}"),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () { /* Edit Match Settings */ }),
        ],
      ),
      body: Column(
        children: [
          // 1. SCOREBOARD HEADER
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[850],
            child: Column(
              children: [
                Text("${inn.totalRuns} / ${inn.totalWickets}", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                Text("Overs: ${inn.oversDisplay} (${engine.settings.totalOvers})  |  RR: ${inn.runRate.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white70)),
                if (inn.isFreeHitPending) 
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(5)),
                    child: const Text("FREE HIT!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 10),
                // Recent Balls
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: inn.history.reversed.take(8).toList().reversed.map((b) => _ballWidget(b)).toList(),
                  ),
                )
              ],
            ),
          ),

          // 2. PLAYERS
          Expanded(
            child: ListView(
              children: [
                _playerTile(engine.currentStrikerId, true, inn),
                _playerTile(engine.currentNonStrikerId, false, inn),
                const Divider(color: Colors.white24),
                ListTile(
                  title: Text(engine.teamB!.squad.firstWhere((p) => p.id == engine.currentBowlerId).name, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  subtitle: Text("${inn.bowlWickets[engine.currentBowlerId]}-${inn.bowlRuns[engine.currentBowlerId]} (${(inn.bowlLegalBalls[engine.currentBowlerId]??0)~/6}.${(inn.bowlLegalBalls[engine.currentBowlerId]??0)%6})", style: const TextStyle(color: Colors.white70)),
                  trailing: isOverComplete 
                    ? ElevatedButton(onPressed: _showBowlerSelectDialog, child: const Text("CHANGE"))
                    : const Icon(Icons.sports_cricket, color: Colors.white24),
                ),
              ],
            ),
          ),

          // 3. CONTROLS
          if (isOverComplete)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.grey[900],
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _showBowlerSelectDialog,
                child: const Text("START NEXT OVER"),
              ),
            )
          else
            _buildKeypad(),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _btn("0", () => engine.processDelivery(runs: 0, extraType: ExtraType.none, isWicket: false)),
              _btn("1", () => engine.processDelivery(runs: 1, extraType: ExtraType.none, isWicket: false)),
              _btn("2", () => engine.processDelivery(runs: 2, extraType: ExtraType.none, isWicket: false)),
              _btn("4", () => engine.processDelivery(runs: 4, extraType: ExtraType.none, isWicket: false), color: Colors.green),
              _btn("6", () => engine.processDelivery(runs: 6, extraType: ExtraType.none, isWicket: false), color: Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _miniBtn("WIDE", () => engine.processDelivery(runs: 0, extraType: ExtraType.wide, isWicket: false)),
              _miniBtn("NO BALL", () => engine.processDelivery(runs: 0, extraType: ExtraType.noBall, isWicket: false)),
              _miniBtn("BOUNCER", () => engine.processDelivery(runs: 0, extraType: ExtraType.none, isWicket: false, isBouncer: true)),
              _miniBtn("WICKET", _handleWicketPress, isRed: true),
            ],
          )
        ],
      ),
    );
  }

  Widget _playerTile(String pid, bool striker, InningsState inn) {
    var p = engine.teamA!.squad.firstWhere((element) => element.id == pid);
    return ListTile(
      leading: Icon(Icons.person, color: striker ? Colors.cyanAccent : Colors.grey),
      title: Text(p.name, style: TextStyle(color: striker ? Colors.white : Colors.white60, fontWeight: striker ? FontWeight.bold : FontWeight.normal)),
      trailing: Text("${inn.batRuns[pid]} (${inn.batBalls[pid]})", style: const TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  Widget _ballWidget(BallData b) {
    String txt = "${b.runsScored + b.extras}";
    Color c = Colors.grey;
    if (b.isWicket) { txt = "W"; c = Colors.red; }
    else if (b.extraType == ExtraType.wide) { txt = "WD"; c = Colors.orange; }
    else if (b.extraType == ExtraType.noBall) { txt = "NB"; c = Colors.orange; }
    else if (b.runsScored == 4) c = Colors.green;
    else if (b.runsScored == 6) c = Colors.cyan;

    return Container(
      margin: const EdgeInsets.all(2),
      width: 30, height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withOpacity(0.2), border: Border.all(color: c), shape: BoxShape.circle),
      child: Text(txt, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _btn(String txt, VoidCallback tap, {Color? color}) {
    return InkWell(
      onTap: tap,
      child: CircleAvatar(
        radius: 25,
        backgroundColor: (color ?? Colors.white).withOpacity(0.1),
        child: Text(txt, style: TextStyle(color: color ?? Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _miniBtn(String txt, VoidCallback tap, {bool isRed = false}) {
    return ElevatedButton(
      onPressed: tap,
      style: ElevatedButton.styleFrom(backgroundColor: isRed ? Colors.red : Colors.grey[800], padding: const EdgeInsets.symmetric(horizontal: 10)),
      child: Text(txt, style: const TextStyle(fontSize: 10, color: Colors.white)),
    );
  }
}