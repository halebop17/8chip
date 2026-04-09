# 8chip — Update Plan

## What this plan covers

All changes are inside `com.halebop.8chip.xrnx/`. The AKWF-FREE repo is
the external waveform library source; its files are not modified here (Phase
1A of that repo is already complete — `AKWF/Halebop_chip/` exists with 15
WAV files).

---

## Summary of changes

| Phase | What                                           | Files touched                                         |
| ----- | ---------------------------------------------- | ----------------------------------------------------- |
| A     | Shared canvas waveform rendering module        | `ui/canvas_wave.lua` *(new)*                          |
| B     | Waveform Studio tab — remove NES, add canvas   | `ui/waveform_panel.lua`                               |
| C     | Presets tab — add canvas + new GB/SID presets  | `ui/presets_panel.lua`, `data/presets/gameboy.lua`, `data/presets/c64.lua`, `data/chip_samples/` *(new folder)* |
| D     | New "Single Cycle" tab (AKWF browser)          | `ui/singlecycle_panel.lua` *(new)*, `ui/dialog.lua`, `preferences.lua` |

---

## Phase A — canvas_wave.lua (shared module)

**New file:** `ui/canvas_wave.lua`

A self-contained module that creates and manages a canvas waveform preview
widget. Used by three tabs; all share the same rendering logic.

**Public API the module exposes:**
```lua
local CW = require "ui.canvas_wave"

local view   = CW.create(vb, width, height)   -- returns the vb:canvas view
CW.set_data(view, samples_table)               -- float array [-1.0, 1.0]
CW.clear(view)                                 -- blank / no signal state
```

**Visual spec:**
- Background: solid black `{0, 0, 0}`
- Center reference line: dark green `{20, 60, 10}`, 1 px
- Waveform stroke: neon green `{57, 255, 20}`, 1.5 px
- No signal: just background + faint center line

**Data flow:**
- `set_data()` stores the samples table in a module-level reference keyed to
  the canvas view object, then calls `view:invalidate()`
- The render callback reads from that reference; if nil, draws blank

---

## Phase B — Waveform Studio tab

**File:** `ui/waveform_panel.lua`

### Remove
- The entire "NES Authenticated Samples" section at the bottom of the panel
  (the dropdown + "Load NES Sample" button). This functionality lives in the
  Presets tab where it belongs.

### Add
- Canvas waveform display at the bottom of the panel (full panel width, 80 px
  tall), using `CW.create()` from Phase A.
- `CW.set_data()` is called whenever:
  - The waveform type popup changes
  - The duty cycle slider changes (pulse type)
  - The FM op ratio or mod index sliders change
  - The Generate or Preview button is clicked
- Data source: call `build_frames(prefs)` (already exists in this file) and
  feed the resulting float table directly to `CW.set_data()`. No extra loading
  required — the math is already there.

---

## Phase C — Presets tab + new chip presets

### C1 — canvas display in presets panel

**File:** `ui/presets_panel.lua`

- Add canvas widget at the bottom (full panel width, 80 px tall).
- `CW.set_data()` is called whenever the preset popup selection changes.
- Data source logic:
  - If `preset.waveform` starts with `"nes_"` → load from the corresponding
    WAV in `data/nes_samples/` using `wave.open` / read frames → normalize to
    float array. (Or reuse the same 5 float arrays, pre-loaded at panel init.)
  - If `preset.waveform` starts with `"chip_"` → load from `data/chip_samples/`
    same way.
  - If `preset.waveform` starts with `"genesis_"` → load from
    `data/genesis_samples/` same way.
  - Otherwise (math type) → call the appropriate `generators.*` function with
    the preset's `num_frames`, `duty`, `fm_op_ratio`, `fm_mod_index` to get
    the float array.

### C2 — new chip sample files

**New folder:** `data/chip_samples/`

Copy these 6 files from `AKWF-FREE/AKWF/Halebop_chip/` at deploy time (they
are small, ~1.2 KB each):

```
gb_wave_saw.wav        (4-bit stepped sawtooth, 32 steps)
gb_wave_triangle.wav   (4-bit stepped triangle, 32 steps)
sid_sawtooth.wav       (linear sawtooth, hardware-accurate)
sid_triangle.wav       (XOR-folded triangle, hardware-accurate)
sid_pulse_25.wav       (25% duty pulse)
sid_pulse_50.wav       (50% duty pulse)
```

The GB and SID *pulse* presets use the existing math generator (their shapes
are identical to a generated pulse). Only the GB wave RAM shapes and the SID
shapes with specific hardware character need the real files.

### C3 — new Game Boy presets

**File:** `data/presets/gameboy.lua`

Add 6 presets (appended to existing 8):

| Name | Waveform key | Notes |
|---|---|---|
| `GB  -  Pulse 12.5%` | `pulse`, duty=0.125 | Math generator, 22050 Hz, 8-bit |
| `GB  -  Pulse 25%` | `pulse`, duty=0.25 | Math generator, 22050 Hz, 8-bit |
| `GB  -  Pulse 50%` | `square` | Math generator, 22050 Hz, 8-bit |
| `GB  -  Pulse 75%` | `pulse`, duty=0.75 | Math generator, 22050 Hz, 8-bit |
| `GB  -  Wave Sawtooth` | `chip_gb_wave_saw` | Loads `data/chip_samples/gb_wave_saw.wav` |
| `GB  -  Wave Triangle` | `chip_gb_wave_triangle` | Loads `data/chip_samples/gb_wave_triangle.wav` |

### C4 — new C64/SID presets

**File:** `data/presets/c64.lua`

Add 4 presets (appended to existing 10):

| Name | Waveform key | Notes |
|---|---|---|
| `SID  -  HW Sawtooth` | `chip_sid_sawtooth` | Loads `data/chip_samples/sid_sawtooth.wav` |
| `SID  -  HW Triangle` | `chip_sid_triangle` | Loads `data/chip_samples/sid_triangle.wav` |
| `SID  -  HW Pulse 25%` | `chip_sid_pulse_25` | Loads `data/chip_samples/sid_pulse_25.wav` |
| `SID  -  HW Pulse 50%` | `chip_sid_pulse_50` | Loads `data/chip_samples/sid_pulse_50.wav` |

"HW" = hardware-accurate, to distinguish from the existing math-generated SID
presets that stay in the list unchanged.

---

## Phase D — New "Single Cycle" tab (AKWF browser)

### D1 — new panel file

**New file:** `ui/singlecycle_panel.lua`

**Layout (~500 × 360 px):**
```
+--------------------------------------------------+
| Library:  [ path display / "bundled" ]  [Browse] |
+--------------------------------------------------+
| Bank:  [ popup menu — scanned bank names v ]     |
+------------------------+-------------------------+
| Waveform list          |  Canvas preview         |
| (scrollable valuebox   |  (full right column     |
|  or listbox if avail.) |   width, 80 px tall)    |
|  e.g. sin_0001         |                         |
|  e.g. sin_0002  <sel>  |                         |
+------------------------+-------------------------+
| Insert mode: [ Single v ]   [ INSERT ]           |
| (Wavetable Spread shows N-select hint when chosn)|
+--------------------------------------------------+
```

**Bank scanning logic:**
- On panel init (or on library path change): scan top-level subfolders of the
  library root for folders containing at least one `.wav` file.
- Populate bank popup with folder names.
- On bank selection: list all `.wav` files in that folder, sorted.

**Canvas preview:**
- On waveform selection: read the WAV file using `wave.open`, decode to float
  array, pass to `CW.set_data()`.
- Fallback: if a matching `.json` exists in `AKWF-js/` (same bank name), read
  the JSON array instead — lighter, no wav decode needed. Optional
  optimisation, not required for v1.

**Insert modes:**

*Single:*
- `instrument:insert_sample_at(#instrument.samples + 1)` (or into slot 1 if
  empty)
- `sample_buffer:load_from(wav_path)`
- `sample.loop_mode = LOOP_MODE_FORWARD`
- `sample.loop_start = 1`, `sample.loop_end = num_frames`
- `sample.name = filename_without_extension`
- No transpose correction applied — user controls pitch as normal

*Wavetable Spread:*
- User can select multiple waveforms in the list (Ctrl+click or shift+click if
  Renoise listbox supports it; otherwise N field + consecutive auto-select)
- Each selected WAV → one sample slot
- Sample key zones distributed evenly across C0–B9
- All slots: forward loop, no transpose

### D2 — dialog.lua update

**File:** `ui/dialog.lua`

- Add 8th tab label: `"Single Cycle"` in the switch widget items table
- Import and call `create_singlecycle_panel(vb)` in the panel creation block
- Add visibility toggle in `show_tab()` for index 8

### D3 — preferences.lua update

**File:** `preferences.lua`

Add two fields to `renoise.Document.create("ChiptuneToolboxPrefs")`:
```lua
scw_library_path  = "",   -- empty string = use bundled waves folder
scw_last_bank     = "",   -- remember last selected bank name across sessions
```

---

## What is NOT changing

- Arp tab, Pitch tab, Drums tab, Mod tab, Probability tab — untouched
- Existing NES presets — untouched (still load from `data/nes_samples/`)
- Existing Genesis presets — untouched
- Existing 8 Game Boy presets — untouched (new ones are additions)
- Existing 10 C64 presets — untouched (new ones are additions)
- `waveforms/generators.lua` — untouched
- All generator modules — untouched
- `deploy.sh` — may need one line added to copy `data/chip_samples/` files

---

## Build order

Each phase is independent enough to be written and tested separately:

1. **Phase A first** — canvas module needed by all others
2. **Phase B** — simplest change (remove + add one widget), good smoke test of canvas
3. **Phase C1** — canvas on presets, tests WAV-to-float loading path
4. **Phase C2–C4** — new sample files + new preset entries
5. **Phase D** — new tab, largest single piece; broken into D1 (panel) then D2/D3 (wiring)
