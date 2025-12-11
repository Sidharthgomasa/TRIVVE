import 'package:flutter/material.dart';

// ==============================================================================
// 1. DATA MODELS
// ==============================================================================

enum DismissalType {
  notOut, bowled, caught, lbw, runOut, stumped, hitWicket, retiredHurt, timedOut
}

enum ExtraType { none, wide, noBall, bye, legBye, penalty }

class MatchSettings {
  int totalOvers;
  int maxOversPerBowler;
  int maxBouncersPerOver;

  MatchSettings({
    this.totalOvers = 20,
    this.maxOversPerBowler = 4,
    this.maxBouncersPerOver = 2,
  });
}

class Player {
  String id;
  String name;
  Player({required this.id, required this.name});
}

class Team {
  String id;
  String name;
  List<Player> squad;
  Team({required this.id, required this.name, required this.squad});
}

class BallData {
  final int ballIndex;
  final String overDisplay;
  final String bowlerId;
  final String strikerId;
  final String nonStrikerId;
  final int runsScored;
  final int extras;
  final ExtraType extraType;
  final bool isWicket;
  final DismissalType dismissalType;
  final String commentary;

  BallData({
    required this.ballIndex, required this.overDisplay, required this.bowlerId,
    required this.strikerId, required this.nonStrikerId, required this.runsScored,
    required this.extras, required this.extraType, this.isWicket = false,
    this.dismissalType = DismissalType.notOut, required this.commentary
  });
}

class InningsState {
  int inningsNo;
  String battingTeamId;
  String bowlingTeamId;
  
  int totalRuns = 0;
  int totalWickets = 0;
  int legalBalls = 0;
  
  // Partnership Logic
  int currentPartnershipRuns = 0;
  int currentPartnershipBalls = 0;
  
  List<BallData> history = [];
  List<String> fallOfWickets = [];
  
  Map<String, int> batRuns = {};
  Map<String, int> batBalls = {};
  Map<String, int> batFours = {}; 
  Map<String, int> batSixes = {}; 
  
  Map<String, int> bowlRuns = {};
  Map<String, int> bowlWickets = {};
  Map<String, int> bowlLegalBalls = {};

  InningsState(this.inningsNo, this.battingTeamId, this.bowlingTeamId);
  
  String get oversDisplay => "${legalBalls ~/ 6}.${legalBalls % 6}";
  double get runRate => legalBalls > 0 ? (totalRuns / (legalBalls/6)) : 0.0;
}

// ==============================================================================
// 2. LOGIC ENGINE
// ==============================================================================

class TrriveScoringEngine extends ChangeNotifier {
  MatchSettings settings = MatchSettings();
  Team? teamA;
  Team? teamB;
  InningsState? currentInnings;
  
  String currentStrikerId = "";
  String currentNonStrikerId = "";
  String currentBowlerId = "";

  // Animation Trigger
  String? lastAnimationEvent; // "4", "6", "OUT"

  void startMatch(Team a, Team b, MatchSettings matchSettings, String sId, String nsId, String bId) {
    teamA = a; teamB = b; settings = matchSettings;
    if (settings.totalOvers != 20 && settings.totalOvers != 50) {
      settings.maxOversPerBowler = (settings.totalOvers / 5).ceil();
    }
    currentInnings = InningsState(1, a.id, b.id);
    currentStrikerId = sId; currentNonStrikerId = nsId; currentBowlerId = bId;
    _initStats(a, b);
    notifyListeners();
  }
  
