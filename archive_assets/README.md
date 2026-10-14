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

Numbers such as `0001` identify variants, not animation frames. Treasure and orc variants with the same number are not necessarily related. Only the prepared pair has recorded derivation links.

## Tags and provenance

`assets.json` is the portable, searchable catalog. Every image records:

- Relative archive path and original Downloads filename/path.
- Subject, pose, asset role, material, dimensions, transparency, and processing tags.
- Pixel dimensions, image mode, alpha bounds, and SHA-256.
- Source information where known, prepared-frame derivation links, and byte-identical runtime matches.

The same tags are attached to each PNG as the comma-separated `user.xdg.tags` extended attribute. File-manager indexing/support varies; copies, exports, and Git can discard these attributes. Use the JSON catalog as the source of truth.

Example tag search, if `jq` is installed, from the project root:

```sh
jq -r '.assets[] | select(.tags | index("open")) | .path' archive_assets/assets.json
```

Useful tags include `chest`, `treasure`, `orc`, `closed`, `open`, `variant`, `prepared`, `reference`, `sprite-sheet`, `ballista`, `source-original`, and `runtime-exact-match`.

Source URLs and license terms were not supplied and are explicitly unspecified, not assumed cleared for redistribution. PixelLab provenance is recorded only where filenames or the documented project workflow identify it.

## Runtime separation

`.gdignore` keeps this archive out of Godot resource imports. The game's active assets remain in `../assets/`; no runtime references were changed.

The ballista original, prepared open chest, and padded closed reference are byte-identical to the corresponding active game PNGs. Other candidates are archived alternatives, not approved runtime replacements. See [the pixel-art workflow](../docs/development.md#pixel-art-asset-workflow) before replacing game art.
