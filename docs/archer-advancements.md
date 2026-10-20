# Arrow tower advancements

## Purchase rules and provisional balance

Damage and speed upgrades lead to Second Archer at level IV. Choose one level-V branch, then buy its successors in order. Each purchase uses the same host transaction for prerequisites, funds, ownership, phase, investment, and refunds. Repeated, skipped, or competing purchases change nothing. Committed Ready locks management until combat; Sandbox uses the same rules without charging. Selling and rebuilding permits another branch.

| Upgrade | Requires | Coins | Effect before rolls/support |
| --- | --- | ---: | --- |
| Four Archers | Second Archer | 650 | Four independent streams; ×1.1 attack rate |
| Eight Archers | Four Archers | 800 | Four archers on each of two storeys; eight independent streams |
| Arrow Minigun | Eight Archers | 1600 | Three crew brace one rotary gun; one stream at twenty individual archers' rate |
| Fire Arrows | Second Archer | 600 | Two physical streams; nonstacking 4 DPS burn for 3 simulation seconds |
| Molotov Cocktails | Fire Arrows | 800 | Two throwers; ×1.25 primary / ×0.65 collateral damage within 1 cell; affected nonimmune survivors burn |
| Quick Pitch | Molotov Cocktails | 1000 | Same bottles and splash, ×1.5 throw rate |
| Flamethrower | Quick Pitch | 1800 | One operator; 144 continuous FIRE DPS, 12 DPS burn for 5 seconds; 60-second uninterrupted fuel streak, 6-second refuel |
| Bomb Arrows | Second Archer | 750 | Two streams; ×1.5 primary / ×0.5 collateral damage within 0.85 cells |
| Bigger Explosions | Bomb Arrows | 250 | Splash radius grows to 1.25 cells |
| Anti-Orc Grenades | Bigger Explosions | 1000 | Two throwers; ×2 primary / ×1 collateral damage, 1.5-cell radius, ×1.1 attack rate |
| A.O.M. | Anti-Orc Grenades | 1800 | One muscular rocket operator; half the preceding attack rate, ×12 primary / ×8 collateral damage, 2.5-cell radius |
| A.O.M. Rapid Reload I | A.O.M. | 450 | ×1.1 attack rate |
| A.O.M. Rapid Reload II | Rapid Reload I | 650 | Another ×1.1 attack rate; ×1.21 across both kits |

Prices and combat fields live in the flat `TowerDefinition.advancements` dictionary in `resources/combat/towers/arrow_tower.tres`, captured on admission. `requires` names the exact preceding advancement. Each record contains complete resulting combat properties; only `attack_rate_multiplier` compounds once per purchase. `advancement_path` retains accepted history for levels, while `advancement` names the active tier.

These are provisional power-based prices, not measured competitive balance. Major weapons become more expensive; the deliberately cheap blast expansion and smaller reload kits are priced for their marginal benefit. With all prerequisites, no rolls, and no support:

- Minigun costs **3370 Coins**, dealing **121 direct DPS**.
- Flamethrower costs **4520**, dealing **144 direct + 12 burn DPS** while firing. It is a stronger focused fire-only capstone, not Molotov crowd coverage.
- A.O.M. costs **4120**, dealing **36 primary / 24 collateral damage** roughly every **0.99 seconds**. Both reload kits bring investment to **5220** and interval to roughly **0.82 seconds**.

## Targeting and damage

Every Arrow tower has one **< current policy >** selector in match and Sandbox inspection, shared by all one/two/four/eight archers and retained by the Minigun, A.O.M., and Flamethrower. First → Last → Closest → Strongest wraps in either direction. First selects greatest captured-route progress; Last selects least progress, not greatest tower distance. Closest uses tower distance; Strongest uses current HP. The host owns `tower.mode`, validates changes through the normal ownership/Ready gates, and preserves it across upgrades, evolutions, and reloads. There are no separate archer policies or commands. Streams apply that same policy to unused eligible targets first, then share when enemies are scarce, so all eight can hit one enemy without being forced to do so. Targets are captured before damage; lethal shared volleys still release all accepted arrows, but deaths/rewards resolve once. Each stream retains independent accepted shot, aim, target ID, and release-origin state for visuals.

Burning is nonstacking. Equal/stronger qualifying hits refresh duration/source; weaker burn cannot replace stronger active burn. Fractional HP accrues only after ignition, with no immediate burn tick. Expiry caps exposure; re-ignition does not duplicate damage. Burn kills retain attribution, bounty, and statistics even after the source tower is sold. Dead/leaked enemies and round resets retire burn state. Pause and playback use simulation time.

Explosives preserve the accepted primary impact point before victims are removed. The primary takes its increased physical hit once; other living enemies inside a true circle take collateral damage, each rounded up. Splash never chains into more explosives or hits the other board. Molotov splash also ignites surviving nonimmune victims.

The Minigun processes every due subinterval shot, including when physics/playback steps exceed its interval. Host throughput is not capped at one arrow per tick. Its bounded cosmetic stream staggers flights when snapshots combine several accepted shots.

## Continuous flame and fuel

