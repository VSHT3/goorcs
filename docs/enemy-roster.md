# Enemy roster and sandbox

Orcieary groups names into **Basic** (white), **Elite** (purple), and **Boss** (red), including the selected detail heading. Basic contains Orcling, Orc, Runner, Brute, Skeltorc and Giant Skeltorc. Elite contains Scrapguard, CrateOrc, Orc Chief, RageOrc, NecOrcmancer, MossOrc and KamikaOrc. The three existing bosses retain Boss classification. `EnemyDefinition.elite` is presentation metadata; the existing `boss` flag takes precedence. Encounter order is preserved within each group, and headings do not interrupt keyboard navigation. Classification changes no stats, rewards or spawning rules.

Category verification: existing rendered Orcieary and headless navigation suites passed. A real main-scene walkthrough checked all fourteen name colors across normal/hover/selected/focused states, native keyboard crossing between groups, duplicate-free reconfiguration, and inspected **1000×720 / 1280×720** captures. Its functional assertions passed, but shutdown reported retained `menu_click.wav` playback resources; no clean main-scene exit is claimed. Evidence: `.verify-logs/gorcs-verify-enemy-categories-4ef5803fe0814a92a62b9eb99ce2fd68/`.

## Rules and provisional balance

All abilities, group rolls, sends, damage, healing, summons, and counters belong to `MatchCombat` on the host. Clients render accepted state. These values establish distinct roles and a gradual introduction; they are not a claim of competitive balance without friend playtests.

Health and movement use the existing wave-scaled baseline in `CombatRules`: each definition supplies a multiplier. Each leaking unit deals its own base damage. Regular selection spends weight per event/group, not per Orcling; count/share caps count those events. Ordinary enemy bounty uses the match rule unless a definition overrides it.

| Enemy | HP multiplier | Speed multiplier | Base damage | Regular wave | Send wave | Weight | Max weight share | Send price / income |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Orcling | 0.5 | 0.9 | 1 | 1 | 1 | 1 per group | 35% | 12 / +1 per group |
| Orc (`grunt`) | 1 | 1 | 1 | 1 | 6 | 1 | 100% | 20 / +2 |
| Runner | 0.6 | 1.7 | 1 | 6 | 12 | 2 | 30% | 25 / +2 |
| Brute | 2.5 | 0.65 | 3 | 12 | 22 | 5 | 35% | 40 / +4 |
| Orc Chief | 6 | 0.5 | 5 | 22 | 34 | 12 | 25% | 130 / +5 |
| NecOrcmancer | 5 | 0.5 | 3 | 34 | 46 | 15 | 25% | 140 / +6 |
| NecOrcmancer Mancer | 30 | 0.3 | 8 | 40, then occasional | 60 | 40 | 50% | 7,500 / −100 |
| Trollorc | 180 | 0.09 | 10 | 60, then occasional | 80 | 60 | 65% | 20,000 / −300 |
| Orc king war orchine | 450 | 0.07 | 10 | 100, then occasional | 120 | 100 | 75% | 50,000 / −1,000 |
| Skeltorc | 0.5 | 1.05 | 1 | Summoned only | Not purchasable | Not in regular roster | — | — |
| Giant Skeltorc | 50× rounded Skeltorc HP | 0.84 | 1 | 1% Skeltorc births from 151 | Not purchasable | Not in regular roster | — | — |
| KamikaOrc | 0.35 | 1.1 | 2 | 80 | 100 | 8 | 12% | 200 / +8 |

The first five rounds allow only Orcling sends. Each later send unlock trails its regular threat tier; the ordinary NecOrcmancer send unlock is deliberately delayed until round 46. UI previews and command validation use the same accepted gate. Earlier-round debug jumps relock later sends. Skeltorcs and Giants remain available directly in Sandbox.

Boss orders pay both the listed Coin price and the full recurring-income penalty immediately and atomically. A sender with too little of either cannot order; income never becomes negative or gets silently clamped. The loss persists through later clears until ordinary sends rebuild income. Mirrored Singleplayer validates both balances before spending or rolling. Each order queues exactly one boss through the existing paced opponent FIFO; regular encounter count/share limits do not cap paid orders. Planning/Ready/terminal restrictions remain unchanged, and a first actual paid-boss kill remains eligible for the existing first-kill loot. All send tuning is provisional.

