# EarGuard

Personal LAN tool to monitor and remotely control the volume of household Android phones,
with a high-frequency ("annoying sound") detector and warning.

One codebase, two build flavors:

- **Agent** (`com.msob7y.eargaurd.agent`): install on household phones. Runs a foreground
  service exposing an HTTP control server, auto-caps volume, detects high-frequency sound,
  and plays a warning. Restarts on boot and network change.
- **Manager** (`com.msob7y.eargaurd.manager`): install on your phone. Auto-discovers agents
  on the LAN (mDNS) and controls them.

## Features

- **Volume control**: read/set volume, `+/-` steps, live current value.
- **Auto-cap**: optional ceiling; if a phone's volume exceeds it, it's pulled back down. Off by default.
- **High-frequency detection**: captures a short mic window, FFTs it, reports the **peak** in a
  configurable band (default 8–20 kHz) as dBFS. If it exceeds a threshold, plays a warning.
- **Live spectrum**: real-time frequency × dBFS graph on the agent to find the offending tone
  and tune the band/threshold. Uses the least-processed mic source available (`UNPROCESSED` →
  `VOICE_RECOGNITION` → `MIC`).
- **Discovery**: agents advertise `_eargaurd._tcp`; manager lists them automatically, with
  manual add-by-IP as a fallback.

## Build

```
flutter pub get
flutter build apk --release --flavor agent   --split-per-abi
flutter build apk --release --flavor manager --split-per-abi
```

Install the **arm64-v8a** APK from `build/app/outputs/flutter-apk/` on modern phones
(~17 MB each). Debug run needs a flavor too: `flutter run --flavor agent|manager`.

Release signing reads `android/key.properties` (keystore `android/eargaurd-release.jks`);
falls back to debug signing if absent. **Change the default keystore password.**

## HTTP API (agent, port 8723, plain HTTP on LAN)

| Route | Purpose |
|---|---|
| `GET /status` | volume, max, cap, capEnabled, threshold, minHz, maxHz, micReady |
| `POST /volume?level=` · `/volume/step?delta=±1` | set / step volume |
| `POST /cap?level=` · `/cap/enable?on=` | cap ceiling / toggle |
| `POST /band?minHz=&maxHz=` · `/threshold?value=` | detection band / warn threshold |
| `POST /analyze` | spectrum snapshot, no warning |
| `POST /check` | analyze band peak, warn if over threshold |
| `POST /warn` | play warning now |

## Setup notes (agent phones)

- Grant **mic + notification** on first start; tap **Disable battery optimization** so the service survives Doze.
- After a reboot the server and volume control run immediately, but the **remote mic check** stays
  disabled until the app is opened once (Android forbids starting a background mic service). The
  agent screen shows a "mic ready" indicator.
- Reserve a **static DHCP lease** per phone so IPs don't drift.
- Detection is relative **dBFS**, not calibrated SPL, and phone mics roll off at high frequencies:
  use the live spectrum to set the band/threshold to what you actually see.

## Tuning detection

Agent → Detection → toggle **Live** → play the sound near the phone → watch where the peak spikes →
drag the band to bracket it → set the threshold just below the peak. Remote `/check` then uses these.

# Credits

Created and written by claude (opus 5)