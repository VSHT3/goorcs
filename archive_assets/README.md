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
| `towers/ballista/gamelab-20261017/` | Approved source designs, provisional assembled trial, previous runtime art and actual game captures | 45 |
| `towers/gold-mine/gamelab-20261017/` | Approved mine, raw/cutout sources, prior procedural PNG and generation provenance | 4 |
| `towers/lightning/gamelab-20261017/` | Approved Lightning, raw/cutout sources, prior procedural PNG and provenance | 4 |
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
- `source-crossbow.png`: preserved source extraction and manual saddle repair before the detail pass. The original PixelLab runtime sprite is now archived at `towers/ballista/gamelab-20261017/previous-runtime.png`; the historical manifest retains its original runtime path and hash.
- `preview.png`: enlarged nearest-neighbor review, not a game screenshot.
- `manifest.json`: source provenance, hashes, layer order, foot anchor `(64, 117)`, roof swivel `(64, 52)`, and export checks.

Run `python3 archive_assets/towers/ballista/manual-master/prepare.py` to reproduce the detailed layer, composite and preview; Pillow is authoring-only. No new AI generation is involved in this final master. Export checks preserve the approved base hash, weapon bounds, binary alpha and unclipped margins.

The [1280×720](towers/ballista/manual-master/godot-review-1280.png) and [1000×720](towers/ballista/manual-master/godot-review-1000.png) captures are direct graphical `PathBoard` renders with both board orientations, adjacent candidates, top-row placement, original towers and enemies. The sprite displayed at 67.2px opaque height on 48px cells. This was an isolated in-memory art preview; collection/save identities, gameplay resources and host-selected target tracking were not changed. `verification.json` ties these captures to the checked master PNG.

## Provisional directional Ballista game trial

[`towers/ballista/gamelab-20261017/`](towers/ballista/gamelab-20261017/) preserves the approved reference-free GameLab SE design and seven approved reference-guided weapon views, exact requests/job IDs, raw/cutout/cleaned sources, previous PixelLab runtime image, and reproducible offline alignment. Master generation reported two credits; the seven alternatives reported fourteen. The subsequent request for a proper generated empty base was rejected for insufficient credits. The creator then explicitly authorized an in-game trial of the existing reconstructed-roof assembly; no additional generation was charged by this integration.

`assembled/prepare.py` builds one fixed base/post, eight weapon layers, SE icon/full composites, a strip and rotation preview on shared 192×192 canvases. Processing uses hard alpha, nearest-neighbor perspective normalization, master-palette matching and small detached-support removal; no finished PNG rotates in its image plane. `assembled/manifest.json` records source hashes, masks, transforms, bolt tips, shared swivel `(96, 84)` and foot `(96, 157)`. The masonry never changes or mirrors during aiming. This is a provisional manually repaired roof, not a newly generated empty base or final geometry/style approval.

Runtime copies use `assets/towers/ballista_base.png`, `ballista_weapon_{n,ne,e,se,s,sw,w,nw}.png` and the full SE `ballista_tower.png`; the reward identity/UID and gameplay rules are unchanged. Host-selected target tracking and immutable release tips are described in the [content pipeline](../docs/content-pipeline.md#directional-weapon-artwork).

[`runtime-proof/directions-runtime.png`](towers/ballista/gamelab-20261017/runtime-proof/directions-runtime.png) is a labelled crop grid of actual host/client main-scene captures, not a generated composite study. Full [1280×720 host combat](towers/ballista/gamelab-20261017/runtime-proof/host-1280.png) and [1000×720 guest view](towers/ballista/gamelab-20261017/runtime-proof/guest-1000.png) show the fixed HUD, top-row clearance and placement. `game-trial.json` records runtime geometry and exercised verification. No native GPU/performance, separate-network internet, new animation, or provider licensing/privacy verification is claimed.

## Approved endpoint idle animations

[`world/idle/idle_comparison.gif`](world/idle/idle_comparison.gif) compares the original portal and crystal with their approved idle loops. Byte-identical PNG sheets are installed in `assets/world/` and enabled in matches and the workshop; this archive preserves the authoring inputs, reproducible exports, and previews.

- Both loops contain sixteen 96×96 frames at 5 fps: a 3.2-second repeating cycle. PNG sheets store one horizontal row; separate transparent GIFs are also included.
- The portal preserves its stone ring, runes, silhouette, and pedestal while the red aperture distorts slightly, small wisps circulate, and existing embers drift. The crystal retains its shape and stone base while facets shimmer and existing sparks twinkle.
- Sprite exports use only their respective source palettes and binary alpha, without blur or antialiasing. Fixed original framing bounds prevent particle changes from shifting sprite scale or anchors.
- [`world/idle/manifest.json`](world/idle/manifest.json) records source/output hashes, runtime sheet paths, timing, frame layout, anchors, and adjacent-frame changes including the loop seam. Sources remain `assets/world/enemy_portal.png` and `assets/world/health_crystal.png`, unchanged.

Regenerate with `python3 archive_assets/world/idle/generate.py` from the project root; authoring was verified with Pillow 12.3.0. This rebuilds archived exports, not the installed runtime copies. Pillow is development-only, not a game dependency. Generation validates source-palette membership, hard alpha, fixed non-magical body pixels, unique frames, and loop boundaries.

Graphical verification played the installed sheets automatically through every frame in the actual workshop and Singleplayer, both match orientations, at 1280×720 and 1000×720, including 2× combat and hide/resume/leave/reopen. Captured frames were inspected; endpoint framing and idle accepted state stayed unchanged. Native clicks still built paths, purchased towers, and started waves. Decoded transparent GIF frames match the PNG sheets exactly.

## Approved Gold Mine still

[`towers/gold-mine/gamelab-20261017/gold_mine_candidate.png`](towers/gold-mine/gamelab-20261017/gold_mine_candidate.png) is the approved runtime Gold Mine, copied byte-for-byte into `assets/towers/gold_mine.png`. GameLab image job `c69e0860-2fc9-4468-b756-1c3f3cd7087e` generated it without reference images, using high quality, a requested 128×128 canvas and 48-color pixel-art processing, at a reported cost of two credits. `generation.json` retains the expanded prompt, settings, job IDs, source hashes, approval and processing. No animation was generated.

The raw chroma image and provider cutout are preserved. The cleaned candidate thresholds cutout alpha at 128 into 0/255 without changing RGB, dimensions or palette; its opaque bounds are `(5, 11)–(125, 115)`. The previous 96×112 procedural mine is preserved as `previous-procedural.png`; the procedural tower tool no longer generates or overwrites Gold Mine. Provider licensing/privacy terms have not been independently verified.

## Approved Lightning still

[`towers/lightning/gamelab-20261017/lightning_candidate.png`](towers/lightning/gamelab-20261017/lightning_candidate.png) is the approved 128×128 GameLab source for base Lightning. Generation job `5abadff5-12ea-47c7-9bd5-798ba48ecec3` used no references, requested high quality and 48-color pixel-art processing, and reported two credits. The cleaned source contains 47 opaque colors and binary alpha; raw output, provider cutout, previous procedural PNG, and exact prompt/settings are preserved beside it.

Runtime `assets/towers/lightning.png` reframes the approved pixels by `(-16, 11)` onto a 128×144 canvas. Every visible source pixel is preserved exactly; only transparent padding changes. This keeps the electric crown at the existing shared muzzle `(48, 19)`, leaving Longer Reach artwork and muzzle geometry unchanged. The base uses a new foot anchor and preserves its previous visible width; the unchanged evolution explicitly retains its old anchor. No animation is generated. Provider licensing/privacy terms have not been independently verified.

## Runtime separation

`.gdignore` keeps this archive out of Godot resource imports. Approved runtime copies live in `../assets/`; the game never loads the archive, GIFs, manifest, or Python authoring script.

The prepared open chest and padded closed reference remain byte-identical to their active runtime PNGs. The original PixelLab Ballista is historical source, not the current runtime match; its exact-match tag has been removed from `assets.json`. Gold Mine's approved cleaned still and Ballista's aligned icon/base/weapon layers have corresponding runtime copies; other archived candidates remain alternatives unless explicitly documented above.
