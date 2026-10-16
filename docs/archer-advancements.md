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

Four Archers exposes four real targeting selectors. A volley captures distinct living targets according to each archer's Furthest/Closest/Strongest policy before applying damage. With fewer than four eligible enemies, extra archers do not repeatedly hit one victim. The third/fourth streams retain their own shot counters, accepted aims, IDs and modes; growth translates aims and debug resets cosmetic shots without removing the paid path. Two extra archer overlays and four source muzzles reflect that state.

Burning is nonstacking. Equal/stronger qualifying hits refresh the full duration and source; a weaker burn cannot replace a stronger active burn. Fractional HP accrues only after ignition, with no immediate burn tick. Expiry caps exposure; re-ignition does not duplicate damage. Burn kills use the existing damage/death/bounty/statistics owner, including when the source tower has already been sold. Dead/leaked enemies and round resets retire burn state. Pause and playback speed use simulation time.

Bombs preserve the accepted primary impact point before any victim is removed. The primary takes its increased physical hit once; nearby **other** living enemies take reduced damage inside a true circle, not a tile square. Splash never chains into more bombs and cannot hit the other board. Both archers' accepted bolts still render even if an earlier explosion has killed a later volley target.

## Presentation and immunities

Fire Arrows adds animated pixel flames to both arrows held on the tower, moving flame trails, and a warm red/orange current-frame enemy palette with restrained fire motes. Bomb Arrows adds bombheads/fuses to held/moving arrows and a small accepted-impact puff/ring/spark animation. Original tower PNGs remain unchanged. All effects are local presentation and cannot apply damage; repeated snapshots cannot duplicate/restart captured flights.

`EnemyDefinition.fire_immune` and `ice_immune` are captured by the host. SkeleOrcs enable both: physical arrows, bombs and Rune damage still work, but ignition/burn damage and Freeze slow do not. The Orcieary lists these immunities. Status rendering uses accepted instance immunity flags rather than independent client calculations; picking still uses the current opaque animation frame.

## Verification

`archer_advancement_test.gd` covers prerequisites, exact affordability, exclusive purchases, level/refund behavior, four distinct targets/fewer-target boundaries, timed nonstacking burn and sold-source kills, circular splash/primary exclusion, and physical/status immunity precedence. `archer_advancement_peer_test.gd` uses separate host/client processes with deliberately different client prices/stats and verifies paid branches, rejected foreign/switch commands, four targets, burns/bombs and client-clock rejection. Tower-selection and rendered board regressions exercise actual controls, target selectors, held flames, streams, bomb impacts and palette/alpha behavior.

The integrated advancement pass passed **45/45 project checks**, including real separate host/client purchases/hits and rendered native-size projectile/idle-effect checks. A graphical game smoke bought all three branches through actual Sandbox controls, observed four captured streams and burning nonimmune enemies, inspected management at 1000×720/1280×720, and displayed SkeleOrc immunities. A normal paid-match smoke bought Four Archers for its configured 650 Coins after the three prerequisites, reached level V, and changed the third/fourth target modes independently. Original tower artwork and all existing enemy balance remained unchanged.
