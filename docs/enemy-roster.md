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
| Trollorc | 180 | 0.09 | 10 | 60, then occasional | Never | 60 | 65% | — |
| Orc king war orchine | 450 | 0.07 | 10 | 100, then occasional | Never | 100 | 75% | — |
| SkeleOrc | 0.5 | 1.05 | 1 | Summoned only | Not purchasable | Not in regular roster | — | — |

The first five rounds allow only Orcling sends. Each later send unlock trails the next regular threat tier; the final NecOrcmancer send unlock is deliberately delayed until round 46, as chosen by the creator. UI previews and command validation use the same accepted gate. Earlier-round debug jumps relock later sends. SkeleOrcs remain available directly in sandbox.

Orclings roll two/three/four members with 60/30/10 weights. Members arrive 0.065 simulation seconds apart; the next ordinary event waits its full normal cooldown after the last member. One paid order charges once, awards income once, and records the actual individual members sent. Rejection rolls nothing and spends nothing. Both boards receive the same host-generated regular groups/timetable. Individual Orclings award one Coin, limiting the horde's bounty advantage.

Chiefs begin at one regular selection per wave; the cap grows by one every ten waves after introduction. Every five simulation seconds a Chief heals **other living allies** inside a true circular 1.6-cell radius for 4% of each ally's maximum HP, rounded up with a one-HP minimum and capped at maximum health. No self-heal, resurrection, or square-range substitute. A brief raised-palm pose and green pulse mark the actual heal.

NecOrcmancers begin at one regular selection per wave; the cap grows by one every twelve waves after introduction. Every seven simulation seconds the caster stops for a 1.15-second staff-raising ritual, then raises two to four SkeleOrcs, limited to six living children per caster. Children inherit the caster's captured route and current progress instead of returning to the portal. A dead/leaked caster cannot finish its ritual. Living children still have to clear before the wave ends. SkeleOrcs have no kill bounty, preventing summon farming. Freeze slows movement, not the simulation ability clock; casting is stationary even while a slow expires. Two-times playback accelerates all of these simulation clocks consistently.

**NecOrcmancer Mancer** (`necorcmancer_mancer`) is a separate boss, never a paid send. One is guaranteed on round 40: its 40 weight is reserved before ordinary selections from that round's 84-weight budget. Later waves roll once for an encounter, starting at 5% on round 41 and gaining 0.5 percentage points per round, capped at 25% from round 81 onward. At most one of this type appears per wave, still respecting budget/share limits; it may coexist with both other boss types later. These encounter odds and combat values are provisional tuning.

The boss uses the same seven-second / 1.15-second ritual, but raises **two to four ordinary NecOrcmancers**, capped at six living direct children. Those NecOrcmancers retain their own stats, bounty, and SkeleOrc rituals; newborn casters start their clocks at birth and cannot cascade a cast immediately. Every generation inherits its parent's captured route/current progress, and all descendants must clear before the wave ends. Catalog validation permits acyclic summon chains and rejects self/indirect cycles. The boss pays 40 Coins when killed; SkeleOrcs retain zero normal Coin bounty.

## Varied regular enemies

These four roles join the existing roster progressively. All are available directly in Sandbox and fully animated in Orcieary. Their count/share caps and rewards remain provisional playtest tuning.

| Enemy | Regular / Send round | HP / Speed multiplier | Weight / share | Send Coins / income | Gimmick |
| --- | --- | --- | --- | --- | --- |
| Scrapguard | 9 / 16 | 2 / 0.8 | 3 / 30% | 35 / +3 | Physical damage ×0.5; elemental damage stays normal. |
| CrateOrc | 18 / 28 | 2.2 / 0.7 | 5 / 25% | 50 / +3 | A confirmed death releases exactly two individual Orclings. |
| RageOrc | 28 / 40 | 3.5 / 0.8 | 7 / 30% | 80 / +4 | First surviving hit to ≤50% HP permanently multiplies speed by 1.6. |
| MossOrc | 52 / 66 | 6 / 0.55 | 12 / 20% | 120 / +5 | Regenerates 8% of maximum HP every four simulation seconds. |

Crate children inherit the captured parent route/current progress, start fresh at birth, keep ordinary Orcling rewards, and prevent clearance. Tower kills award the crate bounty once; collateral death releases children without awarding the player; leaks release none. Combined summon/death-child graphs reject missing references, boss children, and cycles.

