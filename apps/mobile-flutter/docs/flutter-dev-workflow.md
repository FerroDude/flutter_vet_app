## Flutter development workflow in Cursor

- **Extensions**

  - Install “Dart” and “Flutter” (by Dart-Code) in Cursor.

- **Select a device**

  - Ctrl+Shift+P → “Flutter: Select Device” → pick Chrome (web) or an emulator/physical device.

- **Run under the debugger**

  - Press F5 (Run and Debug). Choose “Dart & Flutter” if prompted.
  - Hot reload on save works only when the app is running in the debugger.

- **Hot reload on save**

  - Workspace settings in `.vscode/settings.json`:
    - `"dart.flutterHotReloadOnSave": "all"`
    - `"dart.flutterHotRestartOnSave": "never"`
  - Save any `.dart` file to trigger hot reload. The debug console should show “Reloaded …”.

- **Hot restart and full restart**

  - Hot restart: use the restart button in the debug toolbar (resets app state).
  - Full restart required if you change `main()`, plugin setup, `pubspec.yaml` assets, native code, or other initialization code.

- **Notes for Web (Chrome)**

  - On Flutter Web, some changes will trigger a hot restart instead of a hot reload (state may reset). This is expected behavior on web.

- **Terminal-only workflow (alternative)**

  - `flutter devices`
  - `flutter run -d chrome` (or your device)
  - In the running console: press `r` for hot reload, `R` for hot restart.

- **Troubleshooting**
  - Ensure you started the app with F5 (debugger) for save-to-reload.
  - Verify Flutter/Dart extensions are installed.
  - Check the debug console: “Reloaded …” = hot reload, “Restarted …” = hot restart.