  void _initStats(Team bat, Team bowl) {
    // Initialize BATSMEN (Only the openers start with data)
    currentInnings!.batRuns[currentStrikerId] = 0;
    currentInnings!.batBalls[currentStrikerId] = 0;
    currentInnings!.batFours[currentStrikerId] = 0;
    currentInnings!.batSixes[currentStrikerId] = 0;

    currentInnings!.batRuns[currentNonStrikerId] = 0;
    currentInnings!.batBalls[currentNonStrikerId] = 0;
    currentInnings!.batFours[currentNonStrikerId] = 0;
    currentInnings!.batSixes[currentNonStrikerId] = 0;

    // Initialize ALL BOWLERS
    for(var p in bowl.squad) {
      currentInnings!.bowlRuns[p.id] = 0; currentInnings!.bowlWickets[p.id] = 0;
      currentInnings!.bowlLegalBalls[p.id] = 0;
    }
  }

  String? validateBowler(String bowlerId) {
    if (currentInnings == null) return null;
    
    // 1. Check Consecutive Overs
    if (currentInnings!.history.isNotEmpty) {
      String lastBowler = currentInnings!.history.last.bowlerId;
      if (lastBowler == bowlerId && currentInnings!.legalBalls % 6 == 0 && currentInnings!.legalBalls > 0) {
        return "Cannot bowl consecutive overs";
      }
    }
    
    // 2. Check Over Quota
    int balls = currentInnings!.bowlLegalBalls[bowlerId] ?? 0;
    if ((balls ~/ 6) >= settings.maxOversPerBowler) {
      return "Quota finished";
    }
    return null;
  }

  void processDelivery({
    required int runs, required ExtraType extraType, required bool isWicket,
    DismissalType dismissalType = DismissalType.notOut
  }) {
    final inn = currentInnings!;
    
    // 1. Animation Logic
    if (isWicket) {
      lastAnimationEvent = "OUT";
    } else if (runs == 4) lastAnimationEvent = "4";
    else if (runs == 6) lastAnimationEvent = "6";
    else lastAnimationEvent = null;

    // 2. Calculation
    int totalCredit = runs;
    bool isLegal = true;
    
    if (extraType == ExtraType.wide || extraType == ExtraType.noBall) {
      isLegal = false; totalCredit += 1;
    }
    
    inn.totalRuns += totalCredit;
    inn.batRuns[currentStrikerId] = (inn.batRuns[currentStrikerId] ?? 0) + runs;
    
    if (isLegal) {
      inn.batBalls[currentStrikerId] = (inn.batBalls[currentStrikerId] ?? 0) + 1;
      inn.legalBalls++;
      inn.bowlLegalBalls[currentBowlerId] = (inn.bowlLegalBalls[currentBowlerId] ?? 0) + 1;
    }
    
    if (runs == 4) inn.batFours[currentStrikerId] = (inn.batFours[currentStrikerId]??0) + 1;
    if (runs == 6) inn.batSixes[currentStrikerId] = (inn.batSixes[currentStrikerId]??0) + 1;

    inn.bowlRuns[currentBowlerId] = (inn.bowlRuns[currentBowlerId] ?? 0) + totalCredit;
    
    // Partnership
    inn.currentPartnershipRuns += totalCredit;
    if (isLegal) inn.currentPartnershipBalls++;

    if (isWicket) {
      inn.totalWickets++;
      if (dismissalType != DismissalType.runOut) {
        inn.bowlWickets[currentBowlerId] = (inn.bowlWickets[currentBowlerId] ?? 0) + 1;
      }
      inn.fallOfWickets.add("${inn.totalRuns}/${inn.totalWickets} (${inn.oversDisplay})");
      inn.currentPartnershipRuns = 0; // Reset Partnership
      inn.currentPartnershipBalls = 0;
    }

    // 3. Commentary Generation
    String comm = _generateCommentary(runs, extraType, isWicket, dismissalType);
    
    inn.history.add(BallData(
      ballIndex: inn.history.length, overDisplay: inn.oversDisplay,
      bowlerId: currentBowlerId, strikerId: currentStrikerId, nonStrikerId: currentNonStrikerId,
      runsScored: runs, extras: totalCredit - runs, extraType: extraType,
      isWicket: isWicket, dismissalType: dismissalType, commentary: comm
    ));

    // 4. Strike Rotation
    if ((runs % 2 != 0 && extraType == ExtraType.none) || 
        (extraType == ExtraType.noBall && runs % 2 != 0)) {
       _swapEnds();
    }
    
    if (isLegal && inn.legalBalls % 6 == 0) {
      _swapEnds();
    }
    
    notifyListeners();
  }

