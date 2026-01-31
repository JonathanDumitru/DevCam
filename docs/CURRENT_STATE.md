# Current State Snapshot (2026-01-23)

## Summary
- Initial durability test is successful; 5/10/15 minute retroactive clips record at full resolution.
- Buffer is fixed at 15 minutes; no forward-recording or longer-than-15 clip mode in the UI yet.
- Performance remains low during recording; brief energy spikes occur when opening Preferences or revealing files.
- Console log spam observed: "Sample buffer has no image buffer" (mitigation in progress).
- Resolution selection (720p through native) is working; verified by Jonathan Hines Dumitru.

## Observed Behavior
- Recording starts automatically and maintains a rolling 15-minute buffer.
- Save actions are enabled once buffer time accumulates.
- Menubar reports recording state and export progress.

## Evidence
- Recent test notes provided via console logs and Activity Monitor during the 15-minute run.

## Test Context
- User scenario: Apple TV in Picture-in-Picture over Console.app.
- Screen recording permission reported as granted.
- Single display detected at 1920x1080.

## Impact
- CPU averages ~4% (peaks ~6%).
- Memory stays under ~100 MB.
- Disk activity remains under ~1 MB during steady-state observation.
- Energy impact is low on average, with spikes when opening Preferences or revealing files.

## Minimum Performance Target (M1)
- CPU average <= 5% during steady recording; peak <= 8% during UI actions.
- Memory <= 150 MB during a 15-minute run.
- Energy impact low on average; brief spikes allowed for Preferences and file actions.
- Disk activity minimal during steady recording; temporary spikes during export/buffer rotation.

## In Progress
- Investigating and reducing "Sample buffer has no image buffer" log spam.
- Planning a save-range selection UI (from app launch onward) and a compact menubar prompt.

## Prior Incidents (Resolved)
- AVAssetWriterInput output settings crash fixed by nesting compression properties.
- `incident-logs/DevCam-2026-01-23-075747.ips`
- `incident-logs/DevCam-2026-01-23-080819.ips`
- `incident-logs/DevCam-2026-01-23-100353.ips`
- `incident-logs/DevCam-2026-01-23-102332.txt`
- `incident-logs/DevCam-2026-01-23-104322.txt`
- `incident-logs/DevCam-2026-01-23-104842.txt`

## Open Questions / Missing Info
- macOS version, hardware model (Intel/Apple Silicon), and display setup.
- Whether log spam persists without Picture-in-Picture or at lower resolutions.
- Whether energy spikes improve with a lower resolution selection.
- Performance impact across the new resolution options on M1 baseline hardware.

## Related Docs
- `incident-logs/2026-01-23-incident.md`
- `docs/TROUBLESHOOTING.md`
