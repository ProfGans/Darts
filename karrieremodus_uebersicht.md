# Karrieremodus – Funktionsübersicht und Einschätzung

Stand: 09.06.2026

Dieses Dokument fasst den aktuellen Funktionsumfang des Karrieremodus auf Basis des vorhandenen Codes zusammen. Der Fokus liegt auf:

- was der Modus fachlich kann
- wie die Erstellung und der Spielbetrieb aufgebaut sind
- welche Bereiche bereits stark wirken
- welche Bereiche noch Schwächen oder technische Schulden haben
- einer Endübersicht mit klaren positiven und negativen Punkten

## 1. Grundidee des Karrieremodus

Der Karrieremodus ist nicht nur ein einfacher Turnier-Launcher, sondern ein recht breites System für eine fortlaufende Darts-Laufbahn mit:

- eigenem Karriere-Kader
- Saisonstruktur
- Ranglisten
- Turnierkalender
- Zugangs- und Qualifikationsregeln
- Karriere-Tags
- Template-System
- Schnellstart über Vorlagen oder Quick-Tour
- vollwertigem Experten-Editor
- Saisonfortschritt und Turnier-Simulation
- Karriere-Statistiken und Spielerhistorien

Technisch wird die Karriere hauptsächlich über diese Bereiche getragen:

- [career_setup_screen.dart](C:\Users\johan\Desktop\Dart\flutter_app\lib\presentation\career\career_setup_screen.dart)
- [career_detail_screen.dart](C:\Users\johan\Desktop\Dart\flutter_app\lib\presentation\career\career_detail_screen.dart)
- [career_repository.dart](C:\Users\johan\Desktop\Dart\flutter_app\lib\data\repositories\career_repository.dart)
- [career_models.dart](C:\Users\johan\Desktop\Dart\flutter_app\lib\domain\career\career_models.dart)
- [career_template_repository.dart](C:\Users\johan\Desktop\Dart\flutter_app\lib\data\repositories\career_template_repository.dart)

## 2. Erstellung einer Karriere

Die Karriere-Erstellung ist aktuell schrittbasiert im Einstieg aufgebaut.

### 2.1 Frühe Startentscheidungen

Am Anfang werden zentrale Grundentscheidungen abgefragt:

- ob mit `Trainingsmodus` gespielt werden soll
- ob eine `Vorlage` verwendet werden soll
- wenn keine Vorlage verwendet wird:
  - `einfache Erstellung`
  - oder `Experten-Erstellung`
- der `Karriere-Kader`
- die gewünschte `Kadergröße`

Das ist sinnvoll, weil diese Entscheidungen tatsächlich den späteren Karriereaufbau bestimmen.

### 2.2 Trainingsmodus

Der Trainingsmodus kann früh im Flow aktiviert werden und beeinflusst den späteren Start-Kader.

Er kann:

- eine Average-Spanne für den Start-Kader vorgeben
- eine Zielspanne wie z. B. `50 bis 75` auf einen Pool anwenden
- theoretische Averages in echte Skill-/Finishing-Werte auflösen
- auf den frühen Karriere-Kader wirken
- auch nach späterer Vorlagenwahl erhalten bleiben, solange der Trainingsmodus aktiv bleibt

Technisch wichtig:

- die Auflösung läuft nicht mehr nur lokal auf dem UI-Thread
- vorhandene Background-/Persistent-Job-Infrastruktur wird dafür genutzt
- es gibt Busy-/Warm-up-Texte für teure Bereiche

### 2.3 Karriere-Kader

Der Karriere-Kader wird früh bestimmt. Dabei kann gewählt werden:

- leer starten
- alle Datenbankspieler übernehmen
- gezielte Auswahl aus Datenbankspielern

Zusätzlich gibt es:

- Tag-Filter
- konkrete Spielerwahl
- Ziel-Kadergröße
- automatische Auffüllung fehlender Slots mit generierten Spielern

Die generierten Zusatzspieler werden absichtlich schwächer als der ausgewählte Kern erzeugt.

### 2.4 Vorlagenpfad

Wenn eine Vorlage verwendet wird, wird aus einem vorhandenen Karriere-Gerüst gestartet.

Aktuell enthalten:

- eingebaute `PDC Basic`
- benutzerdefinierte Vorlagen
- Erstellen einer Karriere aus Vorlage
- Bearbeiten vorhandener benutzerdefinierter Vorlagen
- Speichern einer aktuellen Karriereplanung als neue Vorlage

Die eingebaute `PDC Basic` ist im Build enthalten und wird als Built-in geladen. Benutzerdefinierte Vorlagen werden persistent gespeichert.

### 2.5 Einfache Erstellung ohne Vorlage

Wenn keine Vorlage verwendet wird und der einfache Pfad gewählt wird, wird eine `Quick-Tour` aufgebaut.

Das System kann:

- eigene Tour-Bausteine hinzufügen
- pro Baustein eine Turnierart wählen
- Namen vergeben
- Anzahl definieren
- Teilnehmerfelder definieren
- Preisgelder definieren
- Preisgeldverteilungen über Presets oder manuelle Werte setzen
- KO- und Liga-Auszahlungen getrennt pflegen

Der Quick-Editor wurde auf einen einzigen Bearbeitungspfad reduziert:

- Hinzufügen über eine eigene `Quick-Turnier`-Seite
- Bearbeiten bestehender Bausteine über dieselbe Seite
- kein zweiter konkurrierender Inline-Detaileditor mehr im Hauptfluss

### 2.6 Experten-Erstellung

Der Expertenpfad ist der vollständige Karriere-Editor.

Er erlaubt:

- Karriere-Grunddaten
- Ranglisten
- Karriere-Tags
- Saisonregeln
- Turniere
- Kalender
- Validierung
- Vorlagenverwaltung

Wichtig: Vorlagenwahl und Mitspiel-Optionen wurden aus dem direkten Experten-Einstieg entfernt, weil diese Entscheidungen bereits im frühen Startfluss getroffen werden.

## 3. Turnier- und Tourmodell

Der Karrieremodus kann deutlich mehr als nur einfache KO-Turniere.

Unterstützt sind unter anderem:

- KO-Turniere
- Liga-Turniere
- Liga + Playoff
- Serienformate
- Einzelturniere
- unterschiedliche Feldgrößen
- Setzlisten
- Preisgeldverteilungen
- Ranking-Zählungen je Event

Im Quick-Pfad gibt es Tour-Bausteine mit Logik für:

- Open
- Championship
- Players Championship
- Masters
- Major
- weitere Blueprint-basierte Tourtypen

Die Feldgrößen orientieren sich an der Kadergröße. Das verhindert, dass kleine Karriere-Kader mit unrealistisch großen Turnieren starten.

## 4. Ranglisten

Die Ranglistenlogik ist fachlich recht stark.

Der Modus unterstützt:

- Geld- oder Punkte-Rankings
- Gültigkeit über mehrere Saisons
- saisonale Resets
- Kategorien
- `bestOfCount`
- `discardWorstCount`
- Saison- und Playoff-Boni

Das erlaubt sowohl einfache Geldranglisten als auch deutlich speziellere Tourwertungen.

## 5. Karriere-Tags und Regeln

Ein starkes System im Modus sind die Karriere-Tags und Saisonregeln.

Unterstützt werden:

- Tag-Definitionen
- Tag-Attribute
- Spielerlimits
- zeitliche Gültigkeiten
- Add-/Remove-Regeln
- Saisonregeln auf Basis von Ranglisten oder Zuständen
- Tag-Gates für Turniere

Damit können Turniere und Saisonlogik sehr flexibel gesteuert werden, etwa:

- nur bestimmte Spielergruppen zulassen
- Tag-basierte Freischaltungen
- regionale oder statusbasierte Zugänge
- automatische Änderungen bei Saisonübergängen

## 6. Kalender und Saisonfluss

Der Kalender ist ein zentrales Element der Karriere.

Der Modus kann:

- eine Saison mit Kalender-Items verwalten
- erledigte Turniere markieren
- verbleibende Turniere ermitteln
- Turniere bei erfüllten oder nicht erfüllten Tag-Gates zulassen oder ausfallen lassen
- eine Saison abschließen
- neue Saisonzustände ableiten

Im Quick-Pfad werden Kalender-Items automatisch aus den gewählten Tour-Bausteinen gebaut.

## 7. Karrierebetrieb und Spielverlauf

Im laufenden Karrieremodus gibt es bereits eine recht breite Spieloberfläche.

Aktuell vorhanden:

- aktives Karriere-Dashboard
- nächstes offenes Event
- Saisonfortschritt
- Restturniere
- direkte Turnier-Simulation
- Karriere-Turnier öffnen
- Saisonkalender öffnen
- Saison beenden
- Prewarm der nächsten Karriere-Simulation

Der Detailscreen ist damit deutlich mehr als ein statischer Viewer.

## 8. Simulation und Performance

Simulation ist ein zentraler Teil des Modus.

Vorhanden sind:

- Karriere-Turniere aus Kalender-Items erzeugen
- komplette Turniere bis zum Ende simulieren
- Ergebnisse zurück in die Karriere committen
- Fortschritts- und Overlay-Zustände
- Vorwärmen des nächsten Turniers

Es wurde bereits an Performance gearbeitet, insbesondere:

- Trainingsmodus nutzt Background-Jobs
- einfache Karriere-Erstellung verschiebt schwere Arbeit hinter den Busy-Zustand
- Prewarm für den nächsten Karriere-Turnierpfad

