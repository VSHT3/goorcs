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
| NecOrcmancer | 5 | 0.5 | 3 | 34 | 46 | 15 | 25% | 140 / +6 |
| NecOrcmancer Mancer | 30 | 0.3 | 8 | 40, then occasional | Never | 40 | 50% | — |
| SkeleOrc | 0.5 | 1.05 | 1 | Summoned only | Not purchasable | Not in regular roster | — | — |

The first five rounds allow only Orcling sends. Each later send unlock trails the next regular threat tier; the final NecOrcmancer send unlock is deliberately delayed until round 46, as chosen by the creator. UI previews and command validation use the same accepted gate. Earlier-round debug jumps relock later sends. SkeleOrcs remain available directly in sandbox.

Orclings roll two/three/four members with 60/30/10 weights. Members arrive 0.065 simulation seconds apart; the next ordinary event waits its full normal cooldown after the last member. One paid order charges once, awards income once, and records the actual individual members sent. Rejection rolls nothing and spends nothing. Both boards receive the same host-generated regular groups/timetable. Individual Orclings award one Coin, limiting the horde's bounty advantage.

Chiefs begin at one regular selection per wave; the cap grows by one every ten waves after introduction. Every five simulation seconds a Chief heals **other living allies** inside a true circular 1.6-cell radius for 4% of each ally's maximum HP, rounded up with a one-HP minimum and capped at maximum health. No self-heal, resurrection, or square-range substitute. A brief raised-palm pose and green pulse mark the actual heal.

NecOrcmancers begin at one regular selection per wave; the cap grows by one every twelve waves after introduction. Every seven simulation seconds the caster stops for a 1.15-second staff-raising ritual, then raises two to four SkeleOrcs, limited to six living children per caster. Children inherit the caster's captured route and current progress instead of returning to the portal. A dead/leaked caster cannot finish its ritual. Living children still have to clear before the wave ends. SkeleOrcs have no kill bounty, preventing summon farming. Freeze slows movement, not the simulation ability clock; casting is stationary even while a slow expires. Two-times playback accelerates all of these simulation clocks consistently.

**NecOrcmancer Mancer** (`necorcmancer_mancer`) is a separate boss, never a paid send. One is guaranteed on round 40: its 40 weight is reserved before ordinary selections from that round's 84-weight budget. Later waves roll once for an encounter, starting at 5% on round 41 and gaining 0.5 percentage points per round, capped at 25% from round 81 onward. At most one boss appears per wave, still respecting budget/share limits. These encounter odds and combat values are provisional tuning.

The boss uses the same seven-second / 1.15-second ritual, but raises **two to four ordinary NecOrcmancers**, capped at six living direct children. Those NecOrcmancers retain their own stats, bounty, and SkeleOrc rituals; newborn casters start their clocks at birth and cannot cascade a cast immediately. Every generation inherits its parent's captured route/current progress, and all descendants must clear before the wave ends. Catalog validation permits acyclic summon chains and rejects self/indirect cycles. The boss pays 40 Coins when killed; SkeleOrcs retain zero normal Coin bounty.

## Health progression

The shared baseline is now **8 + (round − 1)** HP instead of **8 + 2 × (round − 1)**. This halves the per-round gain while preserving round-one health and each type's multiplier; final unit HP still rounds up, with a minimum of one. Regular enemies, sends, summons, Sandbox, accepted previews, and Orcieary derive from the same admitted rules.

| Round | Ordinary Orc HP |
| --- | ---: |
| 1 | 8 |
| 10 | 17 |
| 40 | 47 |
| 100 | 107 |

The boss debuts with **1410 HP**. Normal NecOrcmancer movement is also reduced from 0.55× to **0.50×** baseline, about 9% slower; the boss remains **0.30×**. Ability timing, ordinary sends/unlocks, and the movement growth curve are unchanged.


## Movement progression

Movement no longer gains a fixed 0.15 cells/second every round. `CombatRules.speed_growth_fraction = 0.1` and `speed_growth_rounds = 5` define additive milestones: the first extra 10% of original speed takes five completed rounds, the next ten, the next fifteen, then twenty, and so on. Growth is interpolated within each span, so enemies do not suddenly jump in speed at a milestone. It neither compounds nor resets the baseline between spans.