Orclings roll two/three/four members with 60/30/10 weights. Members arrive 0.065 simulation seconds apart; the next ordinary event waits its full normal cooldown after the last member. One paid order charges once, awards income once, and records the actual individual members sent. Rejection rolls nothing and spends nothing. Both boards receive the same host-generated regular groups/timetable. Individual Orclings award one Coin, limiting the horde's bounty advantage.

Chiefs begin at one regular selection per wave; the cap grows by one every ten waves after introduction. Every five simulation seconds a Chief heals **other living allies** inside a true circular 1.6-cell radius for 4% of each ally's maximum HP, rounded up with a one-HP minimum and capped at maximum health. No self-heal, resurrection, or square-range substitute. A brief raised-palm pose and green pulse mark the actual heal.

NecOrcmancers begin at one regular selection per wave; the cap grows by one every twelve waves after introduction. Every seven simulation seconds the caster stops for a 1.15-second staff-raising ritual, then raises two to four Skeltorcs, limited to six living direct children per caster. Children inherit the caster's captured route and current progress instead of returning to the portal. A dead/leaked caster cannot finish its ritual. Living children still have to clear before the wave ends. Skeltorcs have no kill bounty, preventing Coin farming. Freeze slows movement, not the simulation ability clock; casting is stationary even while a slow expires. Two-times playback accelerates these simulation clocks consistently.

**NecOrcmancer Mancer** (`necorcmancer_mancer`) is a separate boss with a late-game paid send. One regular encounter is guaranteed on round 40: its 40 weight is reserved before ordinary selections from that round's 84-weight budget. Later waves roll once for an encounter, starting at 5% on round 41 and gaining 0.5 percentage points per round, capped at 25% from round 81 onward. At most one regular encounter of this type appears per wave, still respecting budget/share limits; it may coexist with both other boss types and additional paid orders later. These encounter odds and combat values are provisional tuning.

The boss uses the same seven-second / 1.15-second ritual, but raises **two to four ordinary NecOrcmancers**, capped at six living direct children. Those NecOrcmancers retain their own stats, bounty, and Skeltorc rituals; newborn casters start their clocks at birth and cannot cascade a cast immediately. Every generation inherits its parent's captured route/current progress, and all descendants must clear before the wave ends. Catalog validation permits acyclic summon/variant chains and rejects self/indirect cycles. The boss pays 40 Coins when killed; Skeltorcs retain zero normal Coin bounty.

### Giant Skeltorcs and KamikaOrcs

**Skeltorc** is the canonical display name. The stable `skeleorc` ID, source artwork paths and lifetime-save keys remain unchanged; no save migration or duplicate identity is introduced.

From **round 151**, each newly born Skeltorc independently rolls **1%** to become **Giant Skeltorc**. The host's separate variant RNG runs at the common birth owner for rituals, nested/death-spawn children, custom sources and Sandbox births; unrelated/below-gate births do not roll. An existing unit transferred by Orcapult never rerolls. Giant replacement preserves the single enemy ID allocation, summoner, exact route/progress, birth time and direct-child limit. HP is **50× the normal already-rounded Skeltorc HP**, speed is **80%** of normal. Fire/ice immunity, immunity to burning/the entire Flamethrower/Freeze slow, bloodless death, base damage, zero Coin bounty and the normal 4%/one-Shard drop remain unchanged.

The Giant carries a bomb on its back. Confirmed death drops one bomb on its **same-board rounded death tile**, lights a **two-simulation-second fuse**, then applies a **three-second nonstacking stun** to living enemies and towers within **two Chebyshev tiles**, including diagonals. It deals no damage, grants no extra Coins, and never crosses the ravine. Enemy movement, animation and ability/cast/jump clocks freeze; existing burns continue. Tower stun suspends attacks, support, marking and production through the existing owner. Expiry resumes only the post-stun portion of a coarse tick. New enemies present at the blast can be stunned; later births are not inside a persistent aura. Pending fuses hold wave completion. Leaks, transfers, debug/reset and terminal cleanup cannot detonate/drop a bomb.

