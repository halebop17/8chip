# 8chip — Renoise Chiptune Toolbox

A Renoise `.xrnx` tool with 8 modules for chiptune composition: waveform generation, console instrument presets, single-cycle browsing/wavetable staging, arp/phrase generation, pitch effects, percussion shaping, modulation injection, and probability tools.

**Requires:** Renoise 3.5+
Credit to Adventure Kid for his single cycle waveforms of which some are included in 8chip.
https://www.adventurekid.se/akrt/waveforms/

---

## Installation

1. Copy the `com.halebop.8chip.xrnx` folder into your Renoise Tools directory:
   - **macOS:** `~/Library/Preferences/Renoise/V3.x.x/Scripts/Tools/`
   - **Windows:** `%APPDATA%\Renoise\V3.x.x\Scripts\Tools\`
2. In Renoise: **Tools → Reload All Tools**
3. Open via **Tools → 8chip** or the assigned keybinding

---

## Tabs

The UI uses a 2-row top menu (4 tabs per row).

### 1. Waveforms

Generates a mathematical waveform and writes it directly into the selected instrument's sample slot. No audio files are used.

**Waveform types:**
| Type | Description |
|------|-------------|
| Sine | Pure sine — smooth, warm |
| Pulse | Variable duty cycle — set width with the Duty slider (default 25%) |
| Square (50%) | Hard 50% duty square — NES/GB pulse character, fixed duty |
| Sawtooth | Full-spectrum bright saw — SID/Genesis lead character |
| Triangle | Smooth triangle — NES bass, GB wave channel feel |
| Noise | White noise — drums, percussion |
| FM | Two-operator FM — Genesis YM2612 metallic/electric piano tones |

**Controls:**
- **Waveform** — type selector
- **Frames** — number of samples per cycle (32–4096); shorter = more aliased/lo-fi
- **Duty %** — pulse width, active for Pulse type only (default 25%)
- **FM Ratio / FM Mod** — operator ratio and modulation index, active for FM only
- **Sample Rate** — 8000 Hz (lo-fi) / 11025 / 22050 / 44100 Hz (full quality)
- **Bit Depth** — 8 / 16 / 32-bit
- **Loop Mode** — Forward / Ping-Pong / Off
- **▶ Preview** — plays the waveform via the currently selected instrument slot
- **Generate** — writes waveform to the selected instrument's sample buffer

---

### 2. Presets

Browse and load authentic chip instrument presets. Each preset either loads a real hardware sample or generates a mathematical waveform — see the console list below.

**Consoles:**
| Console | Sample source | Notes |
|---------|--------------|-------|
| NES | Real APU hardware recordings (bundled) | Authentic — staircase triangle, pulse with correct harmonic content |
| Game Boy | Mathematical | Pulse and noise channels are mathematically exact; wave channel is a user-defined blank canvas by hardware design |
| C64 / SID | Mathematical (real samples optional — see below) | Falls back to math if BPB samples not installed |
| Genesis | Bundled single-cycle samples | Authentic YM2612 FM tones; kick, snare, and hi-hat are one-shot recordings |

**Controls:**
- **Console** — dropdown to select category
- **Preset** — dropdown listing all presets in the selected category
- **Description** — brief description of the selected preset
- **Preview** — non-destructive audition (uses a temporary instrument, then removes it)
- **Load Preset** — adds a new instrument slot with the selected preset
- **Load Full Kit** — adds all presets in the category as separate instrument slots, with a naming convention (`[ch.XX]`) for phrase routing

**Kit routing:** When using Load Full Kit, a "phrase holder" slot is created at the base index. Each sound slot is named with its instrument column number, e.g. `NES Pulse 1 [ch.02]`. Write your pattern notes triggering the phrase holder slot; the phrase's instrument column references control which sound slot plays per line.

#### Optional: Authentic C64 / SID Samples

The C64 presets use mathematical waveforms by default. You can upgrade them to real SID 8580 hardware recordings by installing the free BPB C64 Synth Sessions sample packs:

1. Download for free (no account required):
   - [BPB C64 Synth Sessions Part 1](https://bedroomproducersblog.com/2012/03/13/commodore-64-synthesizer-sessions-part-1-free-sample-pack/)
   - [BPB C64 Synth Sessions Part 2](https://bedroomproducersblog.com/2012/04/03/commodore-64-synthesizer-sessions-part-2-free-sample-pack/)
2. Extract each archive
3. Open the `Samples` folder inside each archive
4. Copy the instrument subfolders you want into:
   ```
   com.halebop.8chip.xrnx/data/c64_samples/
   ```
   Keep folder names unchanged (`Legend Of SID`, `MiniSID #1`, `Soft Pulse`, etc.)