Rage composes with slows and casting restrictions without multiplying twice or reverting after healing. Its accepted flag selects the faster `walk_enraged` artwork; changing speed cannot rewrite earlier movement in the same tick. Moss heals only itself, rounds each heal up, caps at maximum HP, never resurrects, and uses a birth-relative simulation clock. Its green action pose marks actual healing; pause/playback affect its clock normally.

## First boss kill loot

Each player earns one bonus for the **first tower-owned kill of each boss type in a run**. The host rolls independently using the same authored rarity weights as tower placement, then immediately credits both currencies. Ordinary bounty/Shard drops still apply separately. Repeated encounters, leaks, collateral deaths, and Sandbox cannot claim the bonus or consume its RNG. Debug round jumps preserve claims; a new run resets them. Rewards are run-only, not lifetime progression.

| Tier | Weight | Base Coins | Base Shards |
| --- | ---: | ---: | ---: |
| Broken | 8 | 50 | 1 |
| Shoddy | 13 | 80 | 2 |
| Common | 35 | 140 | 4 |
| Uncommon | 26 | 240 | 7 |
| Rare | 12 | 420 | 12 |
| Epic | 4.5 | 800 | 22 |
| Legendary | 1.3 | 1600 | 40 |
| Mythic | 0.2 | 4000 | 100 |

Multiply each base payout by `max(1, kill_round / 40)` and round upward once. Later bosses are worth more without making higher tiers less rare. `resources/combat/boss_rewards.tres` owns payouts and references the existing tower rarity resource for odds, rather than maintaining a second set.

The existing sound-backed reel shows each tier's scaled payout and the accepted winning total. **Click or Enter skips spinning straight to that result**, for both boss loot and tower rerolls. It cannot alter the roll or grant again. Multiple awards queue behind the shared tower reel; pause/results defer presentation, leaving clears it, and snapshots never replay a seen award. Multiplayer continues while the local overlay is open.


## Late-game bosses

All boss identities are barred from paid sends by the host, independently of their authored send flag. Each type reserves at most one encounter at its guaranteed debut, then rolls its own occasional later encounter; total weight/share rules still apply. Both new bosses are available directly in Sandbox and have debut-scaled Orcieary entries. Numeric balance below is provisional until real friend playtests.

| Mechanic | Trollorc | Orc king war orchine |
| --- | ---: | ---: |
| Debut HP | 12,060 at round 60 | 48,150 at round 100 |
| Later encounter chance | 4% + 0.3 percentage points/round, capped at 18% | 2.5% + 0.2 percentage points/round, capped at 12% |
| Tower attack interval | 25 simulation seconds | 12 simulation seconds |
| Attack targeting | Nearest within 2.4 cells | Two distinct random towers anywhere on its board |
| Wind-up | 1.25 seconds | 1.4 seconds |
| Tower stun | 30 seconds | 8 seconds |
| Kill Coins / guaranteed Shards | 100 / 8 | 250 / 16 |

**Trollorc** (`troll`): a huge, very slow club bearer. Plain physical damage remains normal; magic, fire, lightning, explosions, and ice deal **1.5×** damage. Direct hits compose that multiplier once with bounty vulnerability; continuous damage/burn apply it before whole-HP accumulation, never by rounding every small tick. Fire-arrow shafts remain physical while their burns are fire; unenhanced Boulders are physical, Freeze Boulders use the ice damage category, and Onyx is magic. Existing SkeleOrc immunity behavior is unchanged: ice immunity blocks slow, not Boulders' HP damage; fire immunity blocks burns/Flamethrower rather than retroactively removing projectile impact.

While walking, each heavy step every **2.4 simulation seconds** damages **other living enemies within a circular 1.1-cell radius** for **8% of their maximum HP**. These collateral deaths grant no tower kills, Coins, Shards, or player lifetime kills. Trollorc periodically winds up and slams the nearest in-range tower; ties are stable, the attack is cancelled by death/leak, and a completed hit shows orbiting cartoon stars. A single tower can remain locked down by repeated club swings, so spread defenses rather than relying on one firing position.

