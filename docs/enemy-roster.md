# Enemy roster and sandbox

## Rules and provisional balance

All abilities, group rolls, sends, damage, healing, summons, and counters belong to `MatchCombat` on the host. Clients render accepted state. These values establish distinct roles and a gradual introduction; they are not a claim of competitive balance without friend playtests.

Health and movement use the existing wave-scaled baseline in `CombatRules`: each definition supplies a multiplier. Each leaking unit deals its own base damage. Regular selection spends weight per event/group, not per Orcling; count/share caps count those events. Ordinary enemy bounty uses the match rule unless a definition overrides it.

| Enemy | HP multiplier | Speed multiplier | Base damage | Regular wave | Send wave | Weight | Max weight share | Send price / income |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Orcling | 0.5 | 0.9 | 1 | 1 | 1 | 1 per group | 35% | 12 / +1 per group |
| Orc (`grunt`) | 1 | 1 | 1 | 1 | 6 | 1 | 100% | 20 / +2 |
| Runner | 0.6 | 1.7 | 1 | 6 | 12 | 2 | 30% | 25 / +2 |
| Brute | 2.5 | 0.65 | 3 | 12 | 22 | 5 | 35% | 40 / +4 |
| Orc Chief | 6 | 0.5 | 5 | 22 | 34 | 12 | 25% | 100 / +5 |
| NecOrcmancer | 5 | 0.55 | 3 | 34 | 46 | 15 | 25% | 140 / +6 |
| SkeleOrc | 0.5 | 1.05 | 1 | Summoned only | Not purchasable | Not in regular roster | — | — |

The first five rounds allow only Orcling sends. Each later send unlock trails the next regular threat tier; the final NecOrcmancer send unlock is deliberately delayed until round 46, as chosen by the creator. UI previews and command validation use the same accepted gate. Earlier-round debug jumps relock later sends. SkeleOrcs remain available directly in sandbox.

Orclings roll two/three/four members with 60/30/10 weights. Members arrive 0.065 simulation seconds apart; the next ordinary event waits its full normal cooldown after the last member. One paid order charges once, awards income once, and records the actual individual members sent. Rejection rolls nothing and spends nothing. Both boards receive the same host-generated regular groups/timetable. Individual Orclings award one Coin, limiting the horde's bounty advantage.

Chiefs begin at one regular selection per wave; the cap grows by one every ten waves after introduction. Every five simulation seconds a Chief heals **other living allies** inside a true circular 1.6-cell radius for 4% of each ally's maximum HP, rounded up with a one-HP minimum and capped at maximum health. No self-heal, resurrection, or square-range substitute. A brief raised-palm pose and green pulse mark the actual heal.

NecOrcmancers begin at one regular selection per wave; the cap grows by one every twelve waves after introduction. Every seven simulation seconds the caster stops for a 1.15-second staff-raising ritual, then raises two to four SkeleOrcs, limited to six living children per caster. Children inherit the caster's captured route and current progress instead of returning to the portal. A dead/leaked caster cannot finish its ritual. Living children still have to clear before the wave ends. SkeleOrcs have no kill bounty, preventing summon farming. Freeze slows movement, not the simulation ability clock; casting is stationary even while a slow expires. Two-times playback accelerates all of these simulation clocks consistently.

## Presentation

All seven enemies use a shared elevated three-quarter pixel-art language, material ramps, lighting and outlines, with separately authored faces/anatomy rather than a reused face or cut-out source limbs. Each has a twelve-frame articulated walk with opposing limbs, grounded backward foot sweep, airborne forward recovery, and role-specific equipment/cloth lag. Chief healing and NecOrcmancer casting have separate anticipation/action/recovery poses. Runtime stills match frame zero; historical source PNGs remain untouched. `tools/author_enemy_sprites.py` reproduces the sheets/stills and per-enemy JSON files in `assets/enemies/animations/` record their derivation and hashes.
Every enemy also has a twelve-frame, 0.8-second death animation. Living Orcs collapse with a small dark-red ground splatter; SkeleOrcs scatter into loose bones without blood. The host publishes short-lived, uniquely numbered confirmed-kill events; clients cannot manufacture damage, rewards, or new living enemies from them. Fallen bodies/bones linger briefly, fade, and are never selectable or targetable. Repeated snapshots cannot replay expired deaths. Playback respects simulation speed and explicit pause, but the final death can finish after wave clearance. Debug/map resets invalidate stale-coordinate effects.

## Orcieary and lifetime records

