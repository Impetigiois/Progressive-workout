# Overload Log (iPhone, SwiftUI)

A 7-week progressive overload tracker. Push (Mon), Legs (Tue), Pull (Wed), Plyometrics (Fri).
Targets for every set are calculated from your last session, and the Progress tab shows how
each lift is trending. Requires iOS 17, Xcode 15 or newer, and a Mac.

## Run it on your iPhone

1. In Xcode: File > New > Project > iOS > App.
   Product Name `OverloadLog`, Interface `SwiftUI`, Language `Swift`. Save it anywhere.
2. Delete the `OverloadLogApp.swift` and `ContentView.swift` files Xcode created.
3. Drag the seven `.swift` files from the `OverloadLog` folder in this zip into the project
   (tick "Copy items if needed" and your app target).
4. Set the project's Minimum Deployments to iOS 17.0.
5. Plug in your iPhone, pick it as the run destination, and press Run.
   First time only: on the phone, turn on Settings > Privacy & Security > Developer Mode,
   and trust your developer certificate under Settings > General > VPN & Device Management.
   A free Apple ID works, but the app expires after 7 days until you run it again.

Shortcut: if you use XcodeGen (`brew install xcodegen`), run `xcodegen` in this folder
and open the generated `OverloadLog.xcodeproj` instead of steps 1 to 4.

## How it works

- **Progression:** +1 rep each session, a weight step once you top the rep range, repeat a
  missed target. Week 7 is a deload (about 10% lighter, one fewer set).
- **RIR:** Week targets are editable under Plan. Lifts you marked 0–1 RIR follow the weekly
  target down to 0, the rest stop at 1.
- **Plyometrics:** no RIR. Bodyweight drills hold at the top of their range. Loaded drills
  add weight (or box height in inches) once the range is topped.
- **Back flag:** every exercise has a supported swap ready. The swap is recorded and the
  old lift's history is kept.
- **Data:** saved on the phone only. Plan > Share backup exports it as text and
  Plan > Restore brings it back.
