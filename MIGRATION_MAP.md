# Migrationsplan JS -> Flutter

## Phase 1: Kernspiel

### Alte Datei
`dart-rules.js`

### Neue Dateien
- `lib/domain/x01/x01_models.dart`
- `lib/domain/x01/x01_rules.dart`
- `lib/domain/x01/x01_match_engine.dart`

### Portieren
- Bust-Regel
- Double-Out
- Startscore / Restscore
- Visit-Auswertung
- Leg-/Set-/Matchende

## Phase 2: Bot

### Alte Datei
`bot.js`

### Neue Datei
- `lib/domain/bot/bot_engine.dart`

### Portieren
- Zielwahl
- Checkout-Logik
- Setup-/Leave-Logik
- Radiusmodell
- theoretische Average-Schaetzung

## Phase 3: Simulation

### Alte Datei
`x01-sim.js`

### Neue Datei
- `lib/domain/x01/x01_match_simulator.dart`

### Portieren
- Bot-vs-Bot Matches
- Legsimulation
- Matchstatistiken

## Phase 4: Dartboard

### Alte Datei
`dartboard.js`

### Neue Dateien
- `lib/domain/board/board_geometry.dart`
- `lib/presentation/board/dartboard_painter.dart`

### Portieren
- Feldgeometrie
- Trefferklassifikation
- Zielpunkte
- Marker-/Overlay-Positionen

## Phase 5: Turniere

### Alte Datei
`tournament.js`

### Neue Dateien
- `lib/domain/tournament/tournament_models.dart`
- `lib/domain/tournament/tournament_engine.dart`

## Phase 6: Karriere

### Alte Datei
`career.js`

### Neue Dateien
- `lib/domain/career/career_models.dart`
- `lib/domain/career/career_engine.dart`
- `lib/domain/rankings/ranking_engine.dart`

## State-Management

Empfehlung:
- Riverpod fuer App-Zustand

## Speicherung

Empfehlung:
- Isar oder Hive fuer App-Daten
- JSON-Export fuer Backups

