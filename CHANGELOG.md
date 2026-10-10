# Changelog

## 0.1.0 — 2026-10-11

Initial native macOS build by Oliver Bross OM0RX.

- Connects simultaneously to one or more auto-reconnecting DX clusters, with
  `cluster.shackcq.com:7300` and the dedicated `OM0RX-12` reader identity as the
  default.
- Reads a chosen RUMlogNG `.rlog` database strictly read-only and classifies
  calls, bands, modes, DXCC state, specials, and worked-before dates.
- Provides one color-coded row of multi-select filters with **All** first in
  each categorical menu.
- Shows previous QSOs, independent LoTW upload/confirmation arrows, and a full
  band/mode matrix with orange worked, green confirmed, and `-` untouched cells.
- Sends a deliberately double-clicked spot to RUMlogNG for station tuning and
  the operator's existing rotator workflow.
- Includes configurable clusters, semantic status colors, and special rules,
  plus a custom OM0RX family dock icon.
