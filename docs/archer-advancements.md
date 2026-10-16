# Arrow tower advancements

## Purchase rules

Damage and speed upgrades lead to Second Archer at level IV. After buying Second Archer, choose exactly one fixed-price advancement for level V. Choice, cost, funds, ownership, phase, investment and refunds belong to the same host transaction as ordinary upgrades; a failed, repeated, or competing choice changes nothing. Committed Ready locks these commands until combat. Sandbox uses the same rules but charges nothing. Selling and rebuilding permits another choice; there is no hidden respec.

| Advancement | Price | Effect |
| --- | ---: | --- |
| Four Archers | 650 Coins | Four independently targeted streams; another multiplicative 10% attack-rate increase |
| Fire Arrows | 600 Coins | Two physical arrow streams; qualifying hits ignite for 4 damage/s over 3 simulation seconds |
| Bomb Arrows | 750 Coins | Two bomb-tipped streams; primary damage ×1.5, other enemies inside a 0.85-cell circle take ×0.5 damage, each rounded up |

These values are provisional role tuning, not measured competitive balance. Costs and mechanics live in `TowerDefinition.advancements` in `resources/combat/towers/arrow_tower.tres`; the host captures them on match admission. No Arrow ID-specific purchase/attack switch is required for resource variants using the same mechanics.

## Targeting and damage

Four Archers exposes four real targeting selectors. Each stream first chooses an unused eligible enemy using its own Furthest/Closest/Strongest policy. If no unused enemy remains, it selects again without exclusions using that same policy. Two/three enemies therefore receive all four arrows, and one enemy can receive four full-damage hits. Second Archer uses the same fallback. Targets are captured before damage; a lethal shared volley still releases every accepted arrow, but death/bounty resolve only once. Out-of-range enemies never count as alternatives. Stream counters, aims, IDs and modes remain independent.

Burning is nonstacking. Equal/stronger qualifying hits refresh the full duration and source; a weaker burn cannot replace a stronger active burn. Fractional HP accrues only after ignition, with no immediate burn tick. Expiry caps exposure; re-ignition does not duplicate damage. Burn kills use the existing damage/death/bounty/statistics owner, including when the source tower has already been sold. Dead/leaked enemies and round resets retire burn state. Pause and playback speed use simulation time.

Bombs preserve the accepted primary impact point before any victim is removed. The primary takes its increased physical hit once; nearby **other** living enemies take reduced damage inside a true circle, not a tile square. Splash never chains into more bombs and cannot hit the other board. Both archers' accepted bolts still render even if an earlier explosion has killed a later volley target.

## Presentation and immunities

Fire Arrows adds animated pixel flames to both arrows held on the tower, moving flame trails, and a warm red/orange current-frame enemy palette with restrained fire motes. Bomb Arrows adds bombheads/fuses to held/moving arrows and a small accepted-impact puff/ring/spark animation. Original tower PNGs remain unchanged. All effects are local presentation and cannot apply damage; repeated snapshots cannot duplicate/restart captured flights.

The runtime archer is now a layered upright pixel rig, not a repeated baked crop. Head/body directional sheets and an archer-free board texture preserve the original collection PNG. Each of the one/two/four shooters reads its own accepted aim; the tower structure never rotates. Bow joints/string and nocked arrow share geometry with the captured release tip. Fire and bombs attach to that tip in hand and flight. Directional heads use eight authored directions; bow direction remains continuous with pixel-snapped joints.

An accepted shot releases immediately with a short recoil/string recovery, then nocks and progressively draws for the next volley. The first shot does not fake pre-shot anticipation, and presentation cannot delay host damage. Pose ages use simulation playback speed and explicit pause. Repeated snapshots do not restart a pose; stream removal, debug, new run and leaving retire stale presentation. Captured normalized origins remain fixed when later targets change. Native48px render tests cover stationary base, independent aiming, tip-to-flight continuity, fire/bomb attachment, mirrored placement, paused poses,3× recovery and cleanup. Actual mixed-tower gameplay was rendered at1×/3× and both board orientations; sound is independently bounded rather than squeak-pitched with speed.


`EnemyDefinition.fire_immune` and `ice_immune` are captured by the host. SkeleOrcs enable both: physical arrows, bombs and Rune damage still work, but ignition/burn damage and Freeze slow do not. The Orcieary lists these immunities. Status rendering uses accepted instance immunity flags rather than independent client calculations; picking still uses the current opaque animation frame.

## Verification

`archer_advancement_test.gd` covers prerequisites, exact affordability, exclusive purchases, level/refund behavior, four distinct targets/fewer-target boundaries, timed nonstacking burn and sold-source kills, circular splash/primary exclusion, and physical/status immunity precedence. `archer_advancement_peer_test.gd` uses separate host/client processes with deliberately different client prices/stats and verifies paid branches, rejected foreign/switch commands, four targets, burns/bombs and client-clock rejection. Tower-selection and rendered board regressions exercise actual controls, target selectors, held flames, streams, bomb impacts and palette/alpha behavior.

The integrated advancement pass passed **45/45 project checks**, including real separate host/client purchases/hits and rendered native-size projectile/idle-effect checks. A graphical game smoke bought all three branches through actual Sandbox controls, observed four captured streams and burning nonimmune enemies, inspected management at 1000×720/1280×720, and displayed SkeleOrc immunities. A normal paid-match smoke bought Four Archers for its configured 650 Coins after the three prerequisites, reached level V, and changed the third/fourth target modes independently. Original tower artwork and all existing enemy balance remained unchanged.

The shared-target cutover replaces idle extra archers when enemies are scarce; it intentionally increases dual/four-archer single-target damage without changing prices, cadence or status stacking. Regression coverage includes one/two/three/four enemies, range exclusions, lethal removal/bounty and fire/ice behavior. A real Sandbox volley targeted one Chief with all four accepted IDs, applied12 damage, and rendered four projectiles; both orientations were inspected at1280×720/1000×720. Hands now have clearer outlined joints and sleeve/skin separation, and shorter bow limbs reduce overlapping diagonal clutter. Tower textures and footprints stay unchanged.

Full integrated verification passed **51/51 checks** after this change, including real host/client, sound, targeting, burn/immunity and rendered rig suites. A subsequent isolated main-scene startup also checked the revised targeting tooltips.