  void _swapEnds() {
    String temp = currentStrikerId; currentStrikerId = currentNonStrikerId; currentNonStrikerId = temp;
  }
  
  void changeBowler(String id) { currentBowlerId = id; notifyListeners(); }
  void replaceBatsman(String outId, String newId) {
    if (currentStrikerId == outId) currentStrikerId = newId;
    if (currentNonStrikerId == outId) currentNonStrikerId = newId;
    // Init stats for new batsman
    if (!currentInnings!.batRuns.containsKey(newId)) {
       currentInnings!.batRuns[newId] = 0;
       currentInnings!.batBalls[newId] = 0;
       currentInnings!.batFours[newId] = 0;
       currentInnings!.batSixes[newId] = 0;
    }
    notifyListeners();
  }

  String _generateCommentary(int runs, ExtraType extra, bool out, DismissalType type) {
    var p = teamA!.squad.firstWhere((e) => e.id == currentStrikerId);
    var b = teamB!.squad.firstWhere((e) => e.id == currentBowlerId);
    
    if (out) return "WICKET! ${p.name} is gone! ${type.name.toUpperCase()} by ${b.name}.";
    if (runs == 6) return "MASSIVE! ${p.name} smashes ${b.name} for a SIX!";
    if (runs == 4) return "FOUR! Beautiful shot by ${p.name} finding the gap.";
    if (extra == ExtraType.wide) return "Wide ball by ${b.name}.";
    if (runs == 0) return "Dot ball. Good bowling by ${b.name}.";
    return "$runs runs taken by ${p.name}.";
  }

  void clearAnimation() {
    lastAnimationEvent = null;
  }
}

// ==============================================================================
// 3. UI: MAIN SCREEN (TABS)
// ==============================================================================

class TrriveProScorecard extends StatefulWidget {
  const TrriveProScorecard({super.key});
  @override
  State<TrriveProScorecard> createState() => _TrriveProScorecardState();
}