Trotzdem ist Performance weiterhin ein sensibles Thema, weil Erstellung, Generierung und große UI-Rebuilds in diesem Bereich schnell teuer werden.

## 9. Vorlagenverwaltung

Die Vorlagenverwaltung kann aktuell:

- Built-in-Vorlage laden
- benutzerdefinierte Vorlagen speichern
- Vorlagen löschen
- vorhandene benutzerdefinierte Vorlagen bearbeiten
- aktuelle Karriereplanung wieder als Vorlage abspeichern

Die Bearbeitung vorhandener Vorlagen läuft derzeit pragmatisch über eine Arbeitskopie im Karriere-Editor, die anschließend zurück in dieselbe Vorlage geschrieben wird.

Das ist funktional brauchbar, aber noch kein eigener dedizierter Vorlagen-Editor.

## 10. Statistiken und Historie

Im laufenden Karrieremodus sind bereits statistische und historische Elemente vorhanden.

Dazu gehören:

- Karriere-Statistikübersichten
- Ranglistenstände
- Spielerhistorien
- saisonbezogene Auswertungen
- Karriereverlauf über abgeschlossene Turniere und Saisons

Das erhöht den Nutzwert des Modus deutlich, weil die Karriere nicht nur abgespielt, sondern auch ausgewertet wird.

## 11. Was aktuell klar positiv ist

- Der Karrieremodus ist fachlich breit. Er ist kein Platzhalter mehr, sondern ein ernstzunehmendes System.
- Es gibt mehrere Einstiegspfade: Vorlage, Quick-Tour, Experten-Editor.
- Trainingsmodus, Karriere-Kader und Kadergröße greifen inzwischen sinnvoll früh im Startfluss.
- Quick-Touren können frei aus Bausteinen aufgebaut werden.
- Ranglistenlogik ist überdurchschnittlich flexibel.
- Tags und Saisonregeln erlauben komplexere Karriere-Logik.
- Turnier- und Saisonfluss sind bereits spielbar.
- Vorlagen sind nicht nur ladbar, sondern inzwischen auch bearbeitbar.
- Simulation und Karriere-Detailansicht sind bereits substanziell.

## 12. Was aktuell klar negativ ist

- Der gesamte Bereich ist weiterhin stark auf eine sehr große Datei konzentriert, vor allem [career_setup_screen.dart](C:\Users\johan\Desktop\Dart\flutter_app\lib\presentation\career\career_setup_screen.dart). Das bleibt ein Wartungs- und Stabilitätsrisiko.
- Mehrere Flows sind funktional schon gut, aber technisch noch pragmatisch statt sauber entkoppelt.
- Vorlagenbearbeitung ist aktuell eher ein Arbeitskopie-Workflow als ein sauber getrenntes Bearbeitungsmodell.
- Einige Performance-Probleme wurden entschärft, sind aber nicht grundsätzlich gelöst.
- Der Bereich hat historisch viele Sonderfälle und Umbauten hinter sich. Das merkt man an Zustand, Rebuild-Risiken und UI-Kopplung.
- Die Testabsicherung für diesen Umfang ist nach wie vor ein Risikofaktor.

## 13. Gesamtfazit

Der Karrieremodus kann aktuell sehr viel:

- Karriere aufbauen
- Karriere anpassen
- Touren generieren
- Vorlagen nutzen und bearbeiten
- Kader trainieren
- Turniere simulieren
- Saisons spielen
- Ranglisten und Regeln verwalten

Seine größte Stärke ist der fachliche Umfang. Seine größte Schwäche ist nicht fehlende Funktion, sondern die technische Dichte und Kopplung im Setup-/Editorbereich.

Wenn man rein auf den Nutzwert schaut, ist der Modus bereits klar über Prototypniveau. Wenn man auf technische Stabilität und Wartbarkeit schaut, ist noch Arbeit offen.

## 14. Endübersicht

### Positiv

- Breiter und ernsthafter Funktionsumfang
- Mehrere sinnvolle Einstiegspfade
- Früh integrierter Trainingsmodus
- Flexibler Karriere-Kader und automatische Auffüllung
- Frei konfigurierbare Quick-Tour
- Starker Experten-Editor
- Gute Ranglisten- und Regelmechanik
- Spielbarer Karrierebetrieb mit Simulation und Saisonfluss
- Vorlagensystem mit Built-in und benutzerdefinierten Vorlagen
- Vorlagenbearbeitung vorhanden

### Negativ

- Sehr große und komplexe Setup-Datei
- Noch keine saubere Entkopplung aller Karriere-Erstellungsbereiche
- Vorlagenbearbeitung noch nicht als eigener, klarer Editor modelliert
- Performance in Erstellungs- und Generierungspfaden bleibt sensibel
- Historisch gewachsene UI-Logik erhöht Fehleranfälligkeit
- Testtiefe wirkt gemessen am Umfang noch zu niedrig