5. Reload Renoise tools — the plugin detects the files automatically and uses them instead of the math fallback

**Which folders map to which presets:**
| Preset name | BPB folder |
|-------------|-----------|
| SID Lead | `Legend Of SID` |
| SID Bass | `MiniSID #1` |
| SID Soft Bass | `Soft Pulse` |
| SID Pad | `Rainy Metropolis` |
| SID Sub | `Slow & Low` |
| SID Grand | `SID Grand` |

> **Note:** These samples are 100% royalty-free for music use but may not be redistributed. Download them directly from BPB. See their license for details.

---

### 3. Arp

Writes arpeggio patterns into a phrase on the selected instrument. Three modes available.

**Modes:**
| Mode | How it works |
|------|-------------|
| Hardware (0A effect) | One note per line; `0A XY` effect cycles chord intervals each tick. Most accurate to NES/C64/GB hardware arps. X = second interval semitone, Y = third. |
| Explicit notes | Each chord note written as a separate phrase line. More readable, supports per-note velocity and probability. |
| Script (pattrns) | Writes a `pattrns` Lua script into an `InstrumentPhrase.PLAY_SCRIPT` phrase. Algorithmic, live-tweakable. |

**Controls:**
- **Mode** — Hardware / Explicit / Script
- **Root note** — base pitch (C0–B9)
- **Chord** — chord type (see chord table below)
- **Octave span** — 1–3 octaves
- **Pattern** — Ascending / Descending / Ping-Pong / Down-Up / Skip (1-3-2) / Random
- **LPB** — phrase lines per beat (4–64); higher = faster arp
- **Length** — total phrase length in lines
- **Loop** — whether the phrase loops
- **▶ Preview** — synthesises the arp as a square-wave audio buffer and plays it
- **Write to Phrase** — writes the arp into a **new** phrase on the selected instrument
- **Live Mode** *(Script mode only)* — checkbox that makes any change to Root, Chord, Pattern, Octave, LPB or Loop instantly re-write the current script phrase. Useful for real-time performance or auditioning chord changes without clicking Write each time. Live Mode always overwrites the currently selected phrase rather than creating a new one — disable it before switching to a different phrase.

**Chord reference:**
| Chord | Intervals (semitones) |
|-------|-----------------------|
| Power | 0, 7 |
| Major | 0, 4, 7 |
| Minor | 0, 3, 7 |
| Diminished | 0, 3, 6 |
| Augmented | 0, 4, 8 |
| Sus2 | 0, 2, 7 |
| Sus4 | 0, 5, 7 |
| Octave | 0, 12 |
| Major 7 | 0, 4, 7, 11 |
| Minor 7 | 0, 3, 7, 10 |
| Dominant 7 | 0, 4, 7, 10 |

> **About the preview:** The arp preview synthesises a square-wave audio buffer — it always sounds like a square wave regardless of the instrument. This is by design; the arp generator produces phrase data, not audio. The preview lets you hear the rhythm and note pattern, not the final timbre.

> **About Script mode:** Script phrases require the `pattrns` scripting engine built into Renoise 3.5. The written script is a live Lua expression that Renoise re-evaluates on playback. On pre-3.5 builds, Script mode automatically falls back to Explicit mode.

> **New phrase behaviour:** Every click of Write Phrase (on Arp, Pitch, Drums, and Mod tabs) always inserts a **new** phrase rather than overwriting the selected one. This prevents accidental destruction of existing phrase data. The only exception is Arp Live Mode, which intentionally overwrites the current phrase for real-time use.

---

### 4. Pitch

Writes pitch effect commands (`0U` slide up, `0D` slide down, `0G` portamento) into a new phrase on the selected instrument.

