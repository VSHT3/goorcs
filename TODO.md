# TODO — Match visual direction

## Status and reference

- [x] Creator approved the direction of the board composition study on 2026-10-14.
- [x] Implement the approved presentation in the running game using existing artwork; coherent replacements remain approval-gated below.

![Approved board composition study](docs/visual-reference/board-target.png)

This is a **static composition study, not an implemented game screenshot**. Approval covers the overall look: stronger proportions, more grounded sprites, layered terrain/path materials, and quieter highlights. It does not mean every existing sprite is final or that the exact camera angle has been settled. The study retains the supplied HUD, two owned Rune towers, four owned Grunts, one opponent Grunt, and the bent-route concept; no extra combat population was added to make it look fuller.

The portable reference is copied unchanged from `~/Pictures/Gorcs-PixelArt/board-readability-pass/board-target.png`. The original study directory also retains its detail image and `provenance.json`. Reference artwork is excluded from Godot imports and is not a runtime asset.

## Recommended viewing angle

**Validate an elevated, front-dominant oblique view for structures:** a broad front face, a narrower visible right side, and enough roof to convey depth. This is the creator's latest working preference from the 2026-10-14 sprite discussion; replacement artwork is not yet approved.

- Keep the existing axis-aligned square grid and 2D gameplay camera. This is a sprite-art direction, not a conversion to a diamond/isometric map or a 3D camera.
- Avoid both equal-sided corner-on foundations and flat front-elevation cutouts. Keep the front foundation edge broadly horizontal; reveal a smaller side face and visible top surfaces.
- Show an enemy's head/shoulders from above while retaining a readable face, torso, and legs. Avoid a pure side-view platformer pose.
- Share camera elevation, ground plane, light direction, shadow treatment, outline weight, and apparent pixel density. Matching angle does **not** require identical facing: structure bases stay fixed while directional weapons and enemies turn.
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

### 3. Structure perspective and eight-way ballista — paused, not implemented

The creator preferred the original heavy crossbow over a front-facing masonry base, but rejected that rough composite's quality. The later `swappy-20261014_223240.png` sketch supersedes the completely frontal box in `swappy-20261014_223203.png`: retain a broad front wall, show a narrower right wall, and reveal more roof. The earlier equal-sided corner-facing appearance in `swappy-20261014_215908.png` is not the target. These references are local Desktop screenshots; the geometry description here is the portable direction.

#### Artwork changes

- [ ] Refine the ballista into a convincing, substantial structure in that front-dominant perspective. Preserve the recognizable heavy timber crossbow, pale stone, steel fittings, upper-left light, and readable dark contours. Improve masonry and roof depth; avoid a skinny box, repetitive tiny bricks, or a miniature weapon.
- [ ] Produce **eight distinct crossbow poses: N, NE, E, SE, S, SW, W, NW**. Generate poses individually against one consistent design/perspective reference; keep the process direct and show useful results promptly instead of repeating a prolonged guide/composite/isolation workflow.
- [ ] Keep the **base identical in every pose**. Only the crossbow assembly turns around its vertical swivel: stock, bow limbs, string, and bolt move together. One shared base with eight weapon layers or full frames assembled from that same base are acceptable; independently changing masonry is not.
- [ ] Align all poses to one swivel point, consistent scale, and canvas. Match physical weapon proportions and materials across views; ensure each bolt points in its named direction, strings meet the stock correctly, and nothing floats or detaches. Draw directional perspective rather than rotating the PNG in its image plane.
- [ ] Apply the same accepted structure perspective to the other towers, crystal pedestal, and portal rim. Preserve crystal facets and portal-opening readability; do not change the square-grid map or gameplay camera to accommodate sprites.
- [ ] Obtain approval for the finished actual-size set before importing replacements. Preserve original PNGs, generation provenance, and stable collection/save identities.

#### Game additions

- [ ] Add ballista directional-art resources and board rendering using the accepted eight poses and shared base; retain a suitable still icon for collection/chest/UI surfaces.
- [ ] Make the crossbow visually track the **host-selected enemy**, not a renderer-selected nearest enemy. `MatchCombat` already records `target_id` and `aim` when firing; follow the live target position between shots and handle absent/dead/out-of-range targets explicitly without changing targeting policy, damage, or authority.
- [ ] Select the correct pose from the displayed direction to that target, including mirrored-board rendering. Keep the base, foot anchor, contact shadow, depth sorting, selection, and camera behavior stable while aiming.
- [ ] Exercise all eight directions and target/idle transitions in the running game, on both board orientations and with separate host/client processes. Inspect adjacent towers, roof attachment, overlaps, and HUD clipping at 1280×720 and 1000×720; run the applicable development checks before marking this implemented.

#### Experiment handoff

Work stopped at the creator's request; **no replacement sprites were imported and no tracking behavior was implemented**. Eight individual full-pose generations and isolated weapon candidates exist, but the set is not approved or fully cleaned/aligned. The south full-pose generation was oversized; a smaller isolated alternative exists. Other observed issues include inconsistent bow/stock/string geometry, mount alignment gaps, and a detached fragment in the west extraction. The draft assembly is not acceptance evidence.

- Initial rough front-facing studies: `~/Pictures/Gorcs-PixelArt/ballista-facing-experiment/`.
- Later generations, direction references, requests/history, and draft assemblies: `~/Pictures/Gorcs-PixelArt/ballista-eight-directions-v2/`.
- `generated-full-poses-review.png` shows the eight generated full poses; `eight-pose-assembly-review.png` shows the unfinished shared-base assembly.
- `base-oblique-01-native_00001_.png` is the unapproved sketch-led base candidate with a narrower visible right side. Later weapon refinement outputs still need review; do not treat a completed generation as approved artwork.


### 4. Verification and acceptance

- [x] Exercise the actual game at 1280×720 and 1000×720, on both board orientations and while panning, with representative bent paths and adjacent towers.
- [x] Inspect idle, hover, placement, selection, attacks, damaged/full health, mixed-enemy streams, and crowded combat. Check overlap, depth sorting, clipping, and health/endpoint visibility.
- [x] Compare a real gameplay capture against the approved reference with comparable counts and layout. Do not present a static composite as runtime proof.
- [x] Run applicable checks from [development](docs/development.md#setup); preserve authoritative gameplay/network state and update affected behavior regressions where needed.
- [x] Update current-state documentation only after implementation and visual verification; keep these boxes unchecked until their behavior is actually delivered.

Current corrected runtime evidence: [1280×720 empty board separation](docs/visual-reference/gameplay-empty.png), [1280×720 bent path and adjacent Rune towers](docs/visual-reference/gameplay-presentation.png), [1000×720 mixed combat](docs/visual-reference/gameplay-compact.png), and [1000×720 top-row towers clearing the HUD](docs/visual-reference/gameplay-top-row.png). These direct Godot main-scene viewport captures replace the first material/HUD pass; they are not composites. Regular enemy count/spawn spacing, board dimensions, placement/hit rules, range, and authoritative state are unchanged. See [verification details](docs/development.md#match-soundtrack-and-presentation).

## Scope boundaries

This is a presentation/art-direction task. It does not authorize balance changes, extra regular enemies, different spawn spacing, new gameplay footprints, a larger map, more path budget, new enemy mechanics, or replacing the approved HUD wholesale. Visual size is not simulation size. Generated artwork remains subject to the existing approval/provenance workflow.
