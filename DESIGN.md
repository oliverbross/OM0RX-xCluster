---
name: OM0RX-xCluster
description: Dense native macOS DX operations console using the established OM0RX Spots color language.
colors:
  console-background: "#07111F"
  console-surface: "#0B1728"
  console-raised: "#101F34"
  console-rule: "#243A55"
  primary-text: "#E6EDF6"
  secondary-text: "#92A7BF"
  data-cyan: "#35C8F5"
  action-teal: "#12D6A0"
  new-call: "#FF6B35"
  new-band: "#00BFFF"
  new-mode: "#FFC000"
  new-band-mode: "#E91E63"
  dxcc-atno: "#FF8C00"
  confirmed: "#10B981"
  worked: "#B0B0B0"
typography:
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "20px"
    fontWeight: 700
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "12px"
    fontWeight: 600
rounded:
  control: "5px"
  container: "6px"
  panel: "8px"
spacing:
  compact: "5px"
  control: "8px"
  panel: "16px"
  sheet: "18px"
components:
  filter-control:
    backgroundColor: "{colors.console-raised}"
    textColor: "{colors.primary-text}"
    rounded: "{rounded.control}"
    height: "27px"
    padding: "0 8px"
  data-panel:
    backgroundColor: "{colors.console-surface}"
    textColor: "{colors.primary-text}"
    rounded: "{rounded.container}"
    padding: "16px"
---

# Design System: OM0RX-xCluster

## Overview

**Creative North Star: “The Live Operator Console”**

OM0RX-xCluster is a dense radio-operations surface built to be scanned while operating, not a decorative dashboard. Near-black navy layers keep attention on callsigns, frequencies, and status evidence; the established OM0RX Spots colors remain semantic and consistent across the live table, previous-QSO sheet, and settings.

Native macOS behavior stays visible: standard focus, menus, sheets, scroll areas, and accessibility labels. Compact geometry, strict alignment, and one-pixel rules carry the structure.

**Key Characteristics:**

- Dense, full-width operational table.
- One-row color-coded filter deck.
- Text plus color for every status.
- Read-only and connection truth visible in the top rail.

## Colors

The palette combines deep navy equipment-console surfaces with the exact OM0RX Spots semantic colors.

### Primary

- **Action Teal** (`#12D6A0`): app identity, interactive emphasis, and selected details.
- **Data Cyan** (`#35C8F5`): frequencies and data-oriented filter identity.

### Secondary

- **New Call Orange** (`#FF6B35`), **New Band Cyan** (`#00BFFF`), **New Mode Amber** (`#FFC000`), and **New Band+Mode Magenta** (`#E91E63`): call-status semantics.
- **DXCC ATNO Orange** (`#FF8C00`) and **Confirmed Green** (`#10B981`): DXCC urgency and confirmation evidence.
- **Worked Grey** (`#B0B0B0`): worked state in the live table. The history matrix deliberately uses ATNO orange for worked-but-unconfirmed ticks so it cannot be confused with confirmation.

### Neutral

- **Console Background** (`#07111F`), **Surface** (`#0B1728`), and **Raised** (`#101F34`): tonal depth without ornamental shadows.
- **Primary Text** (`#E6EDF6`) and **Secondary Text** (`#92A7BF`): high-contrast data and supporting evidence.
- **Console Rule** (`#243A55`): table dividers, outlines, and panel boundaries.

### Named Rules

**The Semantic Color Rule.** Never reuse a call/DXCC status color decoratively in a way that changes its meaning.

**The Dual-Evidence Rule.** LoTW upload and confirmation are separate signals: the up arrow turns green only when uploaded, and the down arrow turns green only when confirmed.

## Typography

**Display Font:** San Francisco via the native macOS system stack.
**Body Font:** San Francisco via the native macOS system stack.

**Character:** Compact and highly legible. Weight establishes hierarchy while monospaced numerals keep frequencies and status data stable.

### Hierarchy

- **Title** (700, 20px): window and sheet identity.
- **Headline** (600, native title-3): section titles and important evidence.
- **Body** (400, 13px): table and settings content.
- **Label** (600, 12px): headers, filters, and metadata.

## Layout

The first viewport is a narrow truth rail, one horizontally scrollable filter row, the live spot table, and a compact bottom inspector. The filter row never wraps. Table density is preserved as the window narrows through horizontal scrolling rather than collapsing evidence-bearing columns. Settings and previous-QSO details use native sheets.

## Elevation & Depth

The system is flat by default. Depth comes from three tonal navy layers and one-pixel blue-grey rules; shadows are not part of the primary visual vocabulary.

## Shapes

Controls use restrained 5px corners, data containers 6px, and larger panels 8px. Pills are reserved for small status/special badges; structural surfaces remain compact rounded rectangles.

## Components

### Filter Controls

- **Shape:** 5px rounded rectangle, 27px high.
- **Color:** each filter family has a distinct tinted fill, border, and label color; active multi-select filters increase saturation.
- **Behavior:** every categorical filter supports one, several, or all values and stays in the single horizontal row.

### Live Table

- **Style:** fixed semantic column order, 30px headers, one-pixel row separators, strong callsign and frequency hierarchy.
- **Status:** call and DXCC strings use configurable colors from `StatusPalette`; color never replaces the text label.

### Previous-QSO Sheet

- **Style:** contact history first, evidence badges second, band/mode matrix last.
- **Matrix:** orange check means worked but unconfirmed, green check means confirmed, and `-` means neither.
- **LoTW:** solid up/down arrows remain visible; each independently turns confirmed green only when its state is true.

## Do's and Don'ts

### Do:

- **Do** keep all filters in one row and expose active multi-selection counts.
- **Do** use the canonical OM0RX status palette and preserve text labels.
- **Do** use truthful disconnected, loading, empty, unknown, and read-only states.
- **Do** keep high-value operating data visible before explanatory copy.

### Don't:

- **Don't** wrap filters into a second row.
- **Don't** replace status evidence with color-only dots or generic macOS accent colors.
- **Don't** add large decorative cards, gradients, glow, or dashboard whitespace to the operating surface.
- **Don't** show an empty matrix cell; use `-` explicitly.