**KamikaOrc** is a low-HP powder carrier introduced at regular round **80**, initially capped at two per wave, gaining one cap every 20 rounds under its 12% weight share. Its first **ten positive damaging contacts** each consume one shield charge and absorb the entire hit; the tenth has no overflow. Blocked contacts grant no damage/kill/reward credit and cannot ignite or freeze. Continuous weapons consume one charge per source's accepted attack interval of positive exposure, not per frame or per accumulated integer HP; zero-interval continuous Rune branches use their original attack cadence divided by accepted speed modifiers. Only post-protection exposure accrues damage/statuses. Confirmed death immediately stuns same-board towers within **one Chebyshev tile** for **three seconds**; leaks never do. Paid sends unlock at round 100. All authored balance is provisional.


## Varied regular enemies

These five roles join the existing roster progressively. All are available directly in Sandbox and fully animated in Orcieary. Their count/share caps and rewards remain provisional playtest tuning.

| Enemy | Regular / Send round | HP / Speed multiplier | Weight / share | Send Coins / income | Gimmick |
| --- | --- | --- | --- | --- | --- |
| Scrapguard | 9 / 16 | 2 / 0.8 | 3 / 30% | 35 / +3 | Physical damage ×0.5; elemental damage stays normal. |
| CrateOrc | 18 / 28 | 2.2 / 0.7 | 5 / 25% | 50 / +3 | A confirmed death releases exactly two individual Orclings. |
| RageOrc | 28 / 40 | 3.5 / 0.8 | 7 / 30% | 80 / +4 | First surviving hit to ≤50% HP permanently multiplies speed by 1.6. |
| MossOrc | 52 / 66 | 6 / 0.55 | 12 / 20% | 120 / +5 | Regenerates 8% of maximum HP every four simulation seconds. |
| HeavyDutyOrc | 30 / 40 | 9 / 0.4 | 10 / 25% | 110 / +4 | Slowest regular orc; industrial plate takes Physical ×0.5 and every other element ×0.9; leaks for 6. |

Crate children inherit the captured parent route/current progress, start fresh at birth, keep ordinary Orcling rewards, and prevent clearance. Tower kills award the crate bounty once; collateral death releases children without awarding the player; leaks release none. Combined summon/death-child graphs reject missing references, boss children, and cycles.

Rage composes with slows and casting restrictions without multiplying twice or reverting after healing. Its accepted flag selects the faster `walk_enraged` artwork; changing speed cannot rewrite earlier movement in the same tick. Moss heals only itself, rounds each heal up, caps at maximum HP, never resurrects, and uses a birth-relative simulation clock. Its green action pose marks actual healing; pause/playback affect its clock normally.

## Elements and Elemental Orcs

Every tower attack belongs to one of five elements: **Physical** (Arrow, Ballista, Boulders, Orcapult slam), **Fire** (Molotov, Flamethrower, and explosive grenade/rocket splash), **Ice** (Freeze Runes), **Lightning** (Lightning tower, Storm Sigil) and **Magic** (Rune pulses, Onyx Ring, Void Monolith, Magic Ballista). The HUD and Towerieary name each attacking tower's current element. New towers pick one of these five rather than adding a new element.

An enemy listed as immune to an element takes no damage from it. Single-target towers skip it, and chain jumps, bounces and Void tendrils never land on it, so they keep working on what they can hurt. Area pulses and splash still pass over it harmlessly. The Orcapult can still throw it.

| Enemy | Regular / Send round | HP / Speed multiplier | Weight / cap | Send Coins / income | Gimmick |
| --- | --- | --- | --- | --- | --- |
| Ember Orc | 10 / 16 | 1.3 / 1.0 | 2 / 1 (+1 per 30 rounds) | 30 / +2 | Immune to Fire (including explosions); never burns. |
| Frost Orc | 13 / 19 | 1.4 / 0.9 | 2 / 1 (+1 per 30 rounds) | 30 / +2 | Immune to Ice; never slowed. |
| Storm Orc | 15 / 21 | 1.2 / 1.15 | 2 / 1 (+1 per 30 rounds) | 30 / +2 | Immune to Lightning. |
| Arcane Orc | 17 / 23 | 1.3 / 1.0 | 2 / 1 (+1 per 30 rounds) | 30 / +2 | Immune to Magic. |
| EleMetal Orc | 20 / 26 | 1.6 / 0.75 | 3 / 1 (+1 per 30 rounds) | 40 / +3 | Heavy full-body iron plate: immune to Physical, takes 50% more Lightning. |
| Omega Elemental Orc (elite) | 38 / 48 | 4 / 0.7 | 12 / 1 (+1 per 20 rounds) | 90 / +5 | Immune to Fire, Ice, Lightning and Magic; only Physical hurts it. |

