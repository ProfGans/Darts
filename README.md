# Flutter Port

Dieses Verzeichnis ist das neue Zielgeruest fuer die Android-/Flutter-Version der Dart-App.

Ziel:
- fachliche Logik aus der aktuellen Electron-App schrittweise nach Dart portieren
- UI komplett neu in Flutter bauen
- bestehende Desktop-App dabei unberuehrt lassen

Empfohlene Reihenfolge:
1. `domain/x01`
2. `domain/bot`
3. `presentation/match`
4. `data/repositories`
5. `domain/tournament`
6. `domain/career`

Wichtige Quelle im Altprojekt:
- `dart-rules.js` -> `lib/domain/x01/`
- `bot.js` -> `lib/domain/bot/`
- `x01-sim.js` -> `lib/domain/x01/`
- `dartboard.js` -> `lib/domain/board/` + `lib/presentation/board/`
- `tournament.js` -> `lib/domain/tournament/`
- `career.js` -> `lib/domain/career/` + `lib/domain/rankings/`
- `script.js` -> Flutter-UI / State-Management, nicht direkt portierbar

Erster sinnvoller Portierungsschritt:
- `x01_rules.dart`
- `x01_models.dart`
- `bot_engine.dart`

