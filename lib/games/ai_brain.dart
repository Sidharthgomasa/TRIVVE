import 'dart:math';

class AIBrain {
  static final Random _rnd = Random();

  // --- 1. MAKE MOVE (AI Action) ---
  static Map<String, dynamic> makeMove(String gameType, Map<String, dynamic> state) {
    Map<String, dynamic> newState = Map.from(state);

    try {
      // Turn-based Strategies
      if (gameType == 'cricket') return _playSmartCricket(newState);
      if (gameType == 'tictactoe') return _minimaxTicTacToe(newState);
      if (gameType == 'connect4') return _smartConnect4(newState);
      if (gameType == 'gomoku') return _heuristicGomoku(newState);
      if (gameType == 'battleship' || gameType == 'ships') return _huntAndTargetBattleship(newState);
      if (gameType == 'memory') return _playMemory(newState);
      if (gameType == 'hangman') return _playHangman(newState);
      if (gameType == 'simon') return _playSimon(newState);
      if (gameType == 'dots') return _smartDots(newState);
      if (gameType == 'ludo') return _smartLudo(newState);
      
      // Simple/Arcade Strategies
      if (gameType == 'rps') { newState['p2Move'] = ["🪨", "📄", "✂️"][_rnd.nextInt(3)]; }
      if (gameType == 'guessnum') return _playGuessNum(newState);
      if (gameType == 'trivia') { newState['p2Score'] = (newState['p2Score'] ?? 0) + (_rnd.nextBool() ? 10 : 0); newState['turn'] = 'P1'; }
      if (gameType == 'math') { newState['p2Score'] = (newState['p2Score'] ?? 0) + 1; newState['turn'] = 'P1'; }
      if (gameType == 'carrom') { newState['turn'] = 'P1'; } 
      
    } catch (e) {
      newState['turn'] = 'P1'; // Fallback
    }
    return newState;
  }

  // --- 2. CHECK WINNER (The Referee) ---
  static String? getWinner(String type, Map<String, dynamic> state) {
    // 1. Board Games
    if (type == 'tictactoe') return _checkWinTicTacToe(state['board']);
    if (type == 'connect4') return _checkWinConnect4(state['board']);
    
    // 2. Score Games (Snake, 2048, Mines, etc.)
    // If Player hits target -> P1 Wins. If AI hits target -> AI Wins.
    int p1 = state['p1Score'] ?? 0;
    int aiScore = state['p2Score'] ?? 0;
    
    // Arcade Targets (Hardcoded for fairness checks)
    if (['snake', 'whack', 'tapattack', 'typer', 'math', 'trivia', 'mines'].contains(type)) {
       // Logic: Usually these are solo games vs a score. 
       // If P1 dies/quits, UI sends AI winner. 
       // Here we just check if AI somehow reached a "Target".
       if (aiScore > 1000) return 'AI'; // Example threshold
    }

    // 3. Cricket / Super Over
    if (type == 'cricket') {
      // If both played (scores != -1)
      if (p1 != -1 && aiScore != -1) {
        if (p1 > aiScore) return 'P1';
        if (aiScore > p1) return 'AI';
        return 'draw';
      }
    }

    // 4. RPS
    if (type == 'rps') {
      String m1 = state['p1Move'] ?? '';
      String m2 = state['p2Move'] ?? '';
      if (m1.isNotEmpty && m2.isNotEmpty) {
        if (m1 == m2) return 'draw';
        if ((m1=='🪨'&&m2=='✂️') || (m1=='📄'&&m2=='🪨') || (m1=='✂️'&&m2=='📄')) return 'P1';
        return 'AI';
      }
    }

    // 5. Guess Number
    if (type == 'guessnum') {
      List guesses = state['guesses'] ?? [];
      if (guesses.isNotEmpty && guesses.last['res'] == 'CORRECT') {
        // Whoever made the last guess wins. 
        // Logic: Turn flips AFTER guess. So if turn is P1, AI just guessed correctly.
        return state['turn'] == 'P1' ? 'AI' : 'P1';
      }
    }

    // 6. Memory
    if (type == 'memory') {
      List<bool> rev = List<bool>.from(state['revealed'] ?? []);
      if (rev.every((r) => r)) return 'draw'; // Simplified: Full clear = end
    }

    return null; // No winner yet
  }

  // --- PRIVATE UTILS ---

  static String? _checkWinTicTacToe(List b) {
    List<List<int>> wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    for (var w in wins) {
      if (b[w[0]] != '' && b[w[0]] == b[w[1]] && b[w[1]] == b[w[2]]) {
        return b[w[0]] == 'X' ? 'P1' : 'AI'; // X is always P1 in Local
      }
    }
    if (!b.contains('')) return 'draw';
    return null;
  }

