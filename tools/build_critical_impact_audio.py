"""Rebuild the project's short original critical-hit impact (no third-party audio)."""
import math
from pathlib import Path
import random
import struct
import wave

rate = 44100
rng = random.Random(35035)
samples = []
phase = 0.0
for index in range(round(rate * 0.18)):
    t = index / rate
    phase += 2 * math.pi * (62 + 145 * math.exp(-t * 35)) / rate
    body = math.sin(phase) * math.exp(-t * 28) * 0.64
    crack = rng.uniform(-1, 1) * math.exp(-t * 90) * 0.36
    metal = (math.sin(2 * math.pi * 1640 * t) + 0.35 * math.sin(2 * math.pi * 2870 * t)) * math.exp(-t * 44) * 0.10
    attack = min(1, t / 0.0015)
    fade = min(1, (0.18 - t) / 0.014)
    samples.append((body + crack + metal) * attack * fade)
peak = max(abs(value) for value in samples)
payload = b"".join(struct.pack("<h", round(value / peak * 0.72 * 32767)) for value in samples)
output = Path(__file__).resolve().parents[1] / "assets/audio/critical_impact.wav"
with wave.open(str(output), "wb") as stream:
    stream.setnchannels(1)
    stream.setsampwidth(2)
    stream.setframerate(rate)
    stream.writeframes(payload)
print(f"CRITICAL_AUDIO_BUILT frames={len(samples)} rate={rate} peak=0.72 seconds=.18")
