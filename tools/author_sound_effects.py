#!/usr/bin/env python3
"""Reproduce Gorcs' short SFX using Python 3.10+ standard library only.

Run from any directory: python3 tools/author_sound_effects.py
Writes assets/audio/sfx/*.wav and its manifest.json, leaving identical WAVs alone.
Original recipes combine seeded noise, damped modes, strings and transients.
The intro roar instead edits a retained CC0 vocal recording: provenance, original
compressed source and decoded PCM are in tools/audio_sources/intro_roar/.
No network, runtime synthesis, dependencies, or changes to the music track.
"""
from __future__ import annotations

import hashlib
import json
import io
import math
from pathlib import Path
import random
import struct
import wave


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/sfx"
RATE = 48000
TAU = 2.0 * math.pi
ROAR_SOURCE = ROOT / "tools/audio_sources/intro_roar"


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


# (first-variant seed, duration seconds, linear authored peak, recommended
#  playback dB, variants, material description). Seeds are explicit so adding or
#  reordering a family never rewrites another family's authored audio. Gain
#  recommendations assume a bounded local voice pool; do not increase per-voice
#  gain to compensate for an overcrowded combat mix.
FAMILIES = {
    "bow": (728160, 0.215, 0.32, -2.0, 3, "tight string release, wood tick, feather/air flick"),
    "ballista": (729169, 0.355, 0.38, -3.0, 3, "heavy latch, tensioned cable, timber recoil and ratchet"),
    "rune": (730178, 0.405, 0.29, -4.0, 2, "restrained stone knock with a low inharmonic magic bloom"),
    "explosion": (731187, 0.475, 0.36, -3.0, 2, "short low pressure body, gritty breakup, scattered debris"),
    "hit": (732196, 0.155, 0.28, -7.0, 3, "dry blunt/arrow contact with a small cloth scrape"),
    "death": (733205, 0.370, 0.30, -5.0, 3, "non-vocal breath texture and muted material fall"),
    "bone_death": (734214, 0.385, 0.30, -4.0, 2, "dry hollow bone clatter, descending small contacts"),
    "portal": (735223, 0.410, 0.29, -4.0, 2, "inward aperture rush, small release and ethereal residue"),
    "crystal": (736232, 0.455, 0.32, -3.0, 2, "glass impact with short inharmonic faceted ringing"),
    "purchase": (737241, 0.175, 0.21, 0.0, 1, "quiet coin edge/contact acknowledgment"),
    "upgrade": (738250, 0.325, 0.25, 0.0, 1, "rising three-part material resonance, affirmative not a fanfare"),
    "reject": (739259, 0.105, 0.20, 0.0, 1, "restrained low double latch click, no buzzer or alarm"),
    "menu_click": (740268, 0.115, 0.16, 0.0, 1, "muted single woody clack with a short dull metal edge; no pitched reward or rejection"),
    "troll_stomp": (741277, 0.590, 0.42, -4.0, 2, "massive low earth thud, stone grit and settling dust"),
    "club_impact": (742286, 0.455, 0.39, -4.0, 2, "splintering timber club crack with hollow wooden body"),
    "cannon": (743295, 0.610, 0.42, -4.0, 2, "iron cannon report, deep pressure and recoiling metal"),
    "tower_stun": (744304, 0.520, 0.28, -7.0, 2, "descending cartoon bell wobble with a dry contact"),
    "machine_gear": (745313, 0.660, 0.30, -7.0, 2, "irregular iron ratchet and loaded mechanical creak"),
    "machine_jump": (746322, 0.680, 0.35, -5.0, 2, "compressed spring release and heavy lifting air rush"),
    "machine_door": (747331, 0.570, 0.30, -6.0, 2, "heavy hinged timber doors opening with iron latch clanks"),
    "sale": (741277, 0.310, 0.23, 0.0, 1, "three bright falling coin contacts into a muted cash drawer"),
    "rarity_tick": (748340, 0.065, 0.18, -5.0, 1, "short dry ratchet tooth with a muted metallic edge for reel crossings"),
    "rarity_reveal": (749349, 0.850, 0.28, -3.0, 1, "latch landing followed by a rising resonant crystal chord"),
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
    elif kind == "sale":
        for at, frequency, gain in ((0.002, 3100, 0.30), (0.052, 2540, 0.25), (0.112, 1980, 0.19)):
            s.noise(at, 0.013, gain, 1900, 8200, 0.0026)
            s.modes(at, 0.160, gain, (frequency, frequency * 1.61, frequency * 2.60), 0.033, 0.61)
        s.noise(0.163, 0.100, 0.26, 160, 1600, 0.017, 0.002)
        s.modes(0.163, 0.120, 0.17, (184, 397, 811), 0.020, 0.42)
    elif kind == "upgrade":
        for at, frequency, gain in ((0.002, 610, 0.23), (0.066, 813, 0.25), (0.131, 1025, 0.26)):
            s.modes(at, 0.185, gain, (frequency, frequency * 2.72, frequency * 4.14), 0.042, 0.49)
            s.noise(at, 0.019, 0.26, 1300, 5700, 0.004)
        s.noise(0.040, 0.190, 0.22, 1300, 4500, 0.073, 0.015, True)
    elif kind == "reject":
        for at, gain in ((0.001, 0.38), (0.034, 0.22)):
            s.noise(at, 0.021, gain, 350, 2400, 0.004)
            s.modes(at, 0.060, gain * 0.65, (174, 361, 795), 0.009, 0.42, -0.10)
    elif kind == "menu_click":
        s.noise(0.001, 0.026, 0.48, 320, 3200, 0.005, 0.0015)
        s.modes(0.002, 0.102, 0.36, (286, 557, 1043), 0.014, 0.46, -0.04)
        s.modes(0.003, 0.045, 0.055, (1370, 2310, 3680), 0.005, 0.37)
        s.noise(0.006, 0.065, 0.20, 140, 1350, 0.012, 0.002)
    elif kind == "troll_stomp":
        s.modes(0.003, 0.520, 0.65, (43 * tuning, 71, 109, 163), 0.110, 0.54, -0.3)
        s.noise(0.002, 0.370, 2.1, 32, 520, 0.086)
        s.noise(0.012, 0.450, 0.90, 210, 2400, 0.095, 0.006)
        for at in (0.055, 0.110, 0.186):
            s.noise(at, 0.065, 0.28, 650, 3900, 0.014)
    elif kind == "club_impact":
        s.noise(0.002, 0.050, 1.25, 350, 6800, 0.009)
        s.modes(0.003, 0.380, 0.58, (79 * tuning, 183, 377, 693), 0.065, 0.61, -0.17)
        s.pluck(0.006, 0.310, 92 * tuning, 0.80, 0.972)
        s.noise(0.022, 0.270, 0.80, 160, 2100, 0.066)
    elif kind == "cannon":
        s.noise(0.002, 0.095, 2.0, 70, 5600, 0.019)
        s.noise(0.004, 0.500, 2.2, 28, 710, 0.120)
        s.modes(0.005, 0.540, 0.43, (48 * tuning, 97, 203, 477), 0.095, 0.48, -0.28)
        for at in (0.060, 0.107, 0.180):
            s.modes(at, 0.180, 0.16, (370 * tuning, 883, 1657), 0.029, 0.58)
    elif kind == "tower_stun":
        s.noise(0.002, 0.036, 0.50, 700, 4400, 0.008)
        for at, frequency in ((0.005, 930), (0.125, 770), (0.253, 640)):
            s.modes(at, 0.260, 0.26, (frequency * tuning, frequency * 1.91, frequency * 3.13), 0.065, 0.48, -0.14)
    elif kind == "machine_gear":
        for index, at in enumerate((0.003, 0.061, 0.129, 0.212, 0.317, 0.447)):
            s.noise(at, 0.050, 0.58, 280, 3600, 0.013)
            s.modes(at, 0.170, 0.22, ((133 + index * 17) * tuning, 437, 933), 0.037, 0.58, 0.08)
        s.noise(0.030, 0.580, 0.42, 90, 980, 0.260, 0.030, True)
    elif kind == "machine_jump":
        s.pluck(0.004, 0.420, 54 * tuning, 1.1, 0.991)
        s.modes(0.005, 0.480, 0.35, (62 * tuning, 137, 307, 683), 0.090, 0.55, 0.32)
        s.air(0.030, 0.580, 1.5, 380, 2900 * tuning, True)
        s.noise(0.012, 0.085, 0.95, 150, 2200, 0.019)
    elif kind == "machine_door":
        s.modes(0.004, 0.500, 0.39, (86 * tuning, 193, 418, 911), 0.100, 0.59, -0.12)
        s.noise(0.008, 0.450, 0.70, 130, 1600, 0.180, 0.010, True)
        for at in (0.010, 0.090, 0.360):
            s.modes(at, 0.180, 0.31, (294 * tuning, 677, 1397), 0.033, 0.56)
            s.noise(at, 0.035, 0.55, 570, 4200, 0.007)
    elif kind == "rarity_tick":
        s.noise(0.001, 0.025, 0.70, 700, 4700, 0.004)
        s.modes(0.001, 0.055, 0.30, (610, 1370, 2410), 0.009, 0.45)
    elif kind == "rarity_reveal":
        s.noise(0.002, 0.060, 0.55, 180, 2400, 0.012)
        s.modes(0.002, 0.240, 0.40, (164, 337, 691), 0.055, 0.50)
        for at, frequency in ((0.025, 523.25), (0.085, 659.25), (0.145, 783.99), (0.205, 1046.50)):
            s.modes(at, 0.600, 0.13, (frequency, frequency * 2.01, frequency * 3.98), 0.150, 0.32)
    else:
        raise ValueError(f"Unknown sound recipe: {kind}")
    return s


def recorded_roar() -> tuple[bytes, dict]:
    """Edit an actual recorded voice, never synthesize a vocal substitute."""
    provenance = json.loads((ROAR_SOURCE / "source.json").read_text(encoding="utf-8"))
    source = ROAR_SOURCE / "roar_02_decoded.wav"
    if hashlib.sha256(source.read_bytes()).hexdigest() != provenance["decoded_pcm"]["sha256"]:
        raise ValueError("Retained intro roar PCM does not match its source provenance")
    with wave.open(str(source), "rb") as recording:
        if (recording.getnchannels(), recording.getsampwidth(), recording.getframerate()) != (1, 2, RATE):
            raise ValueError("Intro roar source must be mono PCM16 at 48 kHz")
        recording.setpos(round(0.070 * RATE))
        raw = recording.readframes(round(0.780 * RATE))
    values = struct.unpack(f"<{len(raw) // 2}h", raw)
    if len(values) != round(0.780 * RATE):
        raise ValueError("Intro roar source is shorter than the recorded edit")
    # Remove rumble, soften the recording's bright edge; preserve vocal timing/pitch.
    signal = lowpass([value / 32768.0 for value in values], 6000.0)
    rumble = lowpass(signal, 80.0)
    sound = Sound(0.780, 918307)
    sound.samples = [sample - low for sample, low in zip(signal, rumble)]
    return sound.finish(0.32), provenance


def write_wave(path: Path, pcm: bytes) -> None:
    """Do not touch existing effects when their deterministic bytes are unchanged."""
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)
    data = buffer.getvalue()
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def measurements(pcm: bytes) -> dict:
    values = struct.unpack(f"<{len(pcm) // 2}h", pcm)
    measured_peak = max(abs(value) for value in values) / 32768.0
    rms = math.sqrt(sum(value * value for value in values) / len(values)) / 32768.0
    return {
        "duration_seconds": len(values) / RATE,
        "measured_peak_dbfs": round(20.0 * math.log10(measured_peak), 3),
        "measured_rms_dbfs": round(20.0 * math.log10(rms), 3),
        "mean_pcm_lsb": round(sum(values) / len(values), 5),
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "format_version": 2,
        "authoring": {
            "source": "tools/author_sound_effects.py",
            "command": "python3 tools/author_sound_effects.py",
            "provenance": "Original mathematical designs except intro_roar.wav, an edit of rubberduck's CC0 recorded vocal; see third_party_sources.",
            "inputs": "Seeded standard-library PRNG noise, filtered plucked strings, damped material modes, shaped air transients; retained decoded third-party PCM for intro_roar.wav only.",
            "external_dependencies": [],
            "runtime_synthesis": False,
            "ownership": "Original recipe assets have no third-party requirements. intro_roar.wav remains a third-party CC0 derivative, not an original project recording.",
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
    for kind, parameters in FAMILIES.items():
        first_seed, duration, peak, gain_db, variants, description = parameters
        for variant in range(1, variants + 1):
            seed = first_seed + (variant - 1) * 7919
            name = "menu_click.wav" if kind == "menu_click" else f"{kind}_{variant:02d}.wav"
            sound = recipe(kind, variant, duration, seed)
            pcm = sound.finish(peak)
            path = OUT / name
            write_wave(path, pcm)
            manifest["files"].append({
                "file": name,
                "family": kind,
                "variant": variant,
                "seed": seed,
                **measurements(pcm),
                "authored_peak_linear": peak,
                "recommended_gain_db": gain_db,
                "recipe": description,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            })
    pcm, provenance = recorded_roar()
    path = OUT / "intro_roar.wav"
    write_wave(path, pcm)
    manifest["third_party_sources"] = {"intro_roar": provenance}
    manifest["files"].append({
        "file": "intro_roar.wav",
        "family": "intro_roar",
        "origin": "third_party_recording",
        "source": "intro_roar",
        "authored_peak_linear": 0.32,
        **measurements(pcm),
        "recommended_gain_db": 0.0,
        "recipe": "Recorded CC0 roar_02; source trim 0.070–0.850s, mono 48 kHz PCM16; one-pole lowpass 6000 Hz minus 80 Hz lowpass, weighted DC removal, 1 ms sin² entrance/15 ms sin² exit, peak 0.32, triangular dither seed 918307. No pitch/time stretch or synthesized voice.",
        "vocal_attack_seconds": 0.03,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    })
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Authored {len(manifest['files']) - 1} original SFX and 1 CC0 recorded vocal edit in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