**Presets:**
| Preset | Effect written | Character |
|--------|---------------|-----------|
| Laser Zap | `0U` rise over N lines, then `0C` cut | Fast upward sweep then silence — laser/zap sound effect |
| Kick Drop | `0D` descend from start note | Pitch-drop kick drum |
| Bass Glide | `0G` portamento between two notes | Smooth glide between defined start and end note |
| Portamento Bass | Alternating root/fifth pattern with `0G` | Walking bass with glide |

**Controls:**
- **Preset** — type selector
- **Note / Start note / End note** — pitch reference(s) depending on preset
- **Speed (Sweep Rate)** — effect value 0–255 controlling sweep rate
- **Sweep lines** — number of lines for the pitch effect to run
- **LPB** — phrase lines per beat
- **Length** — total phrase length
- **Loop** — whether the phrase loops
- **▶ Preview** — synthesises a pitch-accurate audio preview for each preset
- **Write to Phrase** — writes the effect commands into the selected instrument's phrase

---

### 5. Drums

Builds percussion-style phrases using note re-trigger volume fades and Renoise effect commands. Works on top of any instrument — noise or sine work best.

**Presets:**
| Preset | Effects used | Character |
|--------|-------------|----------|
| Kick | Volume step-fade over N lines + `0C` cut | Linear amplitude decay, hard cut at end |
| Snare | `0R` retrigger burst + `0C` cut | Mid-range snap with rapid retrigger echoes |
| Hi-Hat | Very short `0C` per line | Ultra-short tick on every line; add `0Y` probability for shuffle feel |
| Noise Burst | Volume step-fade over N lines + `0C` cut | Decay-shaped noise envelope |

> **How Kick and Noise Burst work:** The phrase retriggers the note on each of the `Decay Lines` with a linearly decreasing volume (e.g. 4 lines: 80% → 60% → 40% → 20%), then fires `0C 00` on the next line to cut. This is standard tracker decay technique — you will see multiple note triggers in the phrase.

**Controls:**
- **Preset** — type selector
- **Note** — root note for the phrase
- **Decay lines** — length of the amplitude decay
- **Retrigger count** — number of `0R` retriggers (Snare only)
- **Cut tick** — tick number at which `0C` fires
- **Probability %** — adds `0Y` value for random note triggering
- **LPB** — phrase lines per beat
- **Length** — total phrase length
- **Loop** — whether the phrase loops
- **▶ Preview** — plays a note via the selected instrument to audition
- **Write to Phrase** — writes percussion effects into the selected instrument's phrase

---

### 6. Mod

Injects vibrato (`0V`), tremolo (`0T`), or auto-pan (`0N`) effect commands into a phrase or into the currently selected pattern region.

**Built-in presets:**
| Preset | Effect | Character |
|--------|--------|-----------|
| Chiptune Vibrato | 0V | Fast speed, shallow depth — classic NES vibrato |
| 16-bit Vibrato | 0V | Fast speed, medium depth — SNES/console style |
| Deep Wobble | 0V | Slow, deep pitch wobble |
| Wobble Bass | 0T | Tremolo — amplitude wobble |
| Tremolo Flutter | 0T | Fast tremolo flutter |
| Wide Stereo | 0N | Auto-pan left/right |
| Fast Pan | 0N | Rapid auto-pan |

**Controls:**
- **Preset** — loads speed/depth/effect from preset
- **Effect** — Vibrato (0V) / Tremolo (0T) / Auto-Pan (0N)
- **Speed** — nibble 0–15 (packed into effect byte high nibble)
- **Depth** — nibble 0–15 (low nibble)
- **Note** — root note for phrase preview
- **LPB** — phrase lines per beat
- **Length** — total phrase length
- **Loop** — whether the phrase loops
- **Target** — **New Phrase** (creates a new phrase on the selected instrument, writing effects and a sustained trigger note on line 1) or **Pattern Region** (injects effects onto lines that already have a note trigger in the selected pattern region — does not write or remove notes)
- **▶ Preview** — plays a modulated note preview
- **Inject** — writes effect commands to the target

> **Effect encoding:** `0V XY` where X = speed nibble (0–F) and Y = depth nibble (0–F). Same encoding for `0T` and `0N`.