| Round | Ordinary Orc speed (cells/s) | Increase over initial speed |
| --- | ---: | ---: |
| 1 | 2.00 | 0% |
| 6 | 2.20 | 10% |
| 16 | 2.40 | 20% |
| 31 | 2.60 | 30% |
| 51 | 2.80 | 40% |
| 101 | 3.17 | 58.33% |

`CombatRules.enemy_speed_at_wave` owns the curve. Match simulation, paid/regular deliveries, next-round previews, Sandbox, and Orcieary use it; an admitted host model retains its captured settings even if local source resources change. Type multipliers, HP growth, weights/counts, irregular spawn cadence, ability clocks, and 1×/2×/3× playback remain independent. The boss/normal caster multipliers above do not change this deliberately restrained growth curve; sustained late-round pressure still needs friend playtests.


## Presentation

All eight enemies use elevated three-quarter pixel art with distinct faces/anatomy and twelve-frame walk/death animations; Chief healing and both NecOrcmancer tiers have separate anticipation/action/recovery poses. The basic **Orc** uses the creator-approved 64×64 GameLab design, losslessly padded onto its existing 80×80 frame canvas. Local cutout articulation preserves that face, clothing and cleaver through walking and collapse; conservative articulation cannot reveal unseen anatomy. `archive_assets/enemies/grunt/gamelab-20261018/derive_runtime.py` reproduces it, with sources, previous artwork and derivations archived beside it. `tools/author_enemy_sprites.py` preserves this accepted Orc and reproduces the remaining six original enemy sheets/stills. `tools/author_necorcmancer_mancer.py` separately authors the boss on a 128×128 canvas. Per-enemy JSON files in `assets/enemies/animations/` record derivation, bounds and hashes. The Orc replacement retains gameplay stats and animation timing. An isolated actual-main-scene X11/Mesa walkthrough exercised live walking and confirmed deaths at supported widths and mirrored orientations; captures were inspected. Native GPU/performance and physical input feel remain unverified.
Every enemy also has a twelve-frame, 0.8-second death animation. Living Orcs collapse with a small dark-red ground splatter; SkeleOrcs scatter into loose bones without blood. The host publishes short-lived, uniquely numbered confirmed-kill events; clients cannot manufacture damage, rewards, or new living enemies from them. Fallen bodies/bones linger briefly, fade, and are never selectable or targetable. Repeated snapshots cannot replay expired deaths. Playback respects simulation speed and explicit pause, but the final death can finish after wave clearance. Debug/map resets invalidate stale-coordinate effects.

## Orcieary and lifetime records

Open **Orcieary** from the main menu or press **B** there. Entries are ordered by earliest regular/send availability, with summoned-only types inheriting their summoner's earliest availability; ties use send/regular availability and stable IDs. The canonical content catalog is not reordered. Each entry shows encounter/send availability, description, portrait, base stats/scaling, mechanics, and lifetime killed/sent counts. Click the portrait, or focus it and press Enter/Space, to play its walk cycle or special action once and return to rest. Repeat activation restarts playback; selection changes clear it, and hidden previews do not run. Arrows navigate entries; Tab/Shift-Tab move between list, portrait, and Back; Escape returns.

The boss entry shows actual round-40 debut stats, weight, later encounter odds, and no paid-send price/income. Other entries retain their wave-one baseline. Its longer identity and mechanics remain usable at both supported desktop widths without visible scrollbar chrome.


`EnemyStatisticsStore` atomically saves `user://enemy_statistics.json`. Accepted cumulative per-side totals carry a unique model/match ID. Durable high-water marks make repeated, stale, reconnected, or restarted observations idempotent; the owned slot is bound for each ID, avoiding mirrored-solo/opponent duplication. Actual tower kills count; leaks/rejected sends do not. Sent groups count individuals. Sandbox never records progression. Invalid saves are not silently replaced; failures are shown in Orcieary and retried only from cumulative accepted state without granting phantom counts. This is a trusted local save, not account-backed anti-cheat.

## Sandbox

**Sandbox** replaces Workshop; **S** opens it from the menu. It owns a separate model, path layout, camera, and paused menu-return state. All catalog towers and enemies are available without unlocking anything. Purchases/upgrades are genuinely free; lives cannot be lost. Sandbox does not edit collection saves or lifetime records.

