# Changelog

## 0.1.2 — 2026-10-11

- Adds a cluster-command console beside the RUMlog contact count, with one/all-cluster targeting, useful read-only presets, custom commands, and copyable responses.
- Removes trailing DX-cluster UTC timestamps such as `0003Z` from spot comments while preserving meaningful numbers elsewhere.
- Requests RBN/Skimmer spots from each cluster with `set/skimmer` by default and provides a setting to disable the upstream feed.
- Hides exact callsign/band/mode combinations already worked by default, with a setting to show them; new-band and new-mode opportunities remain visible.
- Corrects the Previous QSOs matrix to show country-wide DXCC band/mode history rather than only the selected callsign's history.
- Adds configurable OM0RX-xCat/RigCtlD mode control after the RUMlog handoff, because RUMlog's Apple-event `txFrequency` changes radio frequency but not radio mode.

## 0.1.1 — 2026-10-11

- Fixes Worked b4 dates when a callsign was worked on the same band in a
  different mode, while keeping genuinely new-band rows blank.
- Corrects Call Status so a mode is considered new within the selected band;
  a worked band with an unworked band/mode combination is now New Mode.
- Adds unmistakable top and bottom controls for closing the Settings sheet.
- Restores the Vue spot-table palette, including status text, row tints, score
  badges, frequencies, callsigns, worked dates, and per-programme special badges.
- Removes the native grey menu bezel so every single-row filter keeps its own
  visible accent colour. Multi-select filters use persistent checkbox popovers,
  keep **All** checked at the top, and stay open while options are chosen.
- Replaces the default regular-expression editor with human-readable keywords
  and named reference formats; expert patterns remain available when expanded.
- Makes one click anywhere on a spot row tune through RUMlogNG immediately;
  clicking the callsign is reserved exclusively for Previous QSOs.
- Watches both the RUMlog database and its WAL every three seconds, removes a
  callsign as soon as a newly logged contact appears, and reclassifies remaining
  spots without reconnecting the clusters. Logbook reads cannot overlap and use
  a shared parser per refresh for substantially lower CPU cost.

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