Flamethrower damage is entirely FIRE: fire-immune enemies take neither direct damage nor burn and are not eligible targets. It focuses one eligible enemy and can retarget immediately after a lethal contact. Direct DPS retains accepted damage and attack-speed multipliers; burn retains damage multipliers. Fractional accumulation avoids per-frame rounding amplification.

`firing`, `continuous_fire_time`, `refuel_remaining`, and `refuel_duration` belong to the host. Uninterrupted firing reaches 60 simulation seconds and commits a 6-second refuel. Losing all eligible targets before exhaustion resets the streak; immediately changing between available victims does not. A committed refuel cannot be canceled by target loss or a wave/debug transition. Planning/pause does not advance the combat clock. After refueling, firing starts with a fresh streak.

Integration splits at birth, movement/range, lethal, fuel, and refuel boundaries so coarse/fine steps agree. Expired refuel time normalizes to exactly zero: floating-point residue must not leave the renderer showing refueling while authoritative damage has resumed.

## Presentation and immunities

Fire/bomb arrows retain held-tip effects and the original upright directional bow rig. Molotovs and grenades replace bows with articulated windup/release/recovery throws; payloads spin along raised arcs, then show fiery shatter or smoky shrapnel. A.O.M. uses a dark-haired, broad-armed operator, large shoulder launcher, recoil/backblast, rocket smoke, and a stepped radial explosion. Reload tiers add distinct weapon trim.

Eight Archers adds a second deck with four independently aiming archers per storey. The Minigun has one rotating multi-barrel weapon and three bracing/recoiling crew, not twenty cloned bows. Flamethrower uses one dark-haired operator with a tank, hose, nozzle, and directional jet. Refueling disconnects the hose, lowers/exchanges the cylinder, and primes it, with a small staged progress indicator.

`tools/author_arrow_branches.py` reproduces additive branch layers and operator sheets without replacing original collection/source PNGs. `ArrowWeaponVisuals` and `PathBoard` share equipment, geometry, captured origins, and cosmetic clocks with Towerieary portraits and graph thumbnails. The guide keeps readable connected nodes in a chrome-free scrollable graph; selection/focus reveals deep tiers. Inspection shows one tower-wide policy selector. Only its title/X remain pinned; every upgrade/evolution choice shares one scrolling purchase section above Sell, which stays last, rather than a separate Archer follow-up row.

Damage still uses the existing combat owner; projectile flight/impact animation cannot delay or apply another hit. Each trace preserves its original weapon, release origin, and destination after aim or advancement changes. Deduplication, bounded histories, retirement/generation cleanup, pause, and simulation playback apply to all weapons.

`EnemyDefinition.fire_immune` and `ice_immune` are captured by the host. Skeltorcs and Giant Skeltorcs enable both: physical arrows, bottle/grenade/rocket splash, and Rune damage still work, but ignition/burn, the entire Flamethrower, and Freeze slow do not. Orcieary lists these immunities; rendering uses accepted instance flags rather than client resource calculations. KamikaOrc shields absorb whole damaging contacts and attached ignition/freeze; continuous attacks consume charges by accepted attack interval, with no frame-rate-dependent depletion or hidden fractional damage debt.

## Verification

Historical coverage in `archer_advancement_test.gd` included prerequisite chains, atomic rejection/spending/history/refunds, eight distinct/shared targets, Minigun throughput, circular thrown splash/ignition, immunity, rolled/support scaling, continuous/lethal/movement integration, and fuel/refuel/interruption boundaries. `archer_advancement_peer_test.gd` covered new paid chains, eight then-independent policies, divergent client configuration, rocket/flame results, and rejected client clocks through separate host/client processes. Solo, guide/provider, inspector, native-size board, and portrait suites covered their consumers. The independent-policy behavior is now superseded by the shared tower policy; the results below predate and do not verify that cutover.

The isolated `python3 tools/verify.py all` run passed **62/62 checks**, including both startup modes, every model/control/guide/rendered suite, and separate localhost host/client processes. Logs: `.verify-logs/20261017T184054Z-all-61bbef80/`.

After the final stat/chrome/blast polish, the four focused suites and an isolated **15.24-second actual-main-scene rendered walkthrough** passed on macOS Compatibility/OpenGL (Apple M2). Native Towerieary controls selected every Arrow stage at **1000×720 / 1280×720**; Sandbox controls bought every tier, spawned enemies, exercised thrown/rotary/flame/rocket attacks and both orientations, and completed **60 seconds firing → 6 seconds refueling → resumed fire**. Only private fixture enemy health/movement changed for endurance, never tower stats. Native48px and representative guide/Sandbox/refuel captures were inspected. Evidence: `.verify-logs/gorcs-verify-archer-smoke-1d075d4687274300b3e685a13fd7ae6c/`.

### Earlier verification

The original three advancements passed **45/45** integrated checks, including real peers, native-size projectiles, paid Four Archers, Sandbox controls at both supported widths, and displayed Skeltorc immunities. A later shared-target cutover passed **51/51**, including real peers, sound, targeting, burn/immunity, and rig rendering. It changed scarce-enemy fallback without changing the original prices/status stacking. Those historical checks do not establish final late-game balance, artwork approval, long-run performance, or separate-network reachability for this expansion.