- Paint/erase paths with left/right drag while stopped; tiles have no spending budget.
- Buy, inspect, target, upgrade, and sell the same real tower types/evolutions used in matches. **Build another [B]** selects the inspected tower's base identity, not a copy of its upgrades or traits.
- Dragging previews the tower's actual base artwork translucently on the hovered tile, with baseline range cells and red invalid-ground feedback. It closes any tower/enemy inspector immediately. Escape cancels only the drag; ordinary accepted drops inspect the new tower, while Shift-drop keeps building.
- Choose a round and start its weighted wave, or choose any enemy and exact count, including SkeleOrcs.
- Space starts or toggles pause; choose 1×/2×/4× playback or cycle it with **F**. Stop/clear removes enemies and unlocks editing while retaining the build.
- **Restart [R]** repeats the last accepted weighted wave or exact Spawn batch, clearing old enemies/queued spawns and running immediately. It keeps towers, upgrades, rolls, targeting, speed, current route, and selected round. Weighted retries roll a new regular roster; exact retries repeat only the last accepted type/count, not a history of mixed additions. Stop and round edits retain the recipe; a disconnected path prevents replay without discarding it. Fields, menus, confirmations, and active drags block keyboard shortcuts.
- Set map width/height and confirm Resize to replace the map/build. Numeric fields accept values beyond their arrow range, subject to machine memory—not an infinite-performance promise.
- Reset build requires confirmation and retains the path. Menu/Escape pauses and preserves the playground. WASD and cursor zoom reuse match camera controls; text entry, selectors, inspectors, and dialogs take input priority.

Enemy stats are scaled to the selected round. Exact-spawn controls create the requested individual count rather than rolling an Orcling group; weighted waves and paid match orders retain grouping. All normal match ownership, funds, readiness, and send-unlock rules stay intact outside the captured sandbox mode.

## Verification

Use the [single-command checks](development.md#single-command-verification). `enemy_mechanics_test.gd` covers unlock boundaries, atomic rolls, grouped budgets/timing, true-radius healing, caps, cast death/leaks, inherited routes, spawn exposure, slow/cast interaction, and sandbox/statistics isolation. `enemy_mechanics_peer_test.gd` uses real separate host/client processes with divergent client resources. Statistics tests cover duplicate/stale snapshots, restart, corruption, atomic failure/retry, accepted kills/sends, and leaks. Sandbox and rendered Orcieary/board tests cover input priority, confirmations, geometry, animations, and hidden-state behavior. Real friend play remains necessary to tune pressure, maze lengths, healing usefulness, and late-wave performance.

The expansion's full `python3 tools/verify.py all` run passed **41/41 checks** (36 suites plus five gates), including separate real host/client processes and rendered tests. A graphical main-scene smoke exercised menu shortcuts, all seven previews at 1000×720/1280×720, native sandbox path drawing, all three free tower branches, mixed exact spawns, paused navigation, and confirmed 40×24 resizing. A separate real simulation captured Chief healing, stationary staff casting, and living summoned children. A normal match UI smoke recorded three accepted Orcling sends and five actual Orcling kills, displayed them in Orcieary, and reloaded the same saved totals. Smoke resources/saves/scripts were isolated and removed; automated checks do not establish competitive balance or internet reachability.

The portrait/order/art/death revision passed **43/43 project checks**, including real host/client kill-event replication and rendered corpse/blood cleanup. Native portrait clicks were exercised for every sorted entry at 1000×720 and 1280×720. Actual sandbox kills rendered each collapse, bloodless SkeleOrc bone heap, and expiry, including the final death after automatic wave clearance. The reversed grounded/airborne gait was corrected and numerically audited for source-left and mirrored-right before in-game inspection. A clipped Brute collapse frame was corrected; all 192 exported frames retain transparent margins. These checks validate behavior and readability, not objective aesthetic perfection.

The diminishing movement revision passed **49/49 project checks**, including boundary/rate assertions, additive versus compounded milestones, configurable baseline/span/fraction, regular and paid movement, captured-source protection, and separate real host/client agreement with intentionally different client progression. A rendered game smoke inspected live enemies at rounds 1, 6, 16, 31, 51 and 101 and verified Sandbox selected-round speeds against the same owner. At round 101 the ordinary Orc's live inspector displayed 3.17 cells/second. Health, group/count budgets, economy, and spawn cadence were intentionally unchanged.