Together the Elemental Orcs make up about a fifth of a mid-game wave and a quarter late on: enough to punish a single-element defence without replacing the horde.

## ShaOrcs

| Enemy | Regular / Send round | HP / Speed multiplier | Weight / cap | Send Coins / income | Gimmick |
| --- | --- | --- | --- | --- | --- |
| ShaOrc | 24 / 32 | 2 / 0.6 | 5 / 2 (+1 per 10 rounds) | 60 / +3 | Every 6 s raises its staff: heals other orcs within 2 cells for 15% of their maximum HP and restores its own one-hit shield. |
| Greater ShaOrc (elite) | 60 / 72 | 7 / 0.5 | 30 / 1 (+1 per 20 rounds) | 400 / +8 | Every 12 s wards every other non-boss orc within 3.5 cells: immune to all damage for 10 s. |

**OrcShakra.** Each other living ShaOrc within 3 cells charges a ShaOrc's cast faster, with diminishing returns: +20%, +30%, +35%, +37.5% for one to four neighbours, approaching +40% (`shakra_max_bonus * (1 - 0.5^n)`). The charge is integrated on the simulation clock, so a ShaOrc that walks into a group speeds up from that moment.

**Wards.** Warded orcs show a faint pale-cyan hexagon (unlike the gold hit-shield pips) that flickers in its last two seconds; towers ignore them. A Greater ShaOrc never wards itself or another Greater ShaOrc, and every ward it cast ends the moment it dies, leaks or is thrown off the board, so killing it is the answer.

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

All bosses have late-game paid sends with high Coin prices and recurring-income penalties, listed above. Regular encounters still reserve at most one of each type at its guaranteed debut, then roll occasional later encounters under the normal weight/share rules; paid orders use the independent send FIFO instead. Bosses remain available directly in Sandbox and have debut-scaled Orcieary entries. Numeric balance is provisional until real friend playtests.

| Mechanic | Trollorc | Orc king war orchine |
| --- | ---: | ---: |
| Debut HP | 12,060 at round 60 | 48,150 at round 100 |
| Later encounter chance | 4% + 0.3 percentage points/round, capped at 18% | 2.5% + 0.2 percentage points/round, capped at 12% |
| Tower attack interval | 25 simulation seconds | 12 simulation seconds |
| Attack targeting | Nearest within 2.4 cells | Two distinct random towers anywhere on its board |
| Wind-up | 1.25 seconds | 1.4 seconds |
| Tower stun | 30 seconds | 8 seconds |
| Kill Coins / guaranteed Shards | 100 / 8 | 250 / 16 |

**Trollorc** (`troll`): a huge, very slow club bearer. Plain physical damage remains normal; magic, fire, lightning, explosions, and ice deal **1.5×** damage. Direct hits compose that multiplier once with bounty vulnerability; continuous damage/burn apply it before whole-HP accumulation, never by rounding every small tick. Fire-arrow shafts remain physical while their burns are fire; unenhanced Boulders are physical, Freeze Boulders use the ice damage category, and Onyx is magic. Existing Skeltorc immunity behavior is unchanged: ice immunity blocks slow, not Boulders' HP damage; fire immunity blocks burns/Flamethrower rather than retroactively removing projectile impact.

While walking, each heavy step every **2.4 simulation seconds** damages **other living enemies within a circular 1.1-cell radius** for **8% of their maximum HP**. These collateral deaths grant no tower kills, Coins, Shards, or player lifetime kills. Trollorc periodically winds up and slams the nearest in-range tower; ties are stable, the attack is cancelled by death/leak, and a completed hit shows orbiting cartoon stars. A single tower can remain locked down by repeated club swings, so spread defenses rather than relying on one firing position.

