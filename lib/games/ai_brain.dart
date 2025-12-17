import 'dart:math';

class AIBrain {
  static final Random _rnd = Random();

  // --- 1. MAKE MOVE (AI Action Dispatcher) ---
  // This takes the current state and returns a NEW state with the AI's move applied.
  static Map<String, dynamic> makeMove(String gameType, Map<String, dynamic> state) {
    Map<String, dynamic> newState = Map.from(state);

    try {
      switch (gameType) {
        case 'tictactoe': return _minimaxTicTacToe(newState);
        case 'connect4': return _smartConnect4(newState);
        case 'ludo': return _smartLudo(newState);
        case 'ships':
        case 'battleship': return _huntAndTargetBattleship(newState);
        case 'gomoku': return _heuristicGomoku(newState);
        case 'dots': return _smartDots(newState);
        case 'memory': return _playMemory(newState);
        case 'cricket': return _playSmartCricket(newState);
        case 'hangman': return _playHangman(newState);
        case 'simon': return _playSimon(newState);
        case 'guessnum': return _playGuessNum(newState);
        case 'carrom': return _playSmartCarrom(newState);
        case 'rps': 
          newState['p2Move'] = ["🪨", "📄", "✂️"][_rnd.nextInt(3)];
          newState['turn'] = 'P1'; 
          return newState;
        case 'trivia':
          newState['p2Score'] = (newState['p2Score'] ?? 0) + (_rnd.nextBool() ? 10 : 0);
          newState['turn'] = 'P1';
          return newState;
        case 'math':
          newState['p2Score'] = (newState['p2Score'] ?? 0) + 1;
          newState['turn'] = 'P1';
          return newState;
        default:
          // For games like Snake, Whack, 2048 where AI doesn't move but just provides a target score
          newState['turn'] = 'P1'; 
          return newState;
      }
    } catch (e) {
      newState['turn'] = 'P1';
      return newState;
    }
  }

  // --- 2. CHECK WINNER (The Referee) ---
  // Standardized logic to check if a match has concluded.
  static String? getWinner(String type, Map<String, dynamic> state) {
    if (type == 'tictactoe') return _checkWinTicTacToe(state['board']);
    if (type == 'connect4') return _checkWinConnect4(state['board']);
    
    if (type == 'ludo') {
      if ((state['p1Tokens'] as List).every((t) => t >= 57)) return 'P1';
      if ((state['p2Tokens'] as List).every((t) => t >= 57)) return 'AI';
    }

    if (type == 'battleship' || type == 'ships') {
      if (!(state['p1Grid'] as List).contains(1)) return 'AI'; // P1 has no ships left
      if (!(state['p2Grid'] as List).contains(1)) return 'P1'; // AI has no ships left
    }

    if (type == 'cricket') {
      int p1 = state['p1Score'] ?? -1;
      int ai = state['p2Score'] ?? -1;
      if (p1 != -1 && ai != -1 && state['ballsPlayed'] >= 6) {
        if (p1 > ai) return 'P1';
        if (ai > p1) return 'AI';
        return 'draw';
      }
    }

    return null;
  }

  // --- 3. GAME STRATEGIES ---

  static Map<String, dynamic> _playMemory(Map<String, dynamic> state) {
    List<bool> revealed = List<bool>.from(state['revealed'] ?? []);
    List grid = state['grid'] ?? [];
    // AI cheats slightly by remembering all positions and finding a pair
    for (int i = 0; i < grid.length; i++) {
      for (int j = i + 1; j < grid.length; j++) {
        if (!revealed[i] && !revealed[j] && grid[i] == grid[j]) {
          revealed[i] = true;
          revealed[j] = true;
          state['revealed'] = revealed;
          state['turn'] = 'P1';
          return state;
        }
      }
    }
    state['turn'] = 'P1';
    return state;
  }

  static Map<String, dynamic> _huntAndTargetBattleship(Map<String, dynamic> s) {
    List grid = List.from(s['p1Grid'] ?? List.filled(25, 0)); // AI attacks P1's grid
    // Priority: If AI hit a ship last time, target adjacent cells
    int lastHit = grid.indexOf(2); 
    if (lastHit != -1) {
      List<int> adj = [lastHit-5, lastHit+5, lastHit-1, lastHit+1];
      adj.shuffle();
      for (int m in adj) {
        if (m >= 0 && m < 25 && grid[m] < 2) {
          grid[m] = (grid[m] == 1) ? 2 : 3;
          s['p1Grid'] = grid;
          s['turn'] = (grid[m] == 2) ? 'AI' : 'P1';
          return s;
        }
      }
    }
    // Random targeting if no previous hits
    int target = _rnd.nextInt(25);
    while (grid[target] >= 2) {
      target = _rnd.nextInt(25);
    }
    grid[target] = (grid[target] == 1) ? 2 : 3;
    s['p1Grid'] = grid;
    s['turn'] = (grid[target] == 2) ? 'AI' : 'P1';
    return s;
  }

  static Map<String, dynamic> _smartLudo(Map<String, dynamic> s) {
    int dice = _rnd.nextInt(6) + 1;
    s['dice'] = dice;
    List tokens = List.from(s['p2Tokens'] ?? [0,0,0,0]);

    if (dice == 6 && tokens.contains(0)) {
      tokens[tokens.indexOf(0)] = 1;
    } else {
      for (int i = 0; i < 4; i++) {
        if (tokens[i] > 0 && tokens[i] + dice <= 57) {
          tokens[i] += dice;
          break; 
        }
      }
    }
    s['p2Tokens'] = tokens;
    s['turn'] = (dice == 6) ? 'AI' : 'P1';
    return s;
  }