class _TrriveProScorecardState extends State<TrriveProScorecard> with SingleTickerProviderStateMixin {
  final TrriveScoringEngine engine = TrriveScoringEngine();
  late TabController _tabController;
  bool isSetup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    engine.addListener(() {
      if (engine.lastAnimationEvent != null) {
        _showAnimationOverlay(engine.lastAnimationEvent!);
        engine.clearAnimation();
      }
      setState((){});
    });
  }

  void _showAnimationOverlay(String type) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, val, child) {
          return Transform.scale(
            scale: val,
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              content: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: type == "OUT" ? Colors.red : Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: [BoxShadow(color: (type == "OUT" ? Colors.red : Colors.amber).withOpacity(0.8), blurRadius: 50)]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Icon(
                       type == "OUT" ? Icons.close : Icons.star, 
                       size: 60, color: Colors.white
                     ),
                     Text(type == "OUT" ? "WICKET!" : type, 
                       style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white)
                     ),
                  ],
                ),
              ),
            ),
          );
        },
      )
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isSetup) {
      return TrriveMatchSetup(onStart: (a, b, s, sId, nsId, bId) {
        engine.startMatch(a, b, s, sId, nsId, bId);
        setState(() => isSetup = true);
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("${engine.teamA!.name} vs ${engine.teamB!.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "SCORING"),
            Tab(text: "SCORECARD"),
            Tab(text: "COMMENTARY"),
          ],
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildScoringTab(),
              _buildFullScorecardTab(),
              _buildCommentaryTab(),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: LIVE SCORING ---
  Widget _buildScoringTab() {
    final inn = engine.currentInnings!;
    bool overDone = inn.legalBalls > 0 && inn.legalBalls % 6 == 0;
    bool newBowlerNeeded = overDone && inn.history.isNotEmpty && inn.history.last.bowlerId == engine.currentBowlerId;

    double prr = inn.runRate * engine.settings.totalOvers;

    return Column(
      children: [
        // 1. MAIN SCORE CARD
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blueGrey.shade900, Colors.black]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 10)]
          ),
          child: Column(
            children: [
              Text("${inn.totalRuns}/${inn.totalWickets}", 
                style: const TextStyle(fontSize: 48, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              Text("Overs: ${inn.oversDisplay}  |  CRR: ${inn.runRate.toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statBadge("Projected", prr.toStringAsFixed(0)),
                  const SizedBox(width: 20),
                  _statBadge("Partnership", "${inn.currentPartnershipRuns} (${inn.currentPartnershipBalls})"),
                ],
              ),
              const SizedBox(height: 15),
              // Last 6 Balls
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: inn.history.reversed.take(6).toList().reversed.map((b) => _ballWidget(b)).toList(),
                ),
              )
            ],
          ),
        ),

        // 2. ACTIVE PLAYERS
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _playerRow(engine.currentStrikerId, true),
              _playerRow(engine.currentNonStrikerId, false),
              const Divider(color: Colors.white24),
              _bowlerRow(engine.currentBowlerId, newBowlerNeeded),
            ],
          ),
        ),

        // 3. KEYPAD
        if (newBowlerNeeded)
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text("SELECT NEXT BOWLER"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 15),
                minimumSize: const Size(double.infinity, 50)
              ),
              onPressed: () => _showSelectionDialog(
                "Select Bowler", 
                engine.teamB!.squad, 
                (id) => engine.changeBowler(id),
                (id) => engine.validateBowler(id)
              ),
            ),
          )
        else
          _buildKeypad(),
      ],
    );
  }

  // --- TAB 2: FULL SCORECARD ---
  Widget _buildFullScorecardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Batting", style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {0: FlexColumnWidth(3), 4: FlexColumnWidth(1)},
          children: [
            const TableRow(children: [
              Text("Batter", style: TextStyle(color: Colors.grey)),
              Text("R", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Text("B", style: TextStyle(color: Colors.grey)),
              Text("4s", style: TextStyle(color: Colors.grey)),
              Text("6s", style: TextStyle(color: Colors.grey)),
              Text("SR", style: TextStyle(color: Colors.grey)),
            ]),
            ...engine.teamA!.squad.where((p) => engine.currentInnings!.batRuns.containsKey(p.id)).map((p) {
               int r = engine.currentInnings!.batRuns[p.id] ?? 0;
               int b = engine.currentInnings!.batBalls[p.id] ?? 0;
               double sr = b > 0 ? (r/b)*100 : 0.0;
               return TableRow(children: [
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(p.name, style: const TextStyle(color: Colors.white))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text("$r", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text("$b", style: const TextStyle(color: Colors.white70))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text("${engine.currentInnings!.batFours[p.id]}", style: const TextStyle(color: Colors.white70))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text("${engine.currentInnings!.batSixes[p.id]}", style: const TextStyle(color: Colors.white70))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(sr.toStringAsFixed(0), style: const TextStyle(color: Colors.white70))),
               ]);
            })
          ],
        ),
        const Divider(color: Colors.white24, height: 30),
        const Text("Bowling", style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {0: FlexColumnWidth(3)},
          children: [
            const TableRow(children: [
              Text("Bowler", style: TextStyle(color: Colors.grey)),
              Text("O", style: TextStyle(color: Colors.grey)),
              Text("R", style: TextStyle(color: Colors.grey)),
              Text("W", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Text("Eco", style: TextStyle(color: Colors.grey)),
            ]),
             ...engine.teamB!.squad.where((p) => (engine.currentInnings!.bowlLegalBalls[p.id]??0) > 0).map((p) {
               int b = engine.currentInnings!.bowlLegalBalls[p.id] ?? 0;
               int r = engine.currentInnings!.bowlRuns[p.id] ?? 0;
               int w = engine.currentInnings!.bowlWickets[p.id] ?? 0;
               String ov = "${b ~/ 6}.${b % 6}";
               double eco = b > 0 ? (r/b)*6 : 0.0;
               return TableRow(children: [
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(p.name, style: const TextStyle(color: Colors.white))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(ov, style: const TextStyle(color: Colors.white70))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text("$r", style: const TextStyle(color: Colors.white70))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text("$w", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                 Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(eco.toStringAsFixed(1), style: const TextStyle(color: Colors.white70))),
               ]);
            })
          ],
        )
      ],
    );
  }

  // --- TAB 3: COMMENTARY ---
  Widget _buildCommentaryTab() {
    return ListView.builder(
      itemCount: engine.currentInnings!.history.length,
      itemBuilder: (ctx, i) {
        // Reverse order
        final ball = engine.currentInnings!.history[engine.currentInnings!.history.length - 1 - i];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12))
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Text(ball.overDisplay, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ball.commentary, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    if (ball.isWicket)
                       Padding(
                         padding: const EdgeInsets.only(top: 4),
                         child: Text("OUT: ${ball.dismissalType.name}", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                       )
                  ],
                ),
              ),
              _ballWidget(ball)
            ],
          ),
        );
      },
    );
  }

  // --- WIDGETS ---
  Widget _statBadge(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _playerRow(String pid, bool isOnStrike) {
    var p = engine.teamA!.squad.firstWhere((e) => e.id == pid);
    var r = engine.currentInnings!.batRuns[pid];
    var b = engine.currentInnings!.batBalls[pid];
    return ListTile(
      tileColor: isOnStrike ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent,
      leading: Icon(Icons.person, color: isOnStrike ? Colors.cyanAccent : Colors.grey),
      title: Text(p.name, style: TextStyle(color: isOnStrike ? Colors.white : Colors.white60, fontWeight: isOnStrike ? FontWeight.bold : FontWeight.normal)),
      trailing: Text("$r ($b)", style: const TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  Widget _bowlerRow(String pid, bool needsChange) {
    var p = engine.teamB!.squad.firstWhere((e) => e.id == pid);
    var w = engine.currentInnings!.bowlWickets[pid];
    var r = engine.currentInnings!.bowlRuns[pid];
    var b = engine.currentInnings!.bowlLegalBalls[pid] ?? 0;
    return ListTile(
      leading: const Icon(Icons.sports_baseball, color: Colors.orangeAccent),
      title: Text(p.name, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
      subtitle: Text("Figures: $w-$r  |  ${b~/6}.${b%6} Overs", style: const TextStyle(color: Colors.white70)),
      trailing: needsChange ? const Icon(Icons.warning, color: Colors.red) : null,
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black,
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _btn("0", () => engine.processDelivery(runs: 0, extraType: ExtraType.none, isWicket: false)),
            _btn("1", () => engine.processDelivery(runs: 1, extraType: ExtraType.none, isWicket: false)),
            _btn("2", () => engine.processDelivery(runs: 2, extraType: ExtraType.none, isWicket: false)),
            _btn("3", () => engine.processDelivery(runs: 3, extraType: ExtraType.none, isWicket: false)),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _btn("4", () => engine.processDelivery(runs: 4, extraType: ExtraType.none, isWicket: false), color: Colors.green),
            _btn("6", () => engine.processDelivery(runs: 6, extraType: ExtraType.none, isWicket: false), color: Colors.cyan),
            _btn("OUT", _handleWicket, color: Colors.red),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
             _miniBtn("WD", () => engine.processDelivery(runs: 0, extraType: ExtraType.wide, isWicket: false)),
             _miniBtn("NB", () => engine.processDelivery(runs: 0, extraType: ExtraType.noBall, isWicket: false)),
             _miniBtn("BYE", () => engine.processDelivery(runs: 1, extraType: ExtraType.bye, isWicket: false)),
          ]),
        ],
      ),
    );
  }

  Widget _btn(String txt, VoidCallback tap, {Color color = Colors.blueGrey}) {
    return InkWell(
      onTap: tap,
      child: Container(
        width: 70, height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5))
        ),
        child: Text(txt, style: TextStyle(color: color == Colors.blueGrey ? Colors.white : color, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _miniBtn(String txt, VoidCallback tap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], padding: const EdgeInsets.symmetric(horizontal: 20)),
      onPressed: tap,
      child: Text(txt, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _ballWidget(BallData b) {
     Color c = Colors.grey;
     String t = "${b.runsScored}";
     if (b.isWicket) { c = Colors.red; t="W"; }
     else if (b.runsScored == 4) c = Colors.green;
     else if (b.runsScored == 6) c = Colors.cyan;
     else if (b.extraType != ExtraType.none) { c = Colors.orange; t=b.extraType.name.substring(0,2).toUpperCase(); }
     
     return Container(
       margin: const EdgeInsets.symmetric(horizontal: 3),
       width: 28, height: 28,
       alignment: Alignment.center,
       decoration: BoxDecoration(color: c, shape: BoxShape.circle),
       child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
     );
  }

  void _handleWicket() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey[900],
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 10,
          children: DismissalType.values.where((d) => d!=DismissalType.notOut).map((d) => 
            ActionChip(
              label: Text(d.name.toUpperCase()),
              backgroundColor: Colors.red[900],
              labelStyle: const TextStyle(color: Colors.white),
              onPressed: () {
                 Navigator.pop(context);
                 engine.processDelivery(runs: 0, extraType: ExtraType.none, isWicket: true, dismissalType: d);
                 // Only show batsmen who have NOT batted yet
                 _showSelectionDialog("New Batsman", 
                    engine.teamA!.squad.where((p) => !engine.currentInnings!.batRuns.containsKey(p.id)).toList(), 
                    (id) => engine.replaceBatsman(engine.currentStrikerId, id),
                    (id) => null
                 );
              },
            )
          ).toList(),
        ),
      )
    );
  }

  void _showSelectionDialog(String title, List<Player> players, Function(String) onSelect, String? Function(String)? validator) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: SizedBox(width: 300, height: 300, child: ListView(
        children: players.map((p) {
          String? err = validator != null ? validator(p.id) : null;
          return ListTile(
             title: Text(p.name, style: TextStyle(color: err==null ? Colors.white : Colors.grey)),
             subtitle: err!=null ? Text(err, style: const TextStyle(color: Colors.red, fontSize: 10)) : null,
             onTap: err==null ? () { onSelect(p.id); Navigator.pop(context); } : null,
          );
        }).toList()
      )),
    ));
  }
}

