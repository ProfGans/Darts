enum GameMode {
  x01,
  cricket,
  bob27,
}

extension GameModePresentation on GameMode {
  String get title {
    switch (this) {
      case GameMode.x01:
        return 'X01';
      case GameMode.cricket:
        return 'Cricket';
      case GameMode.bob27:
        return 'Bob\'s 27';
    }
  }

  String get description {
    switch (this) {
      case GameMode.x01:
        return 'Das bisherige Spiel mit Match-Setup, Bot und Score-Eingabe.';
      case GameMode.cricket:
        return 'Standard Cricket mit Marks auf 20-15 und Bull.';
      case GameMode.bob27:
        return 'Doppel-Training von D1 bis Bull mit klassischem 27-Scoring.';
    }
  }

  bool get isImplemented {
    switch (this) {
      case GameMode.x01:
        return true;
      case GameMode.cricket:
        return true;
      case GameMode.bob27:
        return true;
    }
  }
}