> **New Phrase target:** always inserts a fresh phrase with the effect written on every line and a sustained trigger note on line 1. The trigger note is written unconditionally since the phrase is always empty on creation.

> **Pattern Region target:** scans the selected region for lines that already have a note trigger and injects the effect command there, leaving note columns untouched.

---

### 7. Probability

Applies `0Y` (probability) and `0Q` (note delay) effect commands to notes in the **currently selected pattern region**. Select notes in the pattern editor before applying.

**Tools:**
| Tool | What it does |
|------|-------------|
| Probability Scatter | Adds `0Y` values to selected notes, controlling playback chance. Density slider controls how many notes get the effect. |
| Humanize | Scatters small `0Q` delay values (±ticks) across notes for a loose, human feel |
| Fill (Every Nth) | Marks every Nth note with a `0Y` value, creating organic variation without changing the melody |

**Controls:**
- **Tool** — Scatter / Humanize / Fill
- **Density** — proportion of notes affected (0–100%)
- **Probability value** — `0Y` amount: 128 = 50% chance, 255 = always, 0 = never
- **Max delay** — maximum `0Q` ticks for humanize (±value)
- **Every N notes** — fill interval
- **Fill chance** — `0Y` value applied to marked notes
- **Apply** — writes effect commands to the selected pattern region

---

### 8. Single Cycles

Browse internal Adventure Kid waveform selections or any custom WAV folder, preview waveforms, insert one-shots, or build staged 4-slot wavetables.

**Core workflow:**
- **Use Internal** — resets to bundled curated AKWF banks included with the tool
- **Browse** — choose your own folder (each subfolder becomes a bank)
- **Bank** — select a waveform bank
- **Waveform** — choose a waveform in that bank
- **Insert Single** — inserts selected waveform directly as a looped sample
- **+ Add to Wavetable** — stages current waveform into queue (max 4)
- **WAVETABLE QUEUE** — staged filenames listed vertically
- **Insert as Wavetable** — inserts queued waveforms and auto-spreads keyzones across C0-B9

**Notes:**
- Canvas preview is full-width and updates on waveform selection.
- Internal curated library is in `data/bundled_waves/`.
- Internal banks include a broad selection (sine, saw, square, triangle, chip, game, FM, organic).

---

## Tips

- **Phrase LPB vs song LPB:** Phrases have their own LPB setting independent of the song. High phrase LPB (32–64) gives ultra-fast chip arps even at a slow song tempo.
- **Kit routing:** When loading a Full Kit, trigger the phrase-holder slot in your pattern. The phrase's instrument column values reference which sound slot plays on each line. Use the instrument column in the phrase editor to route individual lines to different sounds.
- **Layering presets:** Load multiple presets then route them via the pattern's instrument column for multi-timbral chip tracks.
- **Layering Arp / Pitch / Mod on the same phrase:** Each tab always creates a new phrase, so they do not overwrite each other. To combine Arp + Mod on a single phrase: write the arp first, then use Mod's **Pattern Region** target (not New Phrase) to inject modulation effects onto the existing arp notes. Alternatively, layer two separate phrases on the same instrument — one for arp notes, one for mod effects. The safe rule: **Pitch + Mod is always safe. Arp + Pitch slide is safe. Arp + Vibrato is the one to avoid** — both fight over pitch simultaneously and produce unpredictable results. Arp + Tremolo/Auto-Pan is fine since those affect volume and stereo position, not pitch.
- **Math + effects:** The math presets (C64, Genesis) are designed to be starting points. Apply the Arp, Pitch, Mod, and Drums tabs on top to add authentic chip character.
- **Genesis FM in Waveforms tab:** The Waveforms tab FM generator still works independently. Low mod index (0.3–1.0) = electric piano / organ. High ratio (7.0+) = metallic / bell. Extreme mod index (4.0+) = distorted bass. The Genesis presets in the Presets tab use bundled samples.

---

## Effect Command Reference

