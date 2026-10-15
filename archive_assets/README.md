# Pixel-art asset archive

40 PNGs moved from `~/Downloads` and `~/Downloads/goorcs_temp` into the existing Gorcs project. Image bytes are unchanged; filenames are normalized. `assets.json` preserves each original filename and source path.

## Organization

| Folder | Contents | Images |
| --- | --- | ---: |
| `chests/variants/treasure/closed/` | Downloaded treasure-chest candidates | 16 |
| `chests/variants/orc/closed/` | Orc-chest working variants from `goorcs_temp` | 16 |
| `chests/variants/orc/open/` | Downloaded open-pose candidates | 4 |
| `chests/prepared/` | Aligned open frame and padded closed reference | 2 |
| `chests/source_sheets/` | Original 4×4 treasure-chest sheet | 1 |
| `towers/ballista/source/` | Original PixelLab ballista sprite | 1 |
| `towers/ballista/manual-master/` | Manual starting pose, source layers, preview and rendered checks | 7 |
| `world/idle/` | Approved portal/crystal idle sheets and animated previews | 5 |

Numbers such as `0001` identify downloaded variants, not animation frames. Treasure and orc variants with the same number are not necessarily related. Only the prepared chest pair has derivation links in `assets.json`; the endpoint and manual-ballista manifests record their own source links.

## Tags and provenance

`assets.json` is the portable, searchable catalog for the downloaded artwork. Each downloaded image records:

- Relative archive path and original Downloads filename/path.
- Subject, pose, asset role, material, dimensions, transparency, and processing tags.
- Pixel dimensions, image mode, alpha bounds, and SHA-256.
- Source information where known, prepared-frame derivation links, and byte-identical runtime matches.

The same tags are attached to each downloaded PNG as the comma-separated `user.xdg.tags` extended attribute. File-manager indexing/support varies; copies, exports, and Git can discard these attributes. Use the JSON catalog as the source of truth.

Example tag search, if `jq` is installed, from the project root:

```sh
jq -r '.assets[] | select(.tags | index("open")) | .path' archive_assets/assets.json
```

Useful tags include `chest`, `treasure`, `orc`, `closed`, `open`, `variant`, `prepared`, `reference`, `sprite-sheet`, `ballista`, `source-original`, and `runtime-exact-match`.

Source URLs and license terms were not supplied and are explicitly unspecified, not assumed cleared for redistribution. PixelLab provenance is recorded only where filenames or the documented project workflow identify it.

## Manual ballista starting image

[`towers/ballista/manual-master/ballista.png`](towers/ballista/manual-master/ballista.png) is the creator-requested **single starting pose for PixelLab rotations**, not a runtime replacement or an approved eight-direction set. The taller hand-pixeled foundation has projecting corner piers, a recessed stone wall, a thick roof cap and a stepped footing. The retained crossbow gains native-pixel steel bindings, stock highlights, winding-mechanism detail and rivets without enlargement.

- `ballista.png`: complete transparent 128×128 starting image, facing south-east.
- `base.png` and `crossbow.png`: aligned full-canvas layers. Rotate only the weapon if the masonry must remain identical; keep the shared canvas and anchors.
- `source-crossbow.png`: preserved source extraction and manual saddle repair before the detail pass. The original PixelLab sprite remains unchanged in `assets/towers/ballista_tower.png`.
- `preview.png`: enlarged nearest-neighbor review, not a game screenshot.
- `manifest.json`: source provenance, hashes, layer order, foot anchor `(64, 117)`, roof swivel `(64, 52)`, and export checks.

Run `python3 archive_assets/towers/ballista/manual-master/prepare.py` to reproduce the detailed layer, composite and preview; Pillow is authoring-only. No new AI generation is involved in this final master. Export checks preserve the approved base hash, weapon bounds, binary alpha and unclipped margins.

The [1280×720](towers/ballista/manual-master/godot-review-1280.png) and [1000×720](towers/ballista/manual-master/godot-review-1000.png) captures are direct graphical `PathBoard` renders with both board orientations, adjacent candidates, top-row placement, original towers and enemies. The sprite displayed at 67.2px opaque height on 48px cells. This was an isolated in-memory art preview; collection/save identities, gameplay resources and host-selected target tracking were not changed. `verification.json` ties these captures to the checked master PNG.

## Approved endpoint idle animations

[`world/idle/idle_comparison.gif`](world/idle/idle_comparison.gif) compares the original portal and crystal with their approved idle loops. Byte-identical PNG sheets are installed in `assets/world/` and enabled in matches and the workshop; this archive preserves the authoring inputs, reproducible exports, and previews.

- Both loops contain sixteen 96×96 frames at 5 fps: a 3.2-second repeating cycle. PNG sheets store one horizontal row; separate transparent GIFs are also included.
- The portal preserves its stone ring, runes, silhouette, and pedestal while the red aperture distorts slightly, small wisps circulate, and existing embers drift. The crystal retains its shape and stone base while facets shimmer and existing sparks twinkle.
- Sprite exports use only their respective source palettes and binary alpha, without blur or antialiasing. Fixed original framing bounds prevent particle changes from shifting sprite scale or anchors.
- [`world/idle/manifest.json`](world/idle/manifest.json) records source/output hashes, runtime sheet paths, timing, frame layout, anchors, and adjacent-frame changes including the loop seam. Sources remain `assets/world/enemy_portal.png` and `assets/world/health_crystal.png`, unchanged.

Regenerate with `python3 archive_assets/world/idle/generate.py` from the project root; authoring was verified with Pillow 12.3.0. This rebuilds archived exports, not the installed runtime copies. Pillow is development-only, not a game dependency. Generation validates source-palette membership, hard alpha, fixed non-magical body pixels, unique frames, and loop boundaries.

Graphical verification played the installed sheets automatically through every frame in the actual workshop and Singleplayer, both match orientations, at 1280×720 and 1000×720, including 2× combat and hide/resume/leave/reopen. Captured frames were inspected; endpoint framing and idle accepted state stayed unchanged. Native clicks still built paths, purchased towers, and started waves. Decoded transparent GIF frames match the PNG sheets exactly.

## Runtime separation

`.gdignore` keeps this archive out of Godot resource imports. Approved runtime copies live in `../assets/`; the game never loads the archive, GIFs, manifest, or Python authoring script.

The ballista original, prepared open chest, and padded closed reference are byte-identical to the corresponding active game PNGs. Other candidates are archived alternatives, not approved runtime replacements. See [the pixel-art workflow](../docs/development.md#pixel-art-asset-workflow) before replacing game art.
