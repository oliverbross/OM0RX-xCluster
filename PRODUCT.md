# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Stack

Delegated: native SwiftUI and Swift Package Manager, chosen to match OM0RX-xCat, use RUMlogNG Apple events directly, and ship as a self-contained `.app` without a browser runtime.

## Users

The primary user is an amateur-radio operator running RUMlogNG on a Mac who needs a dense, continuously updating DX-cluster view during live station operation.

## Product Purpose

OM0RX-xCluster connects to one or more DX clusters, classifies spots against the operator's selected RUMlog logbook, exposes the existing OM0RX filters and status language, and hands a chosen callsign and frequency to RUMlogNG for radio and rotator action.

## Positioning

Unlike a generic cluster client, xCluster derives call, band, mode, DXCC, confirmation, and worked-before state directly from the same RUMlog logbook that the station uses, while preserving the OM0RX status and special-station rules.

## Operating Context

The app runs beside RUMlogNG during live operating. The operator scans a dense table, narrows it with persistent filters, clicks the callsign for previous-QSO evidence, and clicks another row cell to transfer the target to RUMlogNG. The selected `.rlog` is also synchronized with Wavelog by OM0RX-xBridge.

## Capabilities and Constraints

- Connect simultaneously to one or more configurable telnet DX clusters; `cluster.shackcq.com:7300` is the default.
- Read a user-selected RUMlog `.rlog` via SQLite `READONLY` and `PRAGMA query_only=ON`; never modify it.
- Match the established call/DXCC status names, colors, special rules, bands, modes, scoring, and worked-before behavior.
- Show complete previous-contact details and a populated band/mode matrix.
- Send callsign, operating mode, logging frequency, radio tuning frequency, and optionally the cleaned spot comment as the QSO note to RUMlogNG through its Apple-event interface.
- Store cluster passwords in Keychain rather than preferences.
- Target macOS 13 or newer.
- Live RF tuning, RUMlog auto-rotation, and cluster authentication require the operator's installed applications, hardware, settings, and network.

## Brand Commitments

The product name is `OM0RX-xCluster`. It is a sibling of `OM0RX-xCat` and uses the established dark navy operator-console surfaces, cyan/teal data accents, green confirmations, and the existing status-specific colors from OM0RX Radio Control.

## Evidence on Hand

- Source behavior: `/Users/oliver/Documents/Projects/om0rx-radio-control`.
- Existing native integration patterns: `/Users/oliver/Documents/Projects/Rumlog-Wavelog-Bridge` and `/Users/oliver/Documents/Projects/OM0RX-xCat`.
- UI references: the two screenshots supplied with the build request.
- Live logbook schema inspected from `/Users/oliver/Documents/Ham Radio/om0rx-vk8rx.rlog`.

## Product Principles

- Status is evidence-backed; unavailable data is shown as unknown rather than guessed.
- The operating table stays dense, fast, and keyboard-readable.
- RUMlog data is strictly read-only.
- Configuration is explicit and recoverable.
- Radio-affecting actions require a deliberate double-click.

## Accessibility & Inclusion

Status is communicated by text as well as color. Controls use native macOS focus, keyboard, VoiceOver labels, and reduced-motion behavior.