// ==============================================================================
// 4. FULL SETUP SCREEN (STEPPER)
// ==============================================================================
class TrriveMatchSetup extends StatefulWidget {
  final Function(Team, Team, MatchSettings, String, String, String) onStart;
  const TrriveMatchSetup({super.key, required this.onStart});

  @override
  State<TrriveMatchSetup> createState() => _TrriveMatchSetupState();
}

class _TrriveMatchSetupState extends State<TrriveMatchSetup> {
  int _currentStep = 0;
  
  final _teamAController = TextEditingController(text: "India");
  final _teamBController = TextEditingController(text: "Australia");
  final _oversController = TextEditingController(text: "5");
  
  List<TextEditingController> teamAPlayers = List.generate(11, (i) => TextEditingController(text: "Player A${i+1}"));
  List<TextEditingController> teamBPlayers = List.generate(11, (i) => TextEditingController(text: "Player B${i+1}"));

  String? selectedStriker;
  String? selectedNonStriker;
  String? selectedBowler;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("MATCH SETUP"), backgroundColor: Colors.grey[900], centerTitle: true),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent),
            ),
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: _nextStep,
              onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
              controlsBuilder: (ctx, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue, 
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                        child: Text(_currentStep == 3 ? "START MATCH" : "NEXT")
                      ),
                      if (_currentStep > 0)
                        TextButton(onPressed: details.onStepCancel, child: const Text("BACK"))
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text("Match Rules"),
                  content: Column(
                    children: [
                      _input(_teamAController, "Home Team Name"),
                      const SizedBox(height: 10),
                      _input(_teamBController, "Away Team Name"),
                      const SizedBox(height: 10),
                      _input(_oversController, "Overs", isNumber: true),
                    ],
                  ),
                  isActive: _currentStep >= 0,
                ),
                Step(
                  title: Text("${_teamAController.text} Squad"),
                  content: Column(
                    children: [
                      const Text("Enter Player Names (1-11)", style: TextStyle(color: Colors.white60)),
                      const SizedBox(height: 10),
                      ...teamAPlayers.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _input(c, "Player Name"),
                      )),
                    ],
                  ),
                  isActive: _currentStep >= 1,
                ),
                Step(
                  title: Text("${_teamBController.text} Squad"),
                  content: Column(
                    children: [
                      const Text("Enter Player Names (1-11)", style: TextStyle(color: Colors.white60)),
                      const SizedBox(height: 10),
                      ...teamBPlayers.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _input(c, "Player Name"),
                      )),
                    ],
                  ),
                  isActive: _currentStep >= 2,
                ),
                Step(
                  title: const Text("Opening Players"),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Select Openers for ${_teamAController.text}", style: const TextStyle(color: Colors.cyanAccent)),
                      const SizedBox(height: 10),
                      _dropdown("Striker", teamAPlayers, (v) => setState(() => selectedStriker = v), selectedStriker),
                      _dropdown("Non-Striker", teamAPlayers, (v) => setState(() => selectedNonStriker = v), selectedNonStriker),
                      
                      const SizedBox(height: 20),
                      Text("Select Bowler for ${_teamBController.text}", style: const TextStyle(color: Colors.cyanAccent)),
                      const SizedBox(height: 10),
                      _dropdown("Opening Bowler", teamBPlayers, (v) => setState(() => selectedBowler = v), selectedBowler),
                    ],
                  ),
                  isActive: _currentStep >= 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      if (selectedStriker != null && selectedNonStriker != null && selectedBowler != null && selectedStriker != selectedNonStriker) {
        
        // Build Teams
        Team a = Team(id: "T1", name: _teamAController.text, squad: List.generate(11, (i) => Player(id: "T1P$i", name: teamAPlayers[i].text)));
        Team b = Team(id: "T2", name: _teamBController.text, squad: List.generate(11, (i) => Player(id: "T2P$i", name: teamBPlayers[i].text)));
        MatchSettings settings = MatchSettings(totalOvers: int.parse(_oversController.text));
        
        // Find IDs of selected players
        String sId = a.squad.firstWhere((p) => p.name == selectedStriker).id;
        String nsId = a.squad.firstWhere((p) => p.name == selectedNonStriker).id;
        String bId = b.squad.firstWhere((p) => p.name == selectedBowler).id;

        widget.onStart(a, b, settings, sId, nsId, bId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select valid Strikers and Bowler")));
      }
    }
  }

  Widget _input(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.grey[900],
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
      ),
    );
  }

  Widget _dropdown(String label, List<TextEditingController> source, Function(String?) onChange, String? val) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      dropdownColor: Colors.grey[800],
      decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.grey[900]),
      items: source.map((c) => DropdownMenuItem(value: c.text, child: Text(c.text, style: const TextStyle(color: Colors.white)))).toList(),
      onChanged: onChange,
    );
  }
}