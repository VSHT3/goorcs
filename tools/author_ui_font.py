#!/usr/bin/env python3
"""Build Pixelify's letter face for the UI fallback (requires fonttools)."""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
font = TTFont(ROOT / "assets/fonts/PixelifySans.ttf", recalcTimestamp=False)
options = subset.Options()
options.name_IDs = ["*"]
options.name_legacy = True
options.name_languages = ["*"]
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=set(font.getBestCmap()) - set(range(ord("0"), ord("9") + 1)))
subsetter.subset(font)
font.save(ROOT / "assets/fonts/PixelifySans-letters.ttf")