**Orc king war orchine** (`orc_war_machine`): a crewed timber/iron siege engine with a crowned king, twin cannons, and rear troop doors. It follows the same captured shortest painted route as ordinary enemies, on wheels, never choosing a direct grass shortcut. Every **18 simulation seconds**, subject to finishing a current action, it rolls a forward **2–5-route-tile** jump with respective **45 / 35 / 15 / 5** weights. Only lengths fitting the remaining route are eligible; fewer than two tiles means no jump. It deploys legs for **0.6 seconds**, crouches for **2.5**, flies for **1.5**, lands/retracts for **0.65**, then resumes wheels. Logical progress traverses the captured route; the visible flight arcs between accepted endpoints. A base landing finishes before leaking. Cannons roll up to two distinct existing towers anywhere on that board; sold targets are not replaced mid-windup. Fire deals **1.2×**, lightning **0.9×**, and all other damage remains normal, composing once with bounty vulnerability before fractional accumulation.

Every **8 seconds**, a **1.2-second** door-opening action releases **4–7** host-rolled troops, capped at **24 living direct children**. Orcling / Orc / Runner weights remain **8 / 1 / 1** per child. Troops inherit the carrier's captured painted route and current progress; all children still prevent wave clearance. Artwork exposes intact, damaged, and critical states at **66% / 33%** remaining HP across wheels, cannons, doors and every jump phase.

**Stun ownership:** the host owns `stunned_remaining` and every impact. Stuns refresh nonstackingly and suspend every tower role: fresh discrete/continuous attacks and firing streaks, emitted support buffs, mine production/round-clear payout, bounty marks, and income auras. Periodic production clocks freeze without accumulating catch-up income. Recovery restores eligible effects immediately, with strongest-duplicate stacking preserved. Already-applied burns keep ticking. Timers use simulation time, respecting pause and playback speed; reset/abandoned rounds clear status. Camera, stars, projectiles, and sound never decide outcomes. Display-name changes preserve the stable `troll` / `orc_war_machine` IDs and records.


### Wraithorc (round 120)

`wraithorc` is a late elite shade: **7×** HP, **0.75×** speed, **4** leak damage, weight 14 (one per wave, +1 every 20 rounds), sends from round 135 for 160 Coins. Every **3 s** it switches between solid and ethereal; while ethereal it is drawn translucent and **Physical and Fire deal nothing**, so towers of those elements switch targets until it turns solid again. Lightning, Ice and Magic always hurt it. The phase follows its own simulation clock (`phase_interval`, `phase_immune_elements`).

### Grand Mage Orcafus (round 140)

`grand_mage_orcafus` is a mid-sized gliding archmage: **100×** HP, **0.3×** speed, silent **0.25% max-HP regeneration every 2 s**, and immune to **Fire, Ice and Magic** (only Physical and Lightning hurt him). His debut is guaranteed at **round 140**; afterwards he rolls **5% + 0.6 points per round, up to 50%**, so he becomes a regular sight in late waves. Paid sends unlock at round 160 for **30,000 Coins / −600 income**.

He glides **1.4 s**, then stops for the next castable spell of his `spellbook` rotation, spending most of his time standing still and casting:

| Spell | Cast | Effect |
| --- | --- | --- |
| Nullify | 2.5 s immune channel + 0.6 s strike | Immune to all damage while channelling; the staff strike silences every **Magic** tower on his board for **8 s** (no shots, pulses or tendrils). A crossed sigil marks silenced towers and a violet border frames the arena. |
| Fireball | 1.4 s windup | Aimed at a random tower; stuns towers within **1.6 cells** of the impact for **4 s**. |
| Portal | 2.4 s | Pulls the **10 rearmost** non-boss orcs to just in front of him. |
| Haste | 1.8 s | Orcs within **5 cells** move **40% faster** for **6 s** (refreshes, never stacks). |
| Barrier | 1.8 s | Only below **50% HP**, at most **twice** per life: a **10-hit shield** and **20%** max-HP heal. |

When he dies, his last swing sends a lightning bolt that stuns your **most valuable tower** (highest investment) for **10 s**, then he slowly crumbles to dust.

### Dreadmaw, the Bone Wyrm (round 200)

`dreadmaw` is a colossal skeletal dragon ridden by a lich warlord: **250×** HP, **0.12×** speed, **25** leak damage. Bone takes **60%** of Physical damage, Fire deals **150%**, and it is immune to Ice. Below **50% HP** it enrages and moves **1.3×** faster. Its death spills **8 Skeltorcs**. Debut guaranteed at **round 200**, then **3% + 0.3 points per round, up to 30%**; sends from round 220 for **120,000 Coins / −2,500 income**.

