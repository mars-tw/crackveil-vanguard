#!/usr/bin/env python3
"""Generate tiny placeholder WAV effects for Crackveil Vanguard."""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path


SAMPLE_RATE = 22050
MAX_AMPLITUDE = 32767
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "audio"


def envelope(index: int, total: int, attack: float = 0.08, release: float = 0.42) -> float:
    if total <= 1:
        return 0.0
    t = index / float(total - 1)
    if t < attack:
        return t / max(attack, 0.001)
    if t > 1.0 - release:
        return max(0.0, (1.0 - t) / max(release, 0.001))
    return 1.0


def sine(freq: float, t: float) -> float:
    return math.sin(math.tau * freq * t)


def square(freq: float, t: float) -> float:
    return 1.0 if sine(freq, t) >= 0.0 else -1.0


def write_wav(name: str, duration: float, sample_func) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sample_count = max(1, int(SAMPLE_RATE * duration))
    output = OUTPUT_DIR / f"{name}.wav"
    with wave.open(str(output), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for index in range(sample_count):
            t = index / SAMPLE_RATE
            value = max(-1.0, min(1.0, sample_func(index, sample_count, t)))
            sample = int(value * MAX_AMPLITUDE)
            frames.extend(sample.to_bytes(2, "little", signed=True))
        wav_file.writeframes(frames)


def main() -> None:
    random.seed(917)

    write_wav(
        "fire",
        0.075,
        lambda i, n, t: 0.18
        * envelope(i, n, 0.05, 0.7)
        * (square(820.0 - 1800.0 * t, t) * 0.72 + sine(1640.0 - 2200.0 * t, t) * 0.28),
    )
    write_wav(
        "hit",
        0.055,
        lambda i, n, t: 0.16
        * envelope(i, n, 0.02, 0.8)
        * (random.uniform(-1.0, 1.0) * 0.58 + sine(180.0, t) * 0.42),
    )
    write_wav(
        "upgrade",
        0.22,
        lambda i, n, t: 0.19
        * envelope(i, n, 0.04, 0.36)
        * (sine(520.0, t) * 0.45 + sine(780.0, t) * 0.35 + sine(1040.0, t) * 0.20),
    )
    write_wav(
        "contract",
        0.24,
        lambda i, n, t: 0.2
        * envelope(i, n, 0.05, 0.45)
        * (sine(260.0 + 520.0 * t, t) * 0.5 + sine(390.0 + 780.0 * t, t) * 0.5),
    )
    write_wav(
        "elite",
        0.34,
        lambda i, n, t: 0.22
        * envelope(i, n, 0.03, 0.5)
        * (sine(110.0, t) * 0.42 + square(165.0, t) * 0.34 + sine(440.0, t) * 0.24),
    )
    write_wav(
        "death",
        0.42,
        lambda i, n, t: 0.24
        * envelope(i, n, 0.02, 0.64)
        * (sine(220.0 - 140.0 * t, t) * 0.56 + random.uniform(-1.0, 1.0) * 0.44),
    )
    write_wav(
        "pulse",
        0.19,
        lambda i, n, t: 0.22
        * envelope(i, n, 0.025, 0.48)
        * (
            sine(180.0 + 880.0 * t, t) * 0.38
            + sine(360.0 + 1240.0 * t, t) * 0.34
            + random.uniform(-1.0, 1.0) * 0.28
        ),
    )
    write_wav(
        "pickup",
        0.08,
        lambda i, n, t: 0.18
        * envelope(i, n, 0.03, 0.52)
        * (sine(960.0 + 340.0 * t, t) * 0.64 + sine(1440.0 + 480.0 * t, t) * 0.36),
    )
    write_wav(
        "kill_thump",
        0.16,
        lambda i, n, t: 0.26
        * envelope(i, n, 0.015, 0.72)
        * (
            sine(68.0 - 22.0 * t, t) * 0.62
            + sine(124.0 - 40.0 * t, t) * 0.22
            + random.uniform(-1.0, 1.0) * 0.16
        ),
    )
    write_wav(
        "combo",
        0.24,
        lambda i, n, t: 0.22
        * envelope(i, n, 0.03, 0.42)
        * (
            sine(180.0 + 520.0 * t, t) * 0.32
            + sine(360.0 + 940.0 * t, t) * 0.34
            + sine(720.0 + 1180.0 * t, t) * 0.22
            + random.uniform(-1.0, 1.0) * 0.12
        ),
    )
    write_wav(
        "footstep",
        0.045,
        lambda i, n, t: 0.13
        * envelope(i, n, 0.025, 0.78)
        * (
            sine(92.0 - 28.0 * t, t) * 0.34
            + sine(176.0 - 56.0 * t, t) * 0.18
            + random.uniform(-1.0, 1.0) * 0.48
        ),
    )

    for wav_path in sorted(OUTPUT_DIR.glob("*.wav")):
        print(f"{wav_path.name}: {wav_path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
