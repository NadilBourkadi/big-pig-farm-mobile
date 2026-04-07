#!/usr/bin/env python3
"""Generate placeholder SFX WAV files for Big Pig Farm.

Stdlib only — no Pillow, no numpy, no external deps. Idempotent: re-running
overwrites the existing files. Output is deterministic, so committing the
generated WAVs produces meaningful diffs only when the synthesis parameters
actually change.

Usage:
    python3 tools/generate_sfx.py
    python3 tools/generate_sfx.py --output some/other/dir

The 9 SFX correspond 1:1 to HapticManager event methods. Tweak the per-SFX
parameter dicts below to retune individual sounds.
"""

import argparse
import math
import struct
import wave
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = REPO_ROOT / "BigPigFarm" / "Resources" / "Audio"

SAMPLE_RATE = 22_050
MAX_AMP = 0.6  # Headroom: peak ~ -4 dBFS to avoid clipping


# ---------------------------------------------------------------------------
# Waveform primitives
# ---------------------------------------------------------------------------

def sine(freq: float, duration_ms: float) -> list[float]:
    n = int(SAMPLE_RATE * duration_ms / 1000)
    return [math.sin(2 * math.pi * freq * i / SAMPLE_RATE) for i in range(n)]


def square(freq: float, duration_ms: float) -> list[float]:
    n = int(SAMPLE_RATE * duration_ms / 1000)
    return [
        1.0 if math.sin(2 * math.pi * freq * i / SAMPLE_RATE) >= 0 else -1.0
        for i in range(n)
    ]


def triangle(freq: float, duration_ms: float) -> list[float]:
    n = int(SAMPLE_RATE * duration_ms / 1000)
    return [
        (2 / math.pi) * math.asin(math.sin(2 * math.pi * freq * i / SAMPLE_RATE))
        for i in range(n)
    ]


def sine_glide(freq_start: float, freq_end: float, duration_ms: float) -> list[float]:
    """Linear-frequency sine glide using continuous phase accumulation."""
    n = int(SAMPLE_RATE * duration_ms / 1000)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq_start + (freq_end - freq_start) * (i / max(n - 1, 1))
        phase += 2 * math.pi * f / SAMPLE_RATE
        out.append(math.sin(phase))
    return out


def envelope(n_samples: int, attack_ms: float, decay_ms: float) -> list[float]:
    """Linear attack, exponential decay envelope."""
    attack = int(attack_ms * SAMPLE_RATE / 1000)
    out = []
    for i in range(n_samples):
        if i < attack:
            out.append(i / max(attack, 1))
        else:
            t = (i - attack) / SAMPLE_RATE
            out.append(math.exp(-t * 1000.0 / max(decay_ms, 1)))
    return out


def apply_envelope(
    samples: list[float],
    attack_ms: float,
    decay_ms: float,
    amp: float = MAX_AMP,
) -> list[float]:
    env = envelope(len(samples), attack_ms, decay_ms)
    return [s * e * amp for s, e in zip(samples, env)]


def concat(*chunks: list[float]) -> list[float]:
    out: list[float] = []
    for c in chunks:
        out.extend(c)
    return out


# ---------------------------------------------------------------------------
# WAV writer
# ---------------------------------------------------------------------------

def write_wav(path: Path, samples: list[float]) -> None:
    """Clamp, quantize to int16, and write a mono PCM WAV file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for s in samples:
        clamped = max(-1.0, min(1.0, s))
        frames += struct.pack("<h", int(clamped * 32_767))
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(bytes(frames))


# ---------------------------------------------------------------------------
# Per-SFX builders
# ---------------------------------------------------------------------------

def build_pig_selected() -> list[float]:
    """Soft pip — light tap feedback."""
    return apply_envelope(sine(660, 100), 5, 80)


def build_purchase() -> list[float]:
    """Cha-ching ascending — two square-wave tones (C5 → G5)."""
    a = apply_envelope(square(523, 120), 5, 100, amp=0.4)
    b = apply_envelope(square(784, 130), 5, 100, amp=0.4)
    return concat(a, b)


def build_pig_sold() -> list[float]:
    """Coin-like, brighter than purchase — G5 → C6."""
    a = apply_envelope(square(784, 100), 5, 80, amp=0.4)
    b = apply_envelope(square(1046, 120), 5, 100, amp=0.4)
    return concat(a, b)


def build_birth() -> list[float]:
    """Warm bell — sustained triangle wave at G4."""
    return apply_envelope(triangle(392, 600), 10, 500)


def build_pigdex_discovery() -> list[float]:
    """Achievement sparkle — C-E-G major triad arpeggio."""
    return concat(
        apply_envelope(sine(523, 120), 5, 100),
        apply_envelope(sine(659, 120), 5, 100),
        apply_envelope(sine(784, 140), 5, 120),
    )


def build_contract_completed() -> list[float]:
    """Two-note success ding-ding — E5 → B5."""
    return concat(
        apply_envelope(sine(659, 130), 5, 100),
        apply_envelope(sine(988, 150), 5, 130),
    )


def build_error() -> list[float]:
    """Descending buzz — A3 → E3."""
    return concat(
        apply_envelope(square(220, 90), 2, 80, amp=0.4),
        apply_envelope(square(165, 110), 2, 100, amp=0.4),
    )


def build_treat_placed() -> list[float]:
    """Soft pluck — quick A5 tap."""
    return apply_envelope(sine(880, 80), 2, 60)


def build_treat_consumed() -> list[float]:
    """Happy chirp — A5 → E6 glide."""
    return apply_envelope(sine_glide(880, 1320, 180), 2, 140)


SFX_BUILDERS: dict[str, "callable"] = {
    "sfx_pig_selected.wav": build_pig_selected,
    "sfx_purchase.wav": build_purchase,
    "sfx_pig_sold.wav": build_pig_sold,
    "sfx_birth.wav": build_birth,
    "sfx_pigdex_discovery.wav": build_pigdex_discovery,
    "sfx_contract_completed.wav": build_contract_completed,
    "sfx_error.wav": build_error,
    "sfx_treat_placed.wav": build_treat_placed,
    "sfx_treat_consumed.wav": build_treat_consumed,
}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Big Pig Farm SFX WAVs.")
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output directory (default: {DEFAULT_OUTPUT.relative_to(REPO_ROOT)})",
    )
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for filename, builder in SFX_BUILDERS.items():
        write_wav(args.output / filename, builder())
        print(f"  wrote {filename}")
    print(f"\nWrote {len(SFX_BUILDERS)} SFX to {args.output}")


if __name__ == "__main__":
    main()
