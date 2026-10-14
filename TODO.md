# TODO — Match visual direction

## Status and reference

- [x] Creator approved the direction of the board composition study on 2026-10-14.
- [x] Implement the approved presentation in the running game using existing artwork; coherent replacements remain approval-gated below.

![Approved board composition study](docs/visual-reference/board-target.png)

This is a **static composition study, not an implemented game screenshot**. Approval covers the overall look: stronger proportions, more grounded sprites, layered terrain/path materials, and quieter highlights. It does not mean every existing sprite is final or that the exact camera angle has been settled. The study retains the supplied HUD, two owned Rune towers, four owned Grunts, one opponent Grunt, and the bent-route concept; no extra combat population was added to make it look fuller.

The portable reference is copied unchanged from `~/Pictures/Gorcs-PixelArt/board-readability-pass/board-target.png`. The original study directory also retains its detail image and `provenance.json`. Reference artwork is excluded from Godot imports and is not a runtime asset.

## Recommended viewing angle

**Use a shared elevated three-quarter top-down view for buildings and enemies.** This is the working recommendation, to validate with an actual-size asset lineup before another sprite batch.

- Keep the existing axis-aligned square grid and 2D gameplay camera. This is a sprite-art direction, not a conversion to a diamond/isometric map or a 3D camera.
- Show enough of a tower's top and sides to communicate height, while keeping its base readable on the ground.
- Show an enemy's head/shoulders from above while retaining a readable face, torso, and legs. Avoid a pure side-view platformer pose.
- Share camera elevation, ground plane, light direction, shadow treatment, outline weight, and apparent pixel density. Matching angle does **not** require identical facing: towers may retain a fixed readable three-quarter pose while enemies face along their route.
- Small readability cheats are acceptable. Mixing genuinely side-on towers with strict overhead enemies is not the target; they should look as if they occupy the same world.
- Do not switch to strict bird's-eye sprites unless that alternative is explicitly chosen after comparison. It sacrifices the faces and tall building silhouettes that work in the approved study.

## Approved presentation goals

- **Proportions:** towers read as substantial structures, not inventory icons beside enemies. Ground sprites by their feet/base rather than equal square image canvases. Grunt, Runner, and Brute remain distinguishable by silhouette and mass. The study's tower/Grunt sizing is a starting visual ratio, not a hardcoded global pixel size.
- **Density:** improve visual weight, material variation, and framing instead of adding enemies or towers to hide empty space. Preserve buildable-ground readability. Larger decoration belongs outside playable cells; cosmetic texture must not imply new blocked cells.
- **Ground and path:** replace the uniform dark field and flat bright path ribbon with restrained grass/soil variation, continuous stonework, subtle edges, and contact shadows. Corners, branches, portals, and bases must remain legible.
- **Highlights:** no permanent boxes around every tower and no idle combat hover square when there is no placement action. Give the selected tower contextual feedback; keep legal placement and range feedback discoverable. Show enemy health when damaged rather than drawing bright full bars over the whole stream. Make attack feedback brief, local, and subordinate to the units instead of overlapping gold rings that resemble persistent range indicators.
- **Art consistency:** the current Rune and Grunt still differ in perspective/detail density. Increasing size alone does not make them a matched set. Evaluate all art together on the board, not as isolated enlarged PNGs.

## Implementation order

### 1. Presentation pass using existing artwork

- [x] Establish resource-driven visual sizing and base/foot anchors for towers and enemies; avoid a one-size-fits-all canvas fit.
- [x] Apply the approved tower/enemy hierarchy without changing tower footprints, placement cells, hit rules, range, or path legality.
- [x] Add restrained terrain/path materials and grounding shadows; retain continuous path junctions and readable endpoints.
- [x] Remove always-on tower rectangles and irrelevant idle combat hover outlines; preserve explicit selection, placement legality, and selected range feedback.
- [x] Limit routine health-bar clutter and replace overpowering attack highlights with clearer transient effects. Keep damage/AoE information understandable.
- [x] Keep the fixed HUD, compact-width usability, local camera scouting, and opponent read-only input intact.

The creator's `swappy-20261014_211722.png` rejected the first pass's weak board/exterior separation and redundant HUD prose. The corrected runtime now has a distinct playable field, darker exterior, external earth rim, continuous jagged central ravine, broad quiet terrain patches, and orderly stone paths. Repeated Not ready/Route missing, opponent planning budgets, always-on pan instructions, zero income/queues, disabled wave captions, duplicate placement title/price, and inline affordability prose are removed or moved into tooltips. Positive gameplay state and actual controls remain available.

### 2. Coherent sprite pass

- [x] Make an actual-game-size lineup of Grunt, Runner, Brute, Arrow, Ballista, Rune, portal, and crystal against the proposed terrain. Choose one camera-elevation/light/pixel-detail standard from that lineup.
- [ ] Refine mismatched assets against that shared scene reference; do not generate each asset with an independent style or camera prompt.
- [ ] Preserve original PNGs and provenance; obtain approval for replacements before importing them. Follow the [sprite pipeline](docs/sprite-pipeline.md#approval-and-game-integration).
- [x] Verify source-facing metadata and mirrored-board facing. Start with usable still poses; decide directional poses and animation separately rather than claiming a still is a walk cycle.

The [full actual-size lineup](docs/visual-reference/asset-lineup.png) and [provenance](docs/visual-reference/asset-lineup.provenance.json) use original artwork together against the proposed terrain. This is a **static composite**, not runtime proof. The working standard is elevated three-quarter forms, upper-left lighting, dark readable contours, restrained contact shadows, and deliberate pixel clusters. Runner's head/shoulder planes, Brute's frontal pose, and Rune's finer detail remain visible mismatches.

Two shared-scene ComfyUI refinement batches produced Runner/Brute alternatives at `~/Pictures/Gorcs-PixelArt/asset-lineup-20261014/`, with original PNGs, references, raw outputs, exact requests/history, seeds, processing scripts, and hashes preserved. The candidates are not imported or approved. They improve some perspective cues but still have finer shading/bright contour flecks than Grunt; refinement and replacement approval remain unchecked.

Creator chose **Keep current sprites** for the initial presentation change. Existing runtime artwork remains installed; no replacement is approved by that decision. Continuing refinement produced two new shared-scene seed proposals under `~/Pictures/Gorcs-PixelArt/asset-lineup-20261014/coherent-refinement/`, with graphs, histories, raw outputs, source-facing/anchor metadata, cleanup scripts, and hashes preserved. `candidate-identity-locked-comparison.png` is the preferred review: seed-one Runner/Brute with an explicitly labelled CPU simplification of the original level-one Rune. Model-generated Rune architecture drift was rejected, not substituted for the accepted sprite. Brute interior detail and Rune density still need judgment; this is a static still-pose proposal, not installed art or animation. Refinement/approval boxes remain unchecked.

Portable review artifacts: [shared-scene candidate comparison](docs/visual-reference/coherent-candidates.png) and [provenance](docs/visual-reference/coherent-candidates.provenance.json). These are unapproved static proposals, kept outside Godot imports; the updated original-asset lineup uses the corrected terrain palette.

### 3. Verification and acceptance

- [x] Exercise the actual game at 1280×720 and 1000×720, on both board orientations and while panning, with representative bent paths and adjacent towers.
- [x] Inspect idle, hover, placement, selection, attacks, damaged/full health, mixed-enemy streams, and crowded combat. Check overlap, depth sorting, clipping, and health/endpoint visibility.
- [x] Compare a real gameplay capture against the approved reference with comparable counts and layout. Do not present a static composite as runtime proof.
- [x] Run applicable checks from [development](docs/development.md#setup); preserve authoritative gameplay/network state and update affected behavior regressions where needed.
- [x] Update current-state documentation only after implementation and visual verification; keep these boxes unchecked until their behavior is actually delivered.

Current corrected runtime evidence: [1280×720 empty board separation](docs/visual-reference/gameplay-empty.png), [1280×720 bent path and adjacent Rune towers](docs/visual-reference/gameplay-presentation.png), [1000×720 mixed combat](docs/visual-reference/gameplay-compact.png), and [1000×720 top-row towers clearing the HUD](docs/visual-reference/gameplay-top-row.png). These direct Godot main-scene viewport captures replace the first material/HUD pass; they are not composites. Regular enemy count/spawn spacing, board dimensions, placement/hit rules, range, and authoritative state are unchanged. See [verification details](docs/development.md#match-soundtrack-and-presentation).

## Scope boundaries

This is a presentation/art-direction task. It does not authorize balance changes, extra regular enemies, different spawn spacing, new gameplay footprints, a larger map, more path budget, new enemy mechanics, or replacing the approved HUD wholesale. Visual size is not simulation size. Generated artwork remains subject to the existing approval/provenance workflow.
