# OM0RX-xCluster

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](#requirements)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

A native macOS DX-cluster client for **Oliver Bross OM0RX**. It connects to one or more clusters, classifies live spots from a selected RUMlogNG logbook, shows full previous-QSO evidence, and hands a double-clicked spot to RUMlogNG for radio tuning and the station's configured rotator workflow.

## Highlights

- Simultaneous, auto-reconnecting telnet connections; `cluster.shackcq.com:7300` is included by default.
- Dense live spot table with call, frequency, mode, country, CQ zone, call status, DXCC status, special tags, exact worked-before date, score, source, spotter, and comment.
- One-row, color-coded multi-select filters for bands, modes, continents, call/DXCC status, specials, source, and worked-before state, plus free text and sorting. Each selector supports one, several, or all values.
- OM0RX call/DXCC status rules and configurable status colors.
- Configurable multi-match special-station regular expressions (POTA, SOTA, IOTA, WWFF, bunkers, castles, lighthouses, contests, and IARU by default).
- Direct `.rlog` access using SQLite `READONLY` plus `PRAGMA query_only=ON`; the app never writes to the RUMlog database.
- Previous-QSO sheet with contact details, independently colored LoTW upload/download arrows, DXCC/grid summary, and a populated band/mode matrix (orange worked, green confirmed, dash untouched).
- RUMlogNG Apple-event handoff of callsign, mode, log frequency, and TX frequency on deliberate double-click.
- Cluster passwords stored in macOS Keychain.

## Build

```bash
swift test
./scripts/make-icon.sh
./scripts/package-app.sh
```

The packaged app is written to `dist/OM0RX-xCluster.app`. The packaging script uses an available Developer ID Application identity, otherwise it creates an ad-hoc signed development build.

## First run

1. Open Settings → General and choose the `.rlog` currently open in RUMlogNG.
2. In Settings → Clusters, confirm your login callsign and enable the desired servers.
3. Save and apply. The status rail will show both live cluster count and contact count.
4. Click a callsign to inspect previous QSOs. Double-click a row to send it to RUMlogNG.
5. Approve the macOS Automation request for RUMlogNG on first tune.

## Safety boundaries

- Logbook access is read-only. Wavelog synchronization remains the responsibility of OM0RX-xBridge.
- Tuning is not attempted from a single click. A double-click or explicit **Tune RUMlogNG** button is required.
- Live cluster authentication, RF tuning, and rotor motion depend on the operator's network, RUMlogNG configuration, radio, and rotator. Local tests cannot prove those external paths.

## Requirements

- macOS 13 or newer
- RUMlogNG for tuning and station integration
- A RUMlog `.rlog` file for worked/confirmed classification

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