| Command | Name | Encoding |
|---------|------|----------|
| `0A XY` | Arp | X = second interval semitone (0–F), Y = third (0–F) |
| `0U XX` | Pitch slide up | XX = speed per tick |
| `0D XX` | Pitch slide down | XX = speed per tick |
| `0G XX` | Glide (portamento) | XX = glide speed |
| `0V XY` | Vibrato | X = speed, Y = depth |
| `0T XY` | Tremolo | X = speed, Y = depth |
| `0N XY` | Auto-pan | X = speed, Y = depth |
| `0C XX` | Volume cut | XX = tick at which volume cuts to zero |
| `0R XX` | Retrigger | XX = retrigger period in ticks |
| `0Y XX` | Probability | 00 = never, 80 = 50%, FF = always |
| `0Q XX` | Note delay | XX = ticks to delay note on |

---

## Bundled NES Samples

The NES presets use authentic single-cycle recordings from real NES APU hardware, sourced from the AKWF (Adventure Kid Waveforms) collection (CC0 / public domain):

| File | Waveform |
|------|---------|
| `nes_square.wav` | 50% duty square / pulse lead |
| `nes_pulse_25.wav` | 25% duty pulse |
| `nes_pulse_12_5.wav` | 12.5% duty pulse (narrowest) |
| `nes_triangle.wav` | Staircase triangle (15-step, hardware character) |
| `nes_noise.wav` | LFSR noise loop |

These are stored in `data/nes_samples/` inside the tool bundle.

---

## Bundled Genesis Samples

The Genesis presets use authentic YM2612 FM tones as single-cycle WAV files. Melodic presets loop over a single C4 cycle; percussion presets are full one-shot recordings.

| File | Type | Preset |
|------|------|--------|
| `genesis_bass.wav` | Single-cycle loop | Genesis — Bass |
| `genesis_epiano.wav` | Single-cycle loop | Genesis — Electric Piano |
| `genesis_lead.wav` | Single-cycle loop | Genesis — Lead |
| `genesis_bell.wav` | Single-cycle loop | Genesis — Bell |
| `genesis_brass.wav` | Single-cycle loop | Genesis — Brass |
| `genesis_clav.wav` | Single-cycle loop | Genesis — Clavinet |
| `genesis_organ.wav` | Single-cycle loop | Genesis — Organ |
| `genesis_kick.wav` | One-shot | Genesis — Kick |
| `genesis_snare.wav` | One-shot | Genesis — Snare |
| `genesis_hihat.wav` | One-shot | Genesis — Hi-Hat |

These are stored in `data/genesis_samples/` inside the tool bundle.

---

## Bundled Chip Samples

Additional hardware-style single-cycle files are bundled for GB wave-channel and SID presets:

| File | Used by presets |
|------|------------------|
| `gb_wave_saw.wav` | `chip_gb_wave_saw` |
| `gb_wave_triangle.wav` | `chip_gb_wave_triangle` |
| `sid_sawtooth.wav` | `chip_sid_sawtooth` |
| `sid_triangle.wav` | `chip_sid_triangle` |
| `sid_pulse_25.wav` | `chip_sid_pulse_25` |
| `sid_pulse_50.wav` | `chip_sid_pulse_50` |

Stored in `data/chip_samples/`.

---

## File Structure

```
com.halebop.8chip.xrnx/
├── manifest.xml
├── main.lua                      ← tool registration and menu entry
├── preferences.lua               ← persistent settings
├── data/
│   ├── chords.lua                ← chord interval tables
│   ├── bundled_waves/            ← curated internal AKWF wave banks
│   ├── chip_samples/             ← bundled GB/SID single-cycle WAVs
│   ├── nes_samples/              ← bundled NES APU recordings (CC0)
│   ├── genesis_samples/          ← bundled Genesis YM2612 WAV samples
│   └── presets/
│       ├── nes.lua
│       ├── gameboy.lua
│       ├── c64.lua
│       └── genesis.lua
├── waveforms/
│   └── generators.lua            ← math waveform generators + sample loader
├── generators/
│   ├── arp_generator.lua
│   ├── pitch_generator.lua
│   ├── percussion_generator.lua
│   └── modulation_generator.lua
└── ui/
    ├── dialog.lua
   ├── canvas_wave.lua
    ├── waveform_panel.lua
    ├── presets_panel.lua
   ├── singlecycle_panel.lua
    ├── arp_panel.lua
    ├── pitch_panel.lua
    ├── percussion_panel.lua
    ├── modulation_panel.lua
    └── probability_panel.lua
```
