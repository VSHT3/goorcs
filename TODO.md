# TODO — Match visual direction

## Status and reference

- [x] Creator approved the direction of the board composition study on 2026-10-14.
- [ ] Implement the approved presentation in the running game.

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

- [ ] Establish resource-driven visual sizing and base/foot anchors for towers and enemies; avoid a one-size-fits-all canvas fit.
- [ ] Apply the approved tower/enemy hierarchy without changing tower footprints, placement cells, hit rules, range, or path legality.
- [ ] Add restrained terrain/path materials and grounding shadows; retain continuous path junctions and readable endpoints.
- [ ] Remove always-on tower rectangles and irrelevant idle combat hover outlines; preserve explicit selection, placement legality, and selected range feedback.
- [ ] Limit routine health-bar clutter and replace overpowering attack highlights with clearer transient effects. Keep damage/AoE information understandable.
- [ ] Keep the fixed HUD, compact-width usability, local camera scouting, and opponent read-only input intact.

### 2. Coherent sprite pass

- [ ] Make an actual-game-size lineup of Grunt, Runner, Brute, Arrow, Ballista, Rune, portal, and crystal against the proposed terrain. Choose one camera-elevation/light/pixel-detail standard from that lineup.
- [ ] Refine mismatched assets against that shared scene reference; do not generate each asset with an independent style or camera prompt.
- [ ] Preserve original PNGs and provenance; obtain approval for replacements before importing them. Follow the [sprite pipeline](docs/sprite-pipeline.md#approval-and-game-integration).
- [ ] Verify source-facing metadata and mirrored-board facing. Start with usable still poses; decide directional poses and animation separately rather than claiming a still is a walk cycle.

### 3. Verification and acceptance

- [ ] Exercise the actual game at 1280×720 and 1000×720, on both board orientations and while panning, with representative bent paths and adjacent towers.
- [ ] Inspect idle, hover, placement, selection, attacks, damaged/full health, mixed-enemy streams, and crowded combat. Check overlap, depth sorting, clipping, and health/endpoint visibility.
- [ ] Compare a real gameplay capture against the approved reference with comparable counts and layout. Do not present a static composite as runtime proof.
- [ ] Run applicable checks from [development](docs/development.md#setup); preserve authoritative gameplay/network state and update affected behavior regressions where needed.
- [ ] Update current-state documentation only after implementation and visual verification; keep these boxes unchecked until their behavior is actually delivered.

## Scope boundaries

This is a presentation/art-direction task. It does not authorize balance changes, extra regular enemies, different spawn spacing, new gameplay footprints, a larger map, more path budget, new enemy mechanics, or replacing the approved HUD wholesale. Visual size is not simulation size. Generated artwork remains subject to the existing approval/provenance workflow.