  static Map<String, dynamic> _minimaxTicTacToe(Map<String, dynamic> state) {
    List board = List.from(state['board']);
    // 1. Check if AI can win
    for(int i=0; i<9; i++) {
      if(board[i]=='') { 
        board[i]='O'; 
        if(_checkWinTicTacToe(board)=='AI') { state['board']=board; state['turn']='P1'; return state; } 
        board[i]=''; 
      }
    }
    // 2. Block P1 from winning
    for(int i=0; i<9; i++) {
      if(board[i]=='') { 
        board[i]='X'; 
        if(_checkWinTicTacToe(board)=='P1') { board[i]='O'; state['board']=board; state['turn']='P1'; return state; } 
        board[i]=''; 
      }
    }
    // 3. Random move
    List<int> e=[]; for(int i=0;i<9;i++) {
      if(board[i]=='') e.add(i);
    }
    if(e.isNotEmpty) board[e[_rnd.nextInt(e.length)]] = 'O';
    state['board'] = board; state['turn'] = 'P1'; return state;
  }

  static Map<String, dynamic> _smartDots(Map<String, dynamic> s) {
    List lines = List.from(s['lines'] ?? List.filled(24, 0));
    List<int> avail = [];
    for(int i=0; i<lines.length; i++) {
      if(lines[i] == 0) avail.add(i);
    }
    if(avail.isNotEmpty) lines[avail[_rnd.nextInt(avail.length)]] = 2;
    s['lines'] = lines; s['turn'] = 'P1'; return s;
  }

  static Map<String, dynamic> _playHangman(Map<String, dynamic> s) {
    List guesses = List.from(s['guesses'] ?? []);
    String freq = "ETAOINSHRDLUCMFWYGPBVKXQJZ";
    for(int i=0; i<freq.length; i++) {
      if(!guesses.contains(freq[i])) { guesses.add(freq[i]); break; }
    }
    s['guesses'] = guesses; s['turn'] = 'P1'; return s;
  }

  static Map<String, dynamic> _playSimon(Map<String, dynamic> s) {
    List<int> seq = List<int>.from(s['sequence'] ?? []);
    seq.add(_rnd.nextInt(4));
    s['sequence'] = seq; s['userStep'] = 0; s['turn'] = 'P1'; return s;
  }

  static Map<String, dynamic> _playGuessNum(Map<String, dynamic> s) {
    int target = s['target'] ?? 50;
    List guesses = List.from(s['guesses'] ?? []);
    int g = _rnd.nextInt(100) + 1;
    guesses.add({'val': g, 'res': g == target ? 'CORRECT' : (g < target ? 'LOW' : 'HIGH')});
    s['guesses'] = guesses; s['turn'] = 'P1'; return s;
  }

  static Map<String, dynamic> _smartConnect4(Map<String, dynamic> state) {
    List b = List.from(state['board']);
    List<int> preferredCols = [3,2,4,1,5,0,6]; // Target center columns
    for(int c in preferredCols) {
       int t = -1; for(int r=5; r>=0; r--) { if(b[r*7+c]=='') { t=r*7+c; break; } }
       if (t != -1) { b[t] = 'Y'; break; }
    }
    state['board'] = b; state['turn'] = 'P1'; return state;
  }

  static Map<String, dynamic> _heuristicGomoku(Map<String, dynamic> s) {
    List b = List.from(s['board']);
    List<int> e = []; for(int i=0; i<100; i++) {
      if(b[i]=='') e.add(i);
    }
    if(e.isNotEmpty) b[e[_rnd.nextInt(e.length)]] = 'W';
    s['board'] = b; s['turn'] = 'P1'; return s;
  }

  static Map<String, dynamic> _playSmartCricket(Map<String, dynamic> state) {
    // AI sets a target between 10 and 40 for 1 over
    state['p2Score'] = 10 + _rnd.nextInt(31);
    state['turn'] = 'P1'; return state;
  }

  static Map<String, dynamic> _playSmartCarrom(Map<String, dynamic> s) {
    bool success = _rnd.nextDouble() > 0.4; 
    if (success) {
      int points = _rnd.nextBool() ? 20 : 50;
      s['p2Score'] = (s['p2Score'] ?? 0) + points;
    }
    s['turn'] = 'P1';
    return s;
  }

  static String? _checkWinTicTacToe(List b) {
    List<List<int>> wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    for (var w in wins) {
      if (b[w[0]]!='' && b[w[0]]==b[w[1]] && b[w[1]]==b[w[2]]) return b[w[0]]=='X'?'P1':'AI';
    }
    return b.contains('') ? null : 'draw';
  }

  static String? _checkWinConnect4(List b) {
    for (int i = 0; i < 42; i++) {
      if (b[i] == '') continue;
      String p = b[i]; int r = i ~/ 7; int c = i % 7;
      if (c <= 3 && b[i+1]==p && b[i+2]==p && b[i+3]==p) return p=='R'?'P1':'AI';
      if (r <= 2 && b[i+7]==p && b[i+14]==p && b[i+21]==p) return p=='R'?'P1':'AI';
    }
    return null;
  }
}