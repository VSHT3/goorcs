# TODO — Visual direction and gameplay roadmap

## Sprite consistency and replacement approval

- [ ] Refine mismatched assets against the shared scene reference, not independent style/camera prompts. Runner's head/shoulder planes, Brute's frontal pose, and Rune's finer detail remain mismatches.
- [ ] Obtain creator approval before importing replacements; preserve original PNGs and provenance through the [sprite pipeline](docs/sprite-pipeline.md#approval-and-game-integration). Keeping current sprites did not approve the pending candidates.
- [ ] Apply the accepted structure perspective to the other towers, crystal pedestal, and portal rim. Preserve crystal facets and portal-opening readability without changing the square grid or gameplay camera. Existing approved replacements do not establish roster-wide consistency.
- [ ] Obtain final creator judgment of Ballista's provisional reconstructed roof and cross-view weapon proportions after playtesting. A separately generated empty base remains blocked by provider credits; the installed fixed-base/eight-direction set is an authorized trial, not final artwork approval. See the [Ballista archive](archive_assets/README.md#provisional-directional-ballista-game-trial).

### Working art direction

Use an elevated, front-dominant oblique structure view: broad front wall, narrower visible right side, visible roof, and a broadly horizontal front foundation edge. Avoid equal-sided corner-on bases, flat front-elevation cutouts, and strict bird's-eye sprites. Enemies should show head/shoulder planes while retaining readable faces, torsos, and legs.

Share camera elevation, ground plane, upper-left lighting, dark readable contours, restrained contact shadows, and deliberate pixel clusters. Structure bases stay fixed while weapons and enemies turn. Judge proportions and detail density together at actual game size, not as enlarged isolated PNGs.

### Review references

- [Approved board composition study](docs/visual-reference/board-target.png): static visual-direction reference, not a game screenshot or approval of every sprite or the exact camera angle.
- [Original-art actual-size lineup](docs/visual-reference/asset-lineup.png) and [provenance](docs/visual-reference/asset-lineup.provenance.json): static shared-scene comparison, not runtime proof.
- [Pending shared-scene candidates](docs/visual-reference/coherent-candidates.png) and [provenance](docs/visual-reference/coherent-candidates.provenance.json): unapproved still-pose proposals, not installed art or animation. Preferred review uses seed-one Runner/Brute and a labelled CPU simplification of the original level-one Rune; model-generated Rune architecture drift was rejected. Brute interior detail and Rune density still need judgment.
- Original refinement batches and reproducible processing: `~/Pictures/Gorcs-PixelArt/asset-lineup-20261014/`, including `coherent-refinement/candidate-identity-locked-comparison.png`.
- Runtime comparison captures: [empty board](docs/visual-reference/gameplay-empty.png), [bent path and adjacent Rune towers](docs/visual-reference/gameplay-presentation.png), [compact mixed combat](docs/visual-reference/gameplay-compact.png), and [top-row clearance](docs/visual-reference/gameplay-top-row.png). These are actual Godot captures; [development](docs/development.md#match-soundtrack-and-presentation) records their verification scope.

## Gameplay roadmap — loadouts, tower rolls, and roster expansion

- [ ] Decide Lightning's final identity/name and additional evolution choices. Direct chains, Escalating Chain, and Longer Reach already exist; the missing work is the design decision, not those mechanics.
- [ ] Complete battlefield visual acceptance for the six-role expansion: actual loadout, HUD, inspection, branch surfaces, and new artwork. Later rendered checks cover HUD/camera, tower inspection/accounting, continuous Ballista tracking, selected artwork integrations, and Towerieary; they do not establish blanket battlefield-art approval. Use [six-role verification](docs/development.md#six-role-gameplay-verification) and subsequent verification sections to identify remaining surfaces rather than repeating completed checks. Headless control/peer checks are not pixel proof; interrupted or timed-out rendered attempts are not passing runs.

All authored odds, attribute bounds, reroll curves, Shard grants/drops, tower/evolution stats, prices, production amounts, and provisional branch names remain subject to playtesting and creator judgment. Implemented rules and authoring contracts live in the [content pipeline](docs/content-pipeline.md#six-role-schemas-and-evolution-data); they are not missing implementation or approved final balance.

## Scope constraints

- Preserve square-grid placement, gameplay footprints, path legality, board dimensions/budgets, regular enemy counts and spawn spacing. Visual refinement does not authorize balance changes, new mechanics, or replacing the approved HUD wholesale.
- Keep health, sales, rolls, damage, rewards, and tower statistics host-authoritative; UI and cosmetics display accepted state.
- Generated replacement artwork requires explicit approval and retained provenance. Still-art approval does not imply animation approval.
