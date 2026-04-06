#!/usr/bin/env python3
"""
MDSynth sample processor for 8chip
===================================
Converts chipsynth MD recordings from Files/MDSynth/ into single-cycle
WAVs tuned to C4, blended 80% real / 20% math, saved as 16-bit mono 44100 Hz.
One-shot percussion files (kick, snare, hihat) are trimmed and resampled only.

Run from the workspace root (git repos/8chip/):
    pip install soundfile numpy scipy
    python3 tools/process_mdsynth.py
"""

import os
import re
import sys

import numpy as np
import soundfile as sf
from scipy.signal import resample as scipy_resample

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
INPUT_DIR  = "Files/MDSynth"
OUTPUT_DIR = "com.halebop.8chip.xrnx/data/genesis_samples"

OUT_RATE       = 44100
TARGET_MIDI    = 60        # C4
REAL_WEIGHT    = 0.80      # fraction of extracted real cycle in final blend
MATH_WEIGHT    = 0.20

SILENCE_THRESH = 0.015     # normalized amplitude below which = silence
STABLE_SKIP    = 0.30      # skip first 30% of file so we land in the sustain

# ---------------------------------------------------------------------------
# Note parsing
# ---------------------------------------------------------------------------
_NAME_TO_SEMI = {
    "c": 0,  "c#": 1,  "db": 1,
    "d": 2,  "d#": 3,  "eb": 3,
    "e": 4,
    "f": 5,  "f#": 6,  "gb": 6,
    "g": 7,  "g#": 8,  "ab": 8,
    "a": 9,  "a#": 10, "bb": 10,
    "b": 11,
}

def parse_note(note_str: str) -> int:
    """'c4' / 'f5' / 'c#3' → MIDI note number."""
    note_str = note_str.lower().strip()
    m = re.match(r"([a-g][#b]?)(\d+)$", note_str)
    if not m:
        raise ValueError(f"Unrecognised note: {note_str!r}")
    name, octave = m.group(1), int(m.group(2))
    if name not in _NAME_TO_SEMI:
        raise ValueError(f"Unrecognised note name: {name!r}")
    return _NAME_TO_SEMI[name] + (octave + 1) * 12   # MIDI C4 = 60 (octave 4 → +5*12)

def midi_to_freq(midi: int) -> float:
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))

# ---------------------------------------------------------------------------
# Math waveform generators  (output arrays of length n, range [-1, 1])
# ---------------------------------------------------------------------------
def _sine(n):
    t = np.linspace(0, 1, n, endpoint=False)
    return np.sin(2 * np.pi * t)

def _sawtooth(n):
    t = np.linspace(0, 1, n, endpoint=False)
    return 2.0 * t - 1.0

def _square(n):
    t = np.linspace(0, 1, n, endpoint=False)
    return np.where(t < 0.5, 1.0, -1.0)

def _fm(n, ratio=1.0, mod_index=1.0):
    t = np.linspace(0, 1, n, endpoint=False)
    wave = np.sin(2 * np.pi * t + mod_index * np.sin(2 * np.pi * ratio * t))
    peak = np.max(np.abs(wave))
    return wave / peak if peak > 0 else wave

MATH_WAVEFORMS = {
    "bass":   lambda n: _fm(n, ratio=1.0, mod_index=2.0),
    "epiano": lambda n: _fm(n, ratio=1.0, mod_index=0.8),
    "lead":   lambda n: _sawtooth(n),
    "bell":   lambda n: _fm(n, ratio=3.5, mod_index=1.2),
    "brass":  lambda n: _fm(n, ratio=1.0, mod_index=1.5),
    "clav":   lambda n: _square(n),
    "organ":  lambda n: _fm(n, ratio=2.0, mod_index=0.6),
}

def get_math_wave(patch_name: str, n: int) -> np.ndarray:
    for key, fn in MATH_WAVEFORMS.items():
        if patch_name.lower().startswith(key):
            return fn(n)
    return _sawtooth(n)   # fallback

# ---------------------------------------------------------------------------
# DSP helpers
# ---------------------------------------------------------------------------
def trim_leading_silence(mono: np.ndarray, threshold=SILENCE_THRESH) -> np.ndarray:
    indices = np.where(np.abs(mono) > threshold)[0]
    return mono[indices[0]:] if len(indices) else mono

def find_zero_crossing_down(mono: np.ndarray, start: int) -> int:
    """First sample index ≥ start where signal crosses zero downward."""
    for i in range(start, len(mono) - 1):
        if mono[i] >= 0.0 and mono[i + 1] < 0.0:
            return i + 1
    return start

def extract_clean_cycle(mono: np.ndarray, recorded_freq: float, sr: int) -> np.ndarray:
    """
    Find a representative single cycle in the sustain region.
    Returns a numpy array spanning from one downward ZC to the next.
    """
    skip = int(len(mono) * STABLE_SKIP)
    expected_len = sr / recorded_freq            # fractional samples per cycle

    # Find first downward zero crossing after the stable skip point
    zc1 = find_zero_crossing_down(mono, skip)

    # Look for the next downward ZC in a ± 40 % window around expected period
    lo = zc1 + max(1, int(expected_len * 0.60))
    zc2 = find_zero_crossing_down(mono, lo)

    if zc2 <= zc1 or zc2 >= len(mono):
        # Fallback: just slice round(expected_len) samples starting at zc1
        zc2 = zc1 + max(2, round(expected_len))
        zc2 = min(zc2, len(mono))

    return mono[zc1:zc2]