  static String? _checkWinConnect4(List b) {
    // Horizontal, Vertical, Diagonal checks
    // Simplified checks for 7x6 board
    for (int i = 0; i < 42; i++) {
      if (b[i] == '') continue;
      String p = b[i];
      int r = i ~/ 7; int c = i % 7;
      
      if (c <= 3 && b[i+1]==p && b[i+2]==p && b[i+3]==p) return p=='R'?'P1':'AI'; // Horiz
      if (r <= 2 && b[i+7]==p && b[i+14]==p && b[i+21]==p) return p=='R'?'P1':'AI'; // Vert
      if (c <= 3 && r <= 2 && b[i+8]==p && b[i+16]==p && b[i+24]==p) return p=='R'?'P1':'AI'; // Diag 1
      if (c >= 3 && r <= 2 && b[i+6]==p && b[i+12]==p && b[i+18]==p) return p=='R'?'P1':'AI'; // Diag 2
    }
    return null;
  }

  // ... (Strategies from previous response: _playSmartCricket, _minimaxTicTacToe, etc.)
  // Ensure you include the strategies here as defined in the previous full file code.
  static Map<String, dynamic> _playSmartCricket(Map<String, dynamic> state) {
    int cur = state['p2Score'] == -1 ? 0 : state['p2Score'];
    int target = state['p1Score'];
    int agg = target != -1 ? ((target - cur + 1 > 12) ? 90 : 50) : 50;
    
    int r = 0, w = 0;
    for (int b = 0; b < 6; b++) {
      if (w >= 2) break;
      int roll = _rnd.nextInt(100);
      if (roll < (agg > 70 ? 25 : 15)) {
        w++;
      } else if (roll > (agg > 70 ? 80 : 95)) r += 6;
      else if (roll > 60) r += 4;
      else if (roll > 30) r += 2;
      else r += 1;
    }
    state['p2Score'] = r;
    // Note: Cricket checks win in getWinner, so we just update score here
    return state;
  }

  static Map<String, dynamic> _minimaxTicTacToe(Map<String, dynamic> state) {
    List board = List.from(state['board']);
    // Check immediate win
    for(int i=0; i<9; i++) {
      if(board[i]=='') { board[i]='O'; if(_checkWinTicTacToe(board)=='AI') { state['board']=board; state['turn']='P1'; return state; } board[i]=''; }
    }
    // Check block
    for(int i=0; i<9; i++) {
      if(board[i]=='') { board[i]='X'; if(_checkWinTicTacToe(board)=='P1') { board[i]='O'; state['board']=board; state['turn']='P1'; return state; } board[i]=''; }
    }
    // Random
    List<int> e=[]; for(int i=0;i<9;i++) {
      if(board[i]=='') e.add(i);
    }
    if(e.isNotEmpty) board[e[_rnd.nextInt(e.length)]] = 'O';
    state['board'] = board; state['turn'] = 'P1'; return state;
  }

  static Map<String, dynamic> _smartConnect4(Map<String, dynamic> state) {
    List b = List.from(state['board']);
    List<int> cols = [3,2,4,1,5,0,6];
    for(int c in cols) {
       int t = -1; for(int r=5; r>=0; r--) { if(b[r*7+c]=='') { t=r*7+c; break; } }
       if (t != -1) { b[t] = 'Y'; break; }
    }
    state['board'] = b; state['turn'] = 'P1'; return state;
  }

  // Placeholder for others to prevent errors if not copied full
  static Map<String, dynamic> _heuristicGomoku(Map<String, dynamic> s) { s['turn']='P1'; return s; }
  static Map<String, dynamic> _huntAndTargetBattleship(Map<String, dynamic> s) { s['turn']='P1'; return s; }
  static Map<String, dynamic> _playMemory(Map<String, dynamic> s) { s['turn']='P1'; return s; }
  static Map<String, dynamic> _playHangman(Map<String, dynamic> s) { s['turn']='P1'; return s; }
  static Map<String, dynamic> _playSimon(Map<String, dynamic> s) { s['turn']='P1'; return s; }
  static Map<String, dynamic> _smartDots(Map<String, dynamic> s) { s['turn']='P1'; return s; }
  static Map<String, dynamic> _smartLudo(Map<String, dynamic> s) { s['turn']='P1'; return s; }
  static Map<String, dynamic> _playGuessNum(Map<String, dynamic> s) { s['turn']='P1'; return s; }
}