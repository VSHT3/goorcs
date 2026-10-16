#!/usr/bin/env python3
"""Reproduce Gorcs' original short SFX using Python 3.10+ standard library only.

Run from any directory: python3 tools/author_sound_effects.py
Writes only assets/audio/sfx/*.wav and its manifest.json. No recordings, external
samples, network, runtime synthesis, dependencies, or changes to the music track.
Recipes combine seeded noise, damped material modes, plucked strings, friction,
and shaped air/body transients. The manifest records recipes and output hashes.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/sfx"
RATE = 48000
TAU = 2.0 * math.pi


def lowpass(signal: list[float], cutoff: float) -> list[float]:
    alpha = 1.0 - math.exp(-TAU * cutoff / RATE)
    value = 0.0
    result = []
    for sample in signal:
        value += alpha * (sample - value)
        result.append(value)
    return result


def band_noise(rng: random.Random, count: int, low: float, high: float) -> list[float]:
    """Broad physical texture without white-noise hiss or subsonic energy."""
    noise = [rng.uniform(-1.0, 1.0) for _ in range(count)]
    upper = lowpass(noise, high)
    lower = lowpass(upper, low)
    return [a - b for a, b in zip(upper, lower)]


class Sound:
    def __init__(self, duration: float, seed: int):
        self.samples = [0.0] * round(duration * RATE)
        self.rng = random.Random(seed)

    def mix(self, signal: list[float], at: float, gain: float = 1.0) -> None:
        start = round(at * RATE)
        for index, value in enumerate(signal):
            destination = start + index
            if destination >= len(self.samples):
                break
            if destination >= 0:
                self.samples[destination] += gain * value

    def noise(self, at: float, duration: float, gain: float, low: float,
              high: float, decay: float, attack: float = 0.0008,
              swell: bool = False) -> None:
        signal = band_noise(self.rng, round(duration * RATE), low, high)
        for index in range(len(signal)):
            t = index / RATE
            envelope = min(1.0, t / attack) * math.exp(-t / decay)
            if swell:
                envelope *= math.sin(math.pi * t / duration) ** 1.4
            envelope *= min(1.0, (duration - t) / 0.008)
            signal[index] *= envelope * gain
        self.mix(signal, at)

    def modes(self, at: float, duration: float, gain: float,
              frequencies: tuple[float, ...], decay: float,
              brightness: float = 0.65, bend: float = 0.0) -> None:
        """Inharmonic, slightly detuned impact modes with a soft excitation edge."""
        count = round(duration * RATE)
        signal = [0.0] * count
        for number, frequency in enumerate(frequencies):
            frequency *= self.rng.uniform(0.985, 1.015)
            phase = self.rng.uniform(-0.18, 0.18)
            amplitude = brightness ** number
            life = decay / (1.0 + number * 0.24)
            for index in range(count):
                t = index / RATE
                # Integral of an exponentially settling frequency offset.
                cycles = frequency * (t + bend * 0.025 * (1.0 - math.exp(-t / 0.025)))
                envelope = min(1.0, t / 0.001) * math.exp(-t / life)
                signal[index] += amplitude * math.sin(TAU * cycles + phase) * envelope
        self.mix(signal, at, gain)

    def pluck(self, at: float, duration: float, frequency: float,
              gain: float, damping: float) -> None:
        """Filtered-noise delay loop, not a sine standing in for a bow string."""
        length = max(2, round(RATE / frequency))
        delay = [self.rng.uniform(-1.0, 1.0) for _ in range(length)]
        average = sum(delay) / length
        delay = [sample - average for sample in delay]
        signal = []
        position = 0
        for index in range(round(duration * RATE)):
            sample = delay[position]
            following = delay[(position + 1) % length]
            delay[position] = damping * (sample + following) * 0.5
            position = (position + 1) % length
            t = index / RATE
            signal.append(sample * min(1.0, t / 0.0006) * math.exp(-t / (duration * 0.30)))
        self.mix(signal, at, gain)

    def air(self, at: float, duration: float, gain: float,
            start_cutoff: float, end_cutoff: float, inward: bool = False) -> None:
        """Moving noise aperture gives portal rushes a direction, without a voice."""
        raw = [self.rng.uniform(-1.0, 1.0) for _ in range(round(duration * RATE))]
        bottom = lowpass(raw, 190.0)
        state = 0.0
        signal = []
        for index, sample in enumerate(raw):
            progress = index / len(raw)
            cutoff = start_cutoff * (end_cutoff / start_cutoff) ** progress
            alpha = 1.0 - math.exp(-TAU * cutoff / RATE)
            state += alpha * (sample - state)
            bell = math.sin(math.pi * progress) ** (1.2 if inward else 0.8)
            shape = (0.35 + 0.65 * progress) if inward else (1.0 - progress * 0.65)
            signal.append((state - bottom[index]) * bell * shape)
        self.mix(signal, at, gain)

    def finish(self, peak: float) -> bytes:
        """Remove DC, taper both edges, set deliberate headroom, quantize to PCM16."""
        # Removing the offset under the same window keeps zero boundaries intact.
        count = len(self.samples)
        weights = []
        for index in range(count):
            entrance = min(1.0, index / (RATE * 0.001))
            exit_ = min(1.0, (count - 1 - index) / (RATE * 0.015))
            weights.append(math.sin(entrance * math.pi / 2.0) ** 2
                           * math.sin(exit_ * math.pi / 2.0) ** 2)
        offset = sum(sample * weight for sample, weight in zip(self.samples, weights)) / sum(weights)
        signal = [(sample - offset) * weight for sample, weight in zip(self.samples, weights)]
        scale = peak / max(abs(sample) for sample in signal)
        # Quiet triangular dither decorrelates quantization from resonant tails.
        pcm = []
        for index, sample in enumerate(signal):
            dither = (self.rng.random() - self.rng.random()) * 0.65
            value = round(sample * scale * 32767.0 + dither)
            pcm.append(value if index not in (0, count - 1) else 0)
        return struct.pack(f"<{count}h", *pcm)


# (duration seconds, linear authored peak, recommended playback dB, variants,
#  material description). Gain recommendations assume a bounded local voice pool;
#  do not increase per-voice gain to compensate for an overcrowded combat mix.
FAMILIES = {
    "bow": (0.215, 0.32, -2.0, 3, "tight string release, wood tick, feather/air flick"),
    "ballista": (0.355, 0.38, -3.0, 3, "heavy latch, tensioned cable, timber recoil and ratchet"),
    "rune": (0.405, 0.29, -4.0, 2, "restrained stone knock with a low inharmonic magic bloom"),
    "explosion": (0.475, 0.36, -3.0, 2, "short low pressure body, gritty breakup, scattered debris"),
    "hit": (0.155, 0.28, -7.0, 3, "dry blunt/arrow contact with a small cloth scrape"),
    "death": (0.370, 0.30, -5.0, 3, "non-vocal breath texture and muted material fall"),
    "bone_death": (0.385, 0.30, -4.0, 2, "dry hollow bone clatter, descending small contacts"),
    "portal": (0.410, 0.29, -4.0, 2, "inward aperture rush, small release and ethereal residue"),
    "crystal": (0.455, 0.32, -3.0, 2, "glass impact with short inharmonic faceted ringing"),
    "purchase": (0.175, 0.21, 0.0, 1, "quiet coin edge/contact acknowledgment"),
    "upgrade": (0.325, 0.25, 0.0, 1, "rising three-part material resonance, affirmative not a fanfare"),
    "reject": (0.105, 0.20, 0.0, 1, "restrained low double latch click, no buzzer or alarm"),
}


def recipe(kind: str, variant: int, duration: float, seed: int) -> Sound:
    s = Sound(duration, seed)
    tuning = (0.95, 1.035, 1.0)[variant - 1]
    if kind == "bow":
        s.noise(0.001, 0.014, 0.80, 1100, 8500, 0.0032)
        s.modes(0.001, 0.075, 0.18, (540 * tuning, 1110, 1840), 0.013)
        s.pluck(0.004, 0.195, 188 * tuning, 0.90, 0.985)
        s.pluck(0.003, 0.125, 393 * tuning, 0.26, 0.980)
        s.noise(0.009, 0.062, 0.38, 1350, 6400, 0.022, 0.003)
    elif kind == "ballista":
        s.noise(0.001, 0.024, 0.95, 650, 5200, 0.007)
        s.modes(0.003, 0.290, 0.40, (93 * tuning, 207, 388, 705), 0.053, 0.58, -0.12)
        s.pluck(0.005, 0.290, 76 * tuning, 0.95, 0.989)
        s.pluck(0.007, 0.220, 153 * tuning, 0.27, 0.982)
        s.noise(0.012, 0.100, 0.50, 240, 2100, 0.032, 0.003)
        for at, gain in ((0.032, 0.30), (0.067, 0.19), (0.110, 0.09)):
            s.modes(at, 0.060, gain, (294 * tuning, 676, 1320), 0.010, 0.55)
            s.noise(at, 0.020, gain * 0.9, 900, 4200, 0.004)
    elif kind == "rune":
        s.noise(0.002, 0.047, 0.70, 280, 2400, 0.011)
        s.modes(0.003, 0.180, 0.24, (148 * tuning, 331, 583), 0.033, 0.62)
        s.modes(0.012, 0.360, 0.20, (236 * tuning, 397 * tuning, 702, 1093), 0.081, 0.67, -0.07)
        s.noise(0.012, 0.195, 0.40, 480, 3600, 0.060, 0.010, True)
    elif kind == "explosion":
        s.noise(0.002, 0.082, 1.45, 75, 3800, 0.019)
        s.noise(0.003, 0.330, 1.65, 35, 600, 0.083, 0.0015)
        s.noise(0.015, 0.255, 0.58, 430, 3400, 0.065, 0.004)
        s.modes(0.003, 0.290, 0.27, (66 * tuning, 107, 173), 0.060, 0.48, -0.35)
        for at, frequency, gain in ((0.058, 740, 0.17), (0.102, 1100, 0.13),
                                    (0.163, 560, 0.08), (0.226, 1390, 0.045)):
            at += s.rng.uniform(-0.007, 0.007)
            s.modes(at, 0.067, gain, (frequency * tuning, frequency * 1.73), 0.009, 0.50)
            s.noise(at, 0.023, gain * 1.2, 1200, 6500, 0.005)
    elif kind == "hit":
        s.noise(0.001, 0.025, 0.90, 450, 6900, 0.005)
        s.modes(0.002, 0.115, 0.38, (143 * tuning, 307, 689), 0.017, 0.50, -0.17)
        s.noise(0.006, 0.105, 0.56, 230, 2600, 0.021, 0.002)
        s.noise(0.024, 0.062, 0.20, 1050, 4900, 0.019, 0.004)
    elif kind == "death":
        # No formant filter, vocal oscillator, speech, or human/animal recording.
        s.noise(0.002, 0.100, 0.65, 160, 2900, 0.026, 0.002)
        s.air(0.011, 0.255, 0.38, 2350 * tuning, 480)
        s.modes(0.006, 0.160, 0.23, (109 * tuning, 237, 461), 0.028, 0.45, -0.16)
        impact = 0.091 + (variant - 1) * 0.009
        s.noise(impact, 0.118, 0.82, 70, 1650, 0.026, 0.001)
        s.modes(impact, 0.190, 0.22, (86 * tuning, 193, 370), 0.036, 0.45)
        s.noise(impact + 0.030, 0.140, 0.32, 500, 3200, 0.040, 0.006)
    elif kind == "bone_death":
        for number, at in enumerate((0.002, 0.033, 0.073, 0.119, 0.174, 0.237, 0.292)):
            if number:
                at += s.rng.uniform(-0.009, 0.009)
            frequency = s.rng.uniform(640, 1160) * tuning
            gain = 0.38 * (1.0 - number * 0.115)
            s.modes(at, 0.080, gain, (frequency, frequency * 1.81, frequency * 2.73),
                    0.013, 0.63)
            s.noise(at, 0.022, gain * 1.5, 820, 6800, 0.0035)
        s.modes(0.005, 0.145, 0.11, (218 * tuning, 490), 0.022, 0.50)
    elif kind == "portal":
        s.air(0.001, 0.250, 1.15, 540, 4400 * tuning, True)
        s.air(0.130, 0.230, 0.62, 3800 * tuning, 520)
        s.modes(0.132, 0.250, 0.095, (183 * tuning, 296, 478, 777), 0.057, 0.70, -0.12)
        s.noise(0.193, 0.055, 0.32, 1100, 5500, 0.013, 0.001)
    elif kind == "crystal":
        s.noise(0.001, 0.019, 0.85, 1800, 10000, 0.003)
        s.modes(0.002, 0.420, 0.30,
                (1120 * tuning, 1787 * tuning, 2959, 4283, 6199), 0.091, 0.69)
        s.modes(0.004, 0.100, 0.12, (253 * tuning, 631), 0.018, 0.45)
        for at, frequency, gain in ((0.036, 2610, 0.045), (0.082, 3700, 0.024)):
            s.modes(at, 0.150, gain, (frequency * tuning, frequency * 1.61), 0.029, 0.53)
    elif kind == "purchase":
        s.noise(0.001, 0.015, 0.55, 1900, 8200, 0.0026)
        s.modes(0.002, 0.156, 0.27, (2280, 3680, 5940), 0.027, 0.62)
        s.modes(0.037, 0.110, 0.105, (1760, 2910, 4730), 0.020, 0.57)
        s.noise(0.037, 0.016, 0.24, 2300, 7500, 0.003)
    elif kind == "upgrade":
        for at, frequency, gain in ((0.002, 610, 0.23), (0.066, 813, 0.25), (0.131, 1025, 0.26)):
            s.modes(at, 0.185, gain, (frequency, frequency * 2.72, frequency * 4.14), 0.042, 0.49)
            s.noise(at, 0.019, 0.26, 1300, 5700, 0.004)
        s.noise(0.040, 0.190, 0.22, 1300, 4500, 0.073, 0.015, True)
    elif kind == "reject":
        for at, gain in ((0.001, 0.38), (0.034, 0.22)):
            s.noise(at, 0.021, gain, 350, 2400, 0.004)
            s.modes(at, 0.060, gain * 0.65, (174, 361, 795), 0.009, 0.42, -0.10)
    else:
        raise ValueError(f"Unknown sound recipe: {kind}")
    return s


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "format_version": 1,
        "authoring": {
            "source": "tools/author_sound_effects.py",
            "command": "python3 tools/author_sound_effects.py",
            "provenance": "Original mathematical sound designs authored for Gorcs; no sampled or copied audio.",
            "inputs": "Seeded standard-library PRNG noise, filtered plucked strings, damped material modes, shaped air transients.",
            "external_dependencies": [],
            "runtime_synthesis": False,
            "ownership": "Original project assets; no third-party audio license or attribution requirements.",
            "reproducibility": "Fixed per-file seeds and recipes; PCM is deterministic on the same Python/libm platform. Cross-platform floating-point implementations may differ by a quantization step.",
        },
        "format": {"encoding": "PCM signed 16-bit little endian", "channels": 1, "sample_rate_hz": RATE},
        "mix_guidance": {
            "recommended_gain_db": "Per-file playback gain before the user's Sound bus; authored peaks already retain at least 8 dB headroom.",
            "pitch": "Small playback pitch variation (about +/-3%) only if desired; variants already differ. Speed changes should follow the game's presentation policy.",
            "polyphony": "Use bounded combat voices and event coalescing for crowds rather than raising gain; keep UI independent and clearly audible.",
            "timing": "Play once per accepted event; do not restart tails or repeat snapshot events. Portal's rush reaches its release near 0.19 seconds.",
        },
        "files": [],
    }
    for family_index, (kind, parameters) in enumerate(FAMILIES.items()):
        duration, peak, gain_db, variants, description = parameters
        for variant in range(1, variants + 1):
            seed = 720241 + family_index * 1009 + variant * 7919
            name = f"{kind}_{variant:02d}.wav"
            sound = recipe(kind, variant, duration, seed)
            pcm = sound.finish(peak)
            path = OUT / name
            with wave.open(str(path), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(RATE)
                output.writeframes(pcm)
            values = struct.unpack(f"<{len(pcm) // 2}h", pcm)
            measured_peak = max(abs(value) for value in values) / 32768.0
            rms = math.sqrt(sum(value * value for value in values) / len(values)) / 32768.0
            manifest["files"].append({
                "file": name,
                "family": kind,
                "variant": variant,
                "seed": seed,
                "duration_seconds": len(values) / RATE,
                "authored_peak_linear": peak,
                "measured_peak_dbfs": round(20.0 * math.log10(measured_peak), 3),
                "measured_rms_dbfs": round(20.0 * math.log10(rms), 3),
                "mean_pcm_lsb": round(sum(values) / len(values), 5),
                "recommended_gain_db": gain_db,
                "recipe": description,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            })
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Authored {len(manifest['files'])} original mono 48 kHz PCM16 SFX in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