It walks **3 s** between casts:

- **Soulfire Breath** (1.6 s windup): aimed at your densest group of towers; towers within **2.2 cells** are **Withered**, dealing **50% less damage for 8 s** (green flames on the tower).
- **Raise the Fallen** (1.8 s): up to **6** non-boss orcs that died within **5 cells** in the last **12 s** rise again as Skeltorcs where they fell. Risen and summoned orcs never rise twice.

### Boss loot

Every first boss kill now drops **Rare or better** (`minimum_rarity = "rare"` in `boss_rewards.tres`): Rare 67%, Epic 25%, Legendary 7%, Mythic 1%. The reward reel only shows those tiers.

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

All sixteen enemies use elevated three-quarter pixel art and authored walk/death animations. The approved GameLab Orc and existing boss artwork remain unchanged. `tools/author_variety_enemies.py` owns the four earlier variety enemies. `tools/author_kamikaorc.py` authors original hard-alpha powder-carrier walk/death frames; `tools/author_giant_skeltorc.py` derives Giant walk frames from the unchanged skeleton source plus an original backpack bomb, while death frames retain bare skeleton bones. Each generator retains provenance, fixed foot anchors, bounds and hashes; no paid image service was used.
Every enemy has an authored collapse/debris animation: the original roster uses 0.8 seconds, while the two late bosses use weightier 1.2-second, twelve-frame collapses. Living Orcs/Trollorc leave a small dark-red blood splatter; Skeltorcs scatter into bloodless bones and Orchine breaks into bloodless debris. The host publishes short-lived, uniquely numbered confirmed deaths; clients cannot manufacture damage, rewards, new enemies or bomb detonation from corpse playback. Fallen bodies/effects fade and are never selectable or targetable; Giant ground bombs are separate authoritative state. Repeated snapshots cannot replay expired deaths/explosions. Playback respects simulation speed and pause. Debug/map resets invalidate effects even if every corpse already expired.

## Orcieary and lifetime records

Open **Orcieary** from the main menu or press **B** there. Entries are ordered by earliest regular/send availability, with summoned-only types inheriting their summoner's earliest availability; ties use send/regular availability and stable IDs. The canonical content catalog is not reordered. Each entry shows encounter/send availability, description, portrait, base stats/scaling, mechanics, and lifetime killed/sent counts. Click the portrait, or focus it and press Enter/Space, to play its walk cycle or special action once and return to rest. Repeat activation restarts playback; selection changes clear it, and hidden previews do not run. Arrows navigate entries; Tab/Shift-Tab move between list, portrait, and Back; Escape returns.

Boss entries show their actual debut-round stats, weight, later encounter odds, paid-send unlock, Coin price and signed recurring-income loss. Other entries retain their wave-one baseline. Long identities/mechanics use the existing focus-following, chrome-free scrolling at both supported desktop widths. Machine portrait playback demonstrates attacks, troop doors, legs, charged jumps, and damaged/critical poses using the battlefield's frame owner.


`EnemyStatisticsStore` atomically saves `user://enemy_statistics.json`. Accepted cumulative per-side totals carry a unique model/match ID. Durable high-water marks make repeated, stale, reconnected, or restarted observations idempotent; the owned slot is bound for each ID, avoiding mirrored-solo/opponent duplication. Actual tower kills count; leaks/rejected sends do not. Sent groups count individuals. Sandbox never records progression. Invalid saves are not silently replaced; failures are shown in Orcieary and retried only from cumulative accepted state without granting phantom counts. This is a trusted local save, not account-backed anti-cheat.

## Sandbox

**Sandbox** replaces Workshop; **S** opens it from the menu. It owns a separate model, path layout, camera, and paused menu-return state. All catalog towers and enemies are available without unlocking anything. Purchases/upgrades are genuinely free; lives cannot be lost. Sandbox does not edit collection saves or lifetime records.