Open **Orcieary** from the main menu or press **B** there. Entries are ordered by earliest regular/send availability, with summoned-only types inheriting their summoner's earliest availability; ties use send/regular availability and stable IDs. The canonical content catalog is not reordered. Each entry shows encounter/send availability, description, portrait, base stats/scaling, mechanics, and lifetime killed/sent counts. Click the portrait, or focus it and press Enter/Space, to play its walk cycle or special action once and return to rest. Repeat activation restarts playback; selection changes clear it, and hidden previews do not run. Arrows navigate entries; Tab/Shift-Tab move between list, portrait, and Back; Escape returns.

`EnemyStatisticsStore` atomically saves `user://enemy_statistics.json`. Accepted cumulative per-side totals carry a unique model/match ID. Durable high-water marks make repeated, stale, reconnected, or restarted observations idempotent; the owned slot is bound for each ID, avoiding mirrored-solo/opponent duplication. Actual tower kills count; leaks/rejected sends do not. Sent groups count individuals. Sandbox never records progression. Invalid saves are not silently replaced; failures are shown in Orcieary and retried only from cumulative accepted state without granting phantom counts. This is a trusted local save, not account-backed anti-cheat.

## Sandbox

**Sandbox** replaces Workshop; **S** opens it from the menu. It owns a separate model, path layout, camera, and paused menu-return state. All catalog towers and enemies are available without unlocking anything. Purchases/upgrades are genuinely free; lives cannot be lost. Sandbox does not edit collection saves or lifetime records.

- Paint/erase paths with left/right drag while stopped; tiles have no spending budget.
- Buy, inspect, target, upgrade, and sell the same real tower types/evolutions used in matches.
- Choose a round and start its weighted wave, or choose any enemy and exact count, including SkeleOrcs.
- Space starts or toggles pause; choose 1×/2×/4× playback. Stop/clear removes enemies and unlocks editing while retaining the build.
- Set map width/height and confirm Resize to replace the map/build. Numeric fields accept values beyond their arrow range, subject to machine memory—not an infinite-performance promise.
- Reset build requires confirmation and retains the path. Menu/Escape pauses and preserves the playground. WASD and cursor zoom reuse match camera controls; text entry, selectors, inspectors, and dialogs take input priority.

Enemy stats are scaled to the selected round. Exact-spawn controls create the requested individual count rather than rolling an Orcling group; weighted waves and paid match orders retain grouping. All normal match ownership, funds, readiness, and send-unlock rules stay intact outside the captured sandbox mode.

## Verification

Use the [single-command checks](development.md#single-command-verification). `enemy_mechanics_test.gd` covers unlock boundaries, atomic rolls, grouped budgets/timing, true-radius healing, caps, cast death/leaks, inherited routes, spawn exposure, slow/cast interaction, and sandbox/statistics isolation. `enemy_mechanics_peer_test.gd` uses real separate host/client processes with divergent client resources. Statistics tests cover duplicate/stale snapshots, restart, corruption, atomic failure/retry, accepted kills/sends, and leaks. Sandbox and rendered Orcieary/board tests cover input priority, confirmations, geometry, animations, and hidden-state behavior. Real friend play remains necessary to tune pressure, maze lengths, healing usefulness, and late-wave performance.

The expansion's full `python3 tools/verify.py all` run passed **41/41 checks** (36 suites plus five gates), including separate real host/client processes and rendered tests. A graphical main-scene smoke exercised menu shortcuts, all seven previews at 1000×720/1280×720, native sandbox path drawing, all three free tower branches, mixed exact spawns, paused navigation, and confirmed 40×24 resizing. A separate real simulation captured Chief healing, stationary staff casting, and living summoned children. A normal match UI smoke recorded three accepted Orcling sends and five actual Orcling kills, displayed them in Orcieary, and reloaded the same saved totals. Smoke resources/saves/scripts were isolated and removed; automated checks do not establish competitive balance or internet reachability.

The portrait/order/art/death revision passed **43/43 project checks**, including real host/client kill-event replication and rendered corpse/blood cleanup. Native portrait clicks were exercised for every sorted entry at 1000×720 and 1280×720. Actual sandbox kills rendered each collapse, bloodless SkeleOrc bone heap, and expiry, including the final death after automatic wave clearance. The reversed grounded/airborne gait was corrected and numerically audited for source-left and mirrored-right before in-game inspection. A clipped Brute collapse frame was corrected; all 192 exported frames retain transparent margins. These checks validate behavior and readability, not objective aesthetic perfection.