**Orc king war orchine** (`orc_war_machine`): a crewed timber/iron siege engine with a crowned king, twin cannons, and rear troop doors. It follows the same captured shortest painted route as ordinary enemies, on wheels, never choosing a direct grass shortcut. Every **18 simulation seconds**, subject to finishing a current action, it rolls a forward **2–5-route-tile** jump with respective **45 / 35 / 15 / 5** weights. Only lengths fitting the remaining route are eligible; fewer than two tiles means no jump. It deploys legs for **0.6 seconds**, crouches for **2.5**, flies for **1.5**, lands/retracts for **0.65**, then resumes wheels. Logical progress traverses the captured route; the visible flight arcs between accepted endpoints. A base landing finishes before leaking. Cannons roll up to two distinct existing towers anywhere on that board; sold targets are not replaced mid-windup. Fire deals **1.2×**, lightning **0.9×**, and all other damage remains normal, composing once with bounty vulnerability before fractional accumulation.

Every **8 seconds**, a **1.2-second** door-opening action releases **4–7** host-rolled troops, capped at **24 living direct children**. Orcling / Orc / Runner weights remain **8 / 1 / 1** per child. Troops inherit the carrier's captured painted route and current progress; all children still prevent wave clearance. Artwork exposes intact, damaged, and critical states at **66% / 33%** remaining HP across wheels, cannons, doors and every jump phase.

**Stun ownership:** the host owns `stunned_remaining` and every impact. Stuns refresh nonstackingly and suspend every tower role: fresh discrete/continuous attacks and firing streaks, emitted support buffs, mine production/round-clear payout, bounty marks, and income auras. Periodic production clocks freeze without accumulating catch-up income. Recovery restores eligible effects immediately, with strongest-duplicate stacking preserved. Already-applied burns keep ticking. Timers use simulation time, respecting pause and playback speed; reset/abandoned rounds clear status. Camera, stars, projectiles, and sound never decide outcomes. Display-name changes preserve the stable `troll` / `orc_war_machine` IDs and records.


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

All fourteen enemies use elevated three-quarter pixel art with distinct silhouettes and authored walk/death animations. The approved GameLab Orc and existing boss artwork remain unchanged. `tools/author_variety_enemies.py` reproducibly authors the four new 80×80 hard-alpha sheets/stills, twelve-frame walks/deaths, Rage's faster `walk_enraged`, and Moss's 0.55-second heal action. Existing generators and archived source provenance remain the owners of earlier enemies. Fixed foot anchors and frame-zero stills are shared by battlefield/guide picking and rendering; per-enemy JSON records bounds and hashes. No paid service or external generator was used for the four new enemies.
Every enemy has an authored collapse/debris animation: the original roster uses 0.8 seconds, while the two late bosses use weightier 1.2-second, twelve-frame collapses. Living Orcs/Trollorc leave a small dark-red blood splatter; SkeleOrcs scatter into bloodless bones and Orchine breaks into bloodless debris. The host publishes short-lived, uniquely numbered confirmed deaths; clients cannot manufacture damage, rewards, or new living enemies from them. Fallen bodies/effects fade and are never selectable or targetable. Repeated snapshots cannot replay expired deaths. Playback respects simulation speed and explicit pause, but the final death can finish after wave clearance. Debug/map resets invalidate stale-coordinate effects.

## Orcieary and lifetime records

Open **Orcieary** from the main menu or press **B** there. Entries are ordered by earliest regular/send availability, with summoned-only types inheriting their summoner's earliest availability; ties use send/regular availability and stable IDs. The canonical content catalog is not reordered. Each entry shows encounter/send availability, description, portrait, base stats/scaling, mechanics, and lifetime killed/sent counts. Click the portrait, or focus it and press Enter/Space, to play its walk cycle or special action once and return to rest. Repeat activation restarts playback; selection changes clear it, and hidden previews do not run. Arrows navigate entries; Tab/Shift-Tab move between list, portrait, and Back; Escape returns.

Boss entries show their actual debut-round stats, weight, later encounter odds, and no paid-send price/income. Other entries retain their wave-one baseline. Long identities/mechanics use the existing focus-following, chrome-free scrolling at both supported desktop widths. Machine portrait playback demonstrates attacks, troop doors, legs, charged jumps, and damaged/critical poses using the battlefield's frame owner.


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