- Paint/erase paths with left/right drag while stopped; tiles have no spending budget.
- Buy, inspect, target, upgrade, and sell the same real tower types/evolutions used in matches. **Build another [B]** selects the inspected tower's base identity, not a copy of its upgrades or traits.
- Dragging previews the tower's actual base artwork translucently on the hovered tile, with baseline range cells and red invalid-ground feedback. It closes any tower/enemy inspector immediately. Escape cancels only the drag; ordinary accepted drops inspect the new tower, while Shift-drop keeps building.
- Choose a round and start its weighted wave, or choose any enemy and exact count, including Skeltorcs, Giants and KamikaOrcs.
- Space starts or toggles pause; choose 1×/2×/4× playback or cycle it with **F**. Stop/clear removes enemies and unlocks editing while retaining the build.
- **Restart [R]** repeats the last accepted weighted wave or exact Spawn batch, clearing old enemies/queued spawns and running immediately. It keeps towers, upgrades, rolls, targeting, speed, current route, and selected round. Weighted retries roll a new regular roster; exact retries repeat only the last accepted type/count, not a history of mixed additions. Stop and round edits retain the recipe; a disconnected path prevents replay without discarding it. Fields, menus, confirmations, and active drags block keyboard shortcuts.
- Set map width/height and confirm Resize to replace the map/build. Numeric fields accept values beyond their arrow range, subject to machine memory—not an infinite-performance promise.
- Reset build requires confirmation and retains the path. Menu/Escape pauses and preserves the playground. WASD and cursor zoom reuse match camera controls; text entry, selectors, inspectors, and dialogs take input priority.

Enemy stats are scaled to the selected round. Exact-spawn controls create the requested individual count rather than rolling an Orcling group; weighted waves and paid match orders retain grouping. All normal match ownership, funds, readiness, and send-unlock rules stay intact outside the captured sandbox mode.

## Verification

Use the [single-command checks](development.md#single-command-verification). `enemy_mechanics_test.gd` covers unlock boundaries, atomic rolls, grouped budgets/timing, true-radius healing, caps, cast death/leaks, inherited routes, spawn exposure, slow/cast interaction, and sandbox/statistics isolation. `enemy_mechanics_peer_test.gd` uses real separate host/client processes with divergent client resources. Statistics tests cover duplicate/stale snapshots, restart, corruption, atomic failure/retry, accepted kills/sends, and leaks. Sandbox and rendered Orcieary/board tests cover input priority, confirmations, geometry, animations, and hidden-state behavior. Real friend play remains necessary to tune pressure, maze lengths, healing usefulness, and late-wave performance.

The expansion's full `python3 tools/verify.py all` run passed **41/41 checks** (36 suites plus five gates), including separate real host/client processes and rendered tests. A graphical main-scene smoke exercised menu shortcuts, all seven previews at 1000×720/1280×720, native sandbox path drawing, all three free tower branches, mixed exact spawns, paused navigation, and confirmed 40×24 resizing. A separate real simulation captured Chief healing, stationary staff casting, and living summoned children. A normal match UI smoke recorded three accepted Orcling sends and five actual Orcling kills, displayed them in Orcieary, and reloaded the same saved totals. Smoke resources/saves/scripts were isolated and removed; automated checks do not establish competitive balance or internet reachability.

The portrait/order/art/death revision passed **43/43 project checks**, including real host/client kill-event replication and rendered corpse/blood cleanup. Native portrait clicks were exercised for every sorted entry at 1000×720 and 1280×720. Actual sandbox kills rendered each collapse, bloodless Skeltorc bone heap, and expiry, including the final death after automatic wave clearance. The reversed grounded/airborne gait was corrected and numerically audited for source-left and mirrored-right before in-game inspection. A clipped Brute collapse frame was corrected; all 192 exported frames retain transparent margins. These checks validate behavior and readability, not objective aesthetic perfection.

The diminishing movement revision passed **49/49 project checks**, including boundary/rate assertions, additive versus compounded milestones, configurable baseline/span/fraction, regular and paid movement, captured-source protection, and separate real host/client agreement with intentionally different client progression. A rendered game smoke inspected live enemies at rounds 1, 6, 16, 31, 51 and 101 and verified Sandbox selected-round speeds against the same owner. At round 101 the ordinary Orc's live inspector displayed 3.17 cells/second. Health, group/count budgets, economy, and spawn cadence were intentionally unchanged.
