# Flow: Save Clip (Menubar or Shortcuts)

Goal: Export the last N minutes of the rolling buffer to a single mp4.

Entry points
- DevCam/DevCam/UI/MenuBarView.swift: Save Clip button and Advanced window slider.
- DevCam/DevCam/DevCamApp.swift: setupKeyboardShortcuts -> KeyboardShortcutHandler.
- DevCam/DevCam/Utilities/KeyboardShortcutHandler.swift: Cmd+Option+5/6/7 triggers.

Steps
1. UI or shortcut calls ClipExporter.exportClip(duration:).
2. ClipExporter queries BufferManager.getSegmentsForTimeRange(duration:).
3. ClipExporter builds an AVMutableComposition from segment assets.
4. ClipExporter exports to an output URL with AVAssetExportSession.
5. ClipExporter records a ClipInfo entry and updates recentClips.
6. MenuBarView and ClipsTab observe exportProgress and recentClips to update UI.

Notes
- ExportError.noSegmentsAvailable is thrown if the buffer is empty.
- Save location and notifications come from AppSettings at ClipExporter initialization.
