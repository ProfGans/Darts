# Voice Platform Setup

## Current repo state

The current workspace contains `android`, `web`, and `windows` targets.
There is no `ios` or `macos` target folder in this repository yet.

## Android

Already added:

- `android.permission.CAMERA` in
  `android/app/src/main/AndroidManifest.xml`
- `android.permission.RECORD_AUDIO` in
  `android/app/src/main/AndroidManifest.xml`

## Windows

No extra manifest permission was added for the current Win32 runner.
The voice feature relies on runtime availability of:

- Windows speech recognition for `speech_to_text`
- an available back camera for the board capture flow

If either service is unavailable, the app now fails gracefully and keeps the
affected feature disabled.

## iOS

When an iOS target is generated later, add these keys to
`ios/Runner/Info.plist`:

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

Suggested values:

- `NSCameraUsageDescription`: `Die App nutzt die Kamera, um Dartspitzen am Board als Treffer-Vorschlag zu erkennen.`
- `NSMicrophoneUsageDescription`: `Die App nutzt das Mikrofon fuer die Spracheingabe von Dart-Aufnahmen.`
- `NSSpeechRecognitionUsageDescription`: `Die App nutzt die Spracherkennung, um Aufnahmen und Check-Ansagen freihand zu erfassen.`

After adding the iOS target, the voice and camera features should also be
tested for:

- camera permission prompt on first launch
- microphone and speech permission prompts on first launch
- a stable back-camera preview with the board fully visible