# ---------------------------------------------------------------------------
# Processing paths
# ---------------------------------------------------------------------------
def target_cycle_len() -> int:
    """Number of samples for one C4 period at 44100 Hz."""
    return round(OUT_RATE / midi_to_freq(TARGET_MIDI))  # ≈ 169

def process_loop(src: str, patch_name: str, recorded_midi: int) -> tuple[np.ndarray, int]:
    """Sustained melodic recording → single-cycle 16-bit mono WAV."""
    audio, sr = sf.read(src, always_2d=True, dtype="float64")
    mono = audio.mean(axis=1)

    mono = trim_leading_silence(mono)
    if len(mono) == 0:
        raise RuntimeError("File is silent after threshold trim.")

    recorded_freq = midi_to_freq(recorded_midi)
    cycle = extract_clean_cycle(mono, recorded_freq, sr)

    tgt_len = target_cycle_len()

    # Resample to C4 period at 44100 Hz
    resampled = scipy_resample(cycle, tgt_len)

    # Normalise real cycle
    peak = np.max(np.abs(resampled))
    if peak > 0:
        resampled /= peak

    # Math waveform
    math_wave = get_math_wave(patch_name, tgt_len)

    # Blend
    blended = REAL_WEIGHT * resampled + MATH_WEIGHT * math_wave

    # Final normalise with headroom
    peak = np.max(np.abs(blended))
    if peak > 0:
        blended = blended / peak * 0.9

    return (blended * 32767).astype(np.int16), OUT_RATE


def process_oneshot(src: str) -> tuple[np.ndarray, int]:
    """Percussion one-shot → trimmed mono 16-bit WAV (no loop, no cycle extraction)."""
    audio, sr = sf.read(src, always_2d=True, dtype="float64")
    mono = audio.mean(axis=1)

    mono = trim_leading_silence(mono)
    if len(mono) == 0:
        raise RuntimeError("File is silent after threshold trim.")

    # Resample from source rate (48000) to 44100 if needed
    if sr != OUT_RATE:
        tgt_len = round(len(mono) * OUT_RATE / sr)
        mono = scipy_resample(mono, tgt_len)

    # Normalise with headroom
    peak = np.max(np.abs(mono))
    if peak > 0:
        mono = mono / peak * 0.9

    return (mono * 32767).astype(np.int16), OUT_RATE

# ---------------------------------------------------------------------------
# File map
# ---------------------------------------------------------------------------
# (stem_without_ext, output_name, recorded_note_str, is_oneshot)
FILE_MAP = [
    ("bass-c4",    "genesis_bass",   "c4",  False),
    ("e-piano-f5", "genesis_epiano", "f5",  False),
    ("lead-c4",    "genesis_lead",   "c4",  False),
    ("bell2-c4",   "genesis_bell",   "c4",  False),
    ("brass2-c4",  "genesis_brass",  "c4",  False),
    ("clav2-c4",   "genesis_clav",   "c4",  False),
    ("organ2-c4",  "genesis_organ",  "c4",  False),
    ("kick-c4",    "genesis_kick",   "c4",  True),
    ("snare-c4",   "genesis_snare",  "c4",  True),
    ("hihat-c4",   "genesis_hihat",  "c4",  True),
]

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    ok_count  = 0
    err_count = 0

    print(f"Output dir : {OUTPUT_DIR}")
    print(f"Target C4  : {midi_to_freq(TARGET_MIDI):.2f} Hz  →  {target_cycle_len()} samples @ {OUT_RATE} Hz\n")

    for stem, out_name, note_str, is_oneshot in FILE_MAP:
        src = os.path.join(INPUT_DIR, stem + ".wav")
        dst = os.path.join(OUTPUT_DIR, out_name + ".wav")

        if not os.path.isfile(src):
            print(f"  SKIP  {stem}.wav  (file not found)")
            err_count += 1
            continue

        label = "one-shot" if is_oneshot else f"loop @ {note_str.upper()}"
        print(f"  {stem}.wav  →  {out_name}.wav  [{label}]")

        try:
            if is_oneshot:
                data, rate = process_oneshot(src)
            else:
                midi   = parse_note(note_str)
                patch  = out_name.removeprefix("genesis_")
                data, rate = process_loop(src, patch, midi)

            sf.write(dst, data, rate, subtype="PCM_16")
            print(f"    ✓  {len(data)} samples written")
            ok_count += 1

        except Exception as exc:
            print(f"    ✗  ERROR: {exc}")
            err_count += 1

    print(f"\nDone: {ok_count} succeeded, {err_count} failed.")
    if err_count:
        sys.exit(1)


if __name__ == "__main__":
    main()
