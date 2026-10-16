# Game direction

## Design status

This document records the direction agreed with the creators. **Confirmed** means a design requirement, not implemented behavior. **Working preference** is provisional. **Open** decisions must not be silently filled in as requirements.

The project contains host-authoritative two-player defense, mirrored Singleplayer, collection/chests, a free-build Sandbox replacing Workshop, and the Orcieary with persistent owned-side enemy records. Seven animated enemies include grouped Orclings, healing Orc Chiefs, NecOrcmancers, and summoned SkeleOrcs. Weighted waves, staged sends/income, tower economy/branches, readiness/deadlines, strategy breaks/map growth, persistent match health, and results are implemented. Loadouts and permanent stat growth remain unimplemented; the complete long-term milestone below is not finished.

## The game in one paragraph

Gorcs is a private, desktop-first, top-down 2D pixel-art tower-defense game for friends. Two players build their own mazes, defend against regular waves, and send additional enemies at each other to earn future income and try to destroy the opposing base. Players bring a loadout from a persistent collection, buy known tower types with randomized stats and traits, and upgrade individual towers during a longer competitive run. Play remains active during combat. A run starts small and escalates into huge towers, powerful spells, and dense enemy waves. The world is broad fantasy with orcs as its foundation.

BTD Battles is a reference for opposing boards, scouting, and the send-to-grow-income economy, not a source of assets or code.

## Confirmed experience

- **Private play:** for the creators and a small group of friends, not a public-service game.
- **Desktop first:** downloadable game; exact desktop operating systems are still open.
- **1v1:** both players defend against regular waves and opponent-sent enemies while trying to defeat each other.
- **Two boards, one continuous world:** players initially view their owned side, use WASD to pan in four directions, and scroll/pinch to zoom. Local camera motion clamps at map bounds and leaves the HUD fixed. It grants neither a walking character nor permission to edit the opponent's board.
- **Player-authored routes:** each player lays out a connected path from the entrance to the base using an equal budget of path tiles on a square grid. Towers are not the mechanism that defines the route.
- **Longer runs:** favor substantial build development over a quick duel. Exact duration is open.
- **Persistent progression:** unlock more options and some lasting stat changes. Equal starting power is not a requirement.
- **Escalation:** an initially small defense grows into much larger and more intense combat over the course of a run.

## Run, rounds, and waves

### Confirmed

- A **run** is the complete 1v1 contest. Enemies reaching a base damage it; a destroyed base ends the entire run.
- Base health carries between rounds. Losing a base is not merely losing one round or spending a run life.
- A crystal represents the base and its health. The current match sprite is a blue faceted crystal on a stone pedestal; final art is not settled.
- A **wave** is a group of regular enemies. Opponent-sent enemies arrive concurrently through an independent, paced FIFO stream throughout combat, outside the regular budget/caps. Planning purchases wait for combat. Both boards must finish regular spawns, pending sends, and living enemies before the planning break; there is no minimum combat timer. Continuous funded sending can prolong combat.
- Regular and sent-enemy spawn intervals tighten by 0.5% of their original interval per round after round 1, capped at a 50% reduction from round 101. Their streams stay independent; this changes delivery frequency, not enemy movement speed or the existing HP/count scaling.
- The desired format combines a standalone competitive match with development across multiple encounters.
- **Confirmed simultaneous defeat:** if both bases reach zero in the same host simulation tick, one host-owned random coin flip chooses the run winner. The result is shared and terminal; clients do not roll independently.

### Working preference

The implemented **round** is the current numbered regular wave; there is no second mutable round counter. Maze, towers, upgrades, health, and economy persist through the run. **Main rounds** are the strategy phases immediately before rounds 10, 20, 30…; initial round-1 setup is also a strategy phase.

**Confirmed pacing:** Ready is committed until combat starts and locks that player's planning transactions. Normal rounds start a host-owned 20-real-second window on the first Ready, with both-ready starting sooner and expiry starting automatically. Setup and main rounds are untimed and always require both Ready. Autoplay preserves unanimous consent but pauses at these strategy phases. Combat construction remains allowed. These choices supersede the former reversible Ready/no-countdown and every-break path-editing rules.

## Core player loop

This is the conceptual sequence, not a fixed wave schedule or finalized reward cadence:

1. Outside the run, use earned progression rewards for collection pulls and lasting development.
2. Choose a limited loadout from the permanent collection before entering the run.
3. Start with a small defense. Lay out a legal entrance-to-base route using the path-tile budget, buy known units from the loadout with randomized bonuses, and position defenses around that route.
4. During waves, defend and actively develop the board, use available abilities and interactions, scout, and time enemy sends.
5. Balance immediate defense against spending on sends that increase future income. Develop towers and adapt to random rewards and escalating threats.
6. Continue the competitive run until a base is destroyed.
7. Receive progression currency under rules still to be defined. Run-specific towers, bonuses, and perks do not become permanent collection items.

## Boards and maze building

### Confirmed

Players lay walkable path tiles on a square grid. Both players start with the same path-tile budget, and the tiles must connect the entrance to the base. **30 tiles was an example, not a chosen balance value.** Whether the full budget must be used is still open.

The presentation places the host board on the left and guest on the right in one continuous world, with both streams entering from the middle toward outer bases. The left board mirrors rendering/input, not authoritative coordinates. Each player initially views their own side; WASD pans continuously and wheel/pinch zoom stays bounded and cursor-anchored. A separate world viewport keeps the HUD fixed. Camera control is available in multiplayer and mirrored Singleplayer; gameplay commands remain restricted to the owned board. Both enemy sources join each board's stream, without requiring identical mazes, commanders, or defenses.

The initial match grid is 14×9 with equal 30-tile budgets. Before round 20 and every main round after it, each board gains a row above/below and a column beyond its outer/crystal side, plus six path tiles. Portal-facing edges do not expand. Sandbox shares the artwork/rule owners but permits manually resized maps and unlimited paths without affecting match settings.

Both portal and crystal stay at exactly the same world positions, as do existing towers/paths. Logical x stays unchanged; logical y shifts down one. The mirrored host board's world origin moves left/up while the guest's centre-facing origin stays horizontally fixed and moves up. The central ravine/portal edges remain stationary. Each growth event frames the enlarged owned board once. Expansion overlays are removed; ordinary snapshots preserve the camera.

Enemies take shortest routes across connected path tiles, not placement order. When more than one next branch has the same remaining shortest distance, the host alternates assignments in stable round-robin order at that fork. Regular and sent enemies share a board's rotation, reset each wave; longer alternatives remain unused. Each enemy receives its complete captured route at spawn. Adjacent path sections can still create shortcuts. Towers and walls do not define routes by blocking otherwise walkable ground.

The whole board grows at the same host-owned milestones for both players, rather than selecting territory to buy. Main round 10 is the first redesign window without growth; rounds 20, 30, 40… each grow once. The +6 allowance supports routing through the new strips without granting either player extra Coins or bypassing connectivity. Final growth/budget balance remains subject to playtests.

The current wave's routing graph and each enemy's assigned shortest route are preserved throughout combat. Redesigning paths happens between waves, not as a tactic for repeatedly redirecting moving enemies.

Buildings also use square-grid placement. Building, upgrading, and selling remain available during combat, but must not invalidate the current route. Tower relocation that preserves upgrades and traits is free during breaks only; it is not available during combat.

Some major tower upgrades expand their occupied footprint. An expanding upgrade requires surrounding space and cannot overlap another building or obstruct the route. Players therefore need to plan room for future growth.

### Implemented sandbox

Workshop has been replaced by an isolated free-build combat playground. Every tower/enemy is available, construction/upgrades cost nothing, paths have no spending budget, and leaks cannot defeat the player. Round, weighted wave, exact enemy/count, playback speed, and map dimensions are configurable. Resize/reset require confirmation where they discard a build. Menu/Escape preserves the paused playground and camera for the session; no collection/lifetime progression is granted.

Sandbox uses the actual `MatchCombat`, `PathLayout`, sprite/inspector, and camera owners rather than a second simulation. It can directly spawn summon-only SkeleOrcs; match send/regular gates remain intact outside sandbox mode. The normal route connectivity and captured shortest-branch rules still apply. Full controls and verification are in [enemy roster and sandbox](enemy-roster.md).


### Open implementation-shaping decisions

- Final growth/budget balance and long-run board limits; current milestones add one outer column, two rows, and six path tiles.
- Final route-preview presentation; combat captures equally short branches without drawing a route-line overlay.
- Additional route mechanics beyond initial/main-round redraw; current paths remain locked on all ordinary rounds and retain unused budget.
- Placement relative to path tiles, initial board dimensions, terrain, and the placement of the fixed entrance and crystal.
- Final zoom limits and large-map readability/performance targets; current WASD and bounded wheel/pinch controls preserve local framing through snapshots and growth.
- Sale refunds, purchase/roll costs, and restrictions needed to prevent unlimited trait rerolls through sale/rebuy.

### Commanders and board identity

**Confirmed:** the starting hero is an off-board commander, not a controllable character or a defender placed on the battlefield. Normal defenses are mostly physical structures. Commanders can provide identity and special rules without adding character movement to the camera-controlled game.

Mechanically meaningful board variety is desired, not just cosmetic recoloring. The relationship between commander and map remains open, with both possibilities retained:

- **Commander-linked boards:** the chosen commander determines or modifies terrain, special zones, expansion behavior, or other board mechanics.
- **Independent commander and map choices:** a map has its own mechanical identity, while the commander supplies a separate set of rules or abilities. Different combinations are possible rather than each commander being tied to one map.

Matching starting boards with different player-authored paths also remains an available direction. No final symmetry rule or commander/map coupling has been chosen. Concrete commander abilities, selection rules, and board differences still need examples before this system is specified.

## Active play during combat

The latest decision supersedes the earlier build-only-during-breaks proposal. Players should be able to:

- Build their own towers.
- Upgrade individual towers.
- Sell towers.
- Use abilities and spells.
- Interact with map features.
- Construct other kinds of buildings.
- Spawn/send enemy units at the opponent.
- Gamble during the run.
- Scout the opposing board.

These are desired action categories, not defined content lists. Concrete ability effects and costs, map interactions, non-tower building roles, and gambling rules remain open. Direct relocation is free only during breaks; combat-time construction, upgrades, and selling must preserve the current route.

### Abilities across both boards

**Confirmed:** abilities can affect both the player's own board and the opponent's board. Opponent-targeted spells cause temporary disruption, such as briefly slowing or disabling defenses. They cannot permanently destroy opposing towers or directly damage the opponent's base.

Exact effects, eligible targets, resource costs, cooldowns, visibility, and ways to respond remain open. Clear warnings or counterplay for powerful disruption are design proposals to evaluate, not an implemented system. A spell's ability to target the opposing board does not implicitly permit editing its path, violating route locks, or bypassing the open-route requirement.

## Collection, loadouts, and tower growth

### Persistent collection and loadout

Earn currency from runs for collection pulls and progression outside the match. Collection progress provides additional options plus some permanent stat changes. The strength and limits of those advantages are open.

Choose a limited loadout before a run. That loadout determines the known unit types available to buy. Loadout size, duplicate slots, purchase limits, starter access, and permanent duplicate handling are open.

### Implemented collection chest

- **Approved prototype rules:** free chest openings on the collection screen; unlock only missing tower types, without duplicates. Openings stop when the catalog is exhausted.
- **Prototype reset:** the collection screen's confirmed Reset progress action clears saved tower unlocks and the previous reveal, enabling fresh chest openings. Cancel leaves progress unchanged; reset does not affect workshop paths. Reset is unavailable during an active reveal or a save error.
- **Provisional payout odds:** roll one reward 80% of the time, three 15%, and five 5%; cap to the number of types still locked. The initial three-entry catalog means a five-roll can grant at most three actual rewards.
- **Initial identities:** Arrow tower, Orc ballista, Rune obelisk. All three use accepted PixelLab sprites with unchanged source PNGs; atlas regions exclude transparent canvas padding. Arrow tower uses the creator-selected green-bannered tower with a visible stone base and a pink-haired archer holding a bow. All three use a consistent visual-size limit in the collection and chest cards without stretching. Each `TowerDefinition` references its `TowerReward` identity/art resource. One typed `ContentCatalog` resource registers towers and enemies; collection rewards, match palettes, and board artwork derive from it. Saved unlocks determine local placement-menu options. See the [content pipeline](content-pipeline.md) for adding resource-only variants.
- **Ownership:** `CollectionStore` selects the rewards and atomically saves the complete unlocked set before granting it in memory. Invalid saves or write failures disable openings and grant nothing; existing saved data is not silently replaced.
- **Presentation:** `ChestReveal` only displays a supplied reward list. User-supplied PixelLab chest sprites provide closed/open poses; the fixed body stays unchanged while the lid/interior crossfades. Shake, light, decorative coins, and simultaneous reward cards remain separate. This borrows the chest-reveal idea, not assets or a roulette reel. Skipping or navigation cannot reroll or grant rewards.
- **Persistence:** a local `user://collection.json` save belongs to one running game instance. There is no cloud sync, account, concurrent-writer coordination, or host-authoritative match reward integration.
- **Check:** open, skip, return to the menu, restart, and inspect the same unlocks; complete the three-type catalog and confirm openings stop. Regression commands and save-error handling are in [development](development.md#collection-and-chest-verification).

Free prototype openings do not decide how completed runs award collection currency or chests, loadout rules, or permanent stat changes.


### In-run purchases and randomness

**Choose the unit identity, randomize its bonuses.** Buying a tower is not a roll for an unknown tower type. Bonuses should include both numerical stats and meaningful traits that can affect behavior or synergies.

Random upgrade/reward choices also remain part of the desired roguelite direction. Their cadence and relationship to tower traits are open. In-run gambling should include several activities at different risk levels, rather than a single universal reroll action.

When bonuses become visible, whether players can reroll them, what can stack, and how sale/rebuy affects a roll are open. Do not assume a bench or automatic random placement.

### Tower growth and reset

Buy levels for individual towers, with occasional major branching evolutions that change role, appearance, and sometimes occupied footprint. Duplicate merging is not the chosen in-run upgrade system. Specific evolution branches, commitment or respec rules, costs, and trait interactions are open.

Run-specific towers, traits, upgrades, and perks reset after the run rather than being carried home as items. The enduring reward is currency for collection pulls and permanent progression. How victory, defeat, survival, and run length affect payouts is open.

### Gambling: multiple risk levels

**Confirmed:** the desired system includes several kinds of in-run gambling with different stakes. Candidates discussed are paying to reroll a tower's bonuses, wagering currency for random rewards, and risking an existing tower for a transformation.

The choice of multiple activities does not yet lock in all three candidates or their failure outcomes. Which activities ship, what can be lost, whether an outcome can be declined, odds disclosure, costs, and safeguards against repeatable exploits remain open. This is part of the game's resource economy; no real-money gambling or purchases have been requested.

## Economy and attacking

Sending enemies spends match currency now and increases future income. This creates a tradeoff between immediate defensive investment, economic growth, and pressure on the opponent.

The creator authorized provisional playtest Coins and balance values: host-owned paid towers, kill and wave-clear income, one-time damage/speed upgrades followed by a gated type-specific special, and a partial invested-cost sale refund. Sends now offer Grunt, fast/fragile Runner, and slow/durable Brute, with resource-defined prices and recurring income gains. Income starts at zero and is paid with the existing both-board clear reward, not on a wall-clock timer or immediately on purchase. Each accepted send grows that bonus, including a late queued order; terminal defeat pays no clear reward or bonus. These prototype values/cadence do not settle final balance, gambling, purchase randomness, or long-run progression.

Important design risks to address:

- An early income lead becoming impossible to recover from.
- Endless cheap sending becoming the only sensible economic action.
- Buying, selling, and rerolling producing free money or effectively unlimited trait rolls.
- Permanent stats, favorable trait rolls, and reward luck compounding into an overwhelming advantage.

These are risks, not decisions to remove progression, income growth, or randomness.

## World, art, and escalation

**Confirmed:** top-down pixel art, broader fantasy, with orcs as the foundation rather than the only possible faction. Defenses are mostly physical structures rather than stationed characters or creatures. Exact factions, tone, structure roster, palette, asset sources, and pixel resolution are open.

The creator approved the board composition study's overall visual direction: stronger tower/enemy proportions, grounded sprites, layered terrain/path materials, and quieter contextual highlights. The existing-art presentation pass is implemented and rendered in the game; art consistency is not final. [Visual TODO](../TODO.md) preserves the approved reference, actual runtime captures, shared actual-size lineup, and remaining replacement-approval work. The working sprite standard is elevated three-quarter artwork, upper-left lighting, restrained contact shadows, dark readable contours, and deliberate pixel clusters. The square-grid gameplay camera is unchanged in kind; resource-derived visual headroom keeps tall top-row artwork below the fixed HUD.

The follow-up readability correction makes the playable field distinct from darker outer scenery and the central ravine, with a cosmetic external earth edge and quieter continuous stonework. Routine HUD text is limited to current facts/actions; route/scouting explanations, affordability deficits, and regular-spawn progress are tooltip-only, and zero income/queues are absent. These are presentation decisions, not changes to usable cells, match rules, or sprite approval.

The run should start small and become increasingly extreme: larger towers, stronger and more spectacular spells, and much higher enemy density. This is a desired experience, not a measured engine capacity or a fixed enemy-count target.

**Design constraints to validate:** players should still be able to understand routes, important threats, and the results of their actions during late-run spectacle. Visual size and simulation footprint are separate decisions. Representative late-run scenes must be measured on the chosen target hardware before performance is claimed.

## Technical direction

- Required engine release and run commands: [development setup](development.md#setup).
- Editing and state-ownership conventions: [AGENTS.md](../AGENTS.md).
- Godot's Compatibility renderer, text-authored scenes/resources, and nearest-neighbor texture filtering are the current starting configuration.
- `resources/content_catalog.tres` is the one authored tower/enemy registration list. `CombatRules.catalog` and the collection share it; combat captures authoritative stats, while UI and renderers resolve the same registered identities. Variants of existing attacks/enemy behavior need resources and one catalog edit; novel mechanics still require code and behavior regressions. Duplicate/invalid entries are rejected, and weighted waves require an always-eligible unlimited weight-one enemy of any ID. Exact authoring and validation rules are in the [content pipeline](content-pipeline.md).
- One authoritative host validates both players' commands and simulates captured routes, regular enemies, Arrow attacks, base damage, and results. Clients display detached accepted snapshots; camera position, selection, tool choice, target defaults for future placement, and visual effects stay local.
- **Implemented connection setup:** Play offers Host and Join using Godot ENet. The creator chose no game-hosted online infrastructure. A shared invite contains a numeric host address, UDP port, and fresh random room credential; it admits only one guest. LAN, a private VPN/network, or a reachable public address with UDP forwarding/firewall access is required. The invite is not a short-code lookup service and cannot bypass NAT.
- **Local testing:** Play also offers Singleplayer, with no network connection. A mirror opponent repeats accepted path/tower/send commands and readiness through the same authoritative rules; no independent AI or progression bypass is added.
- **In-match menu:** Escape/cogwheel opens Resume, Settings, and Quit. Solo pauses while multiplayer continues behind its local overlay; no peer can unilaterally freeze the shared run. Quit returns to title through normal session teardown. Music/Sound preferences are local and persistent, independent of gameplay; current effects audio remains unimplemented.
- MCP/editor bridges are optional development tools, not something players must run.

Host migration, public matchmaking, accounts, monetization, and real-money purchases have not been requested. The game is intended for trusted friends. Real internet play must be checked between separate machines and networks, not inferred from localhost success.

Admission opens initial planning with local owned-side focus. The host validates ownership, cells, paths, funds, tower transactions, readiness, and pacing; scouting grants no opponent commands. Ready locks own planning mutations. Manual both-ready, normal deadline, and ordinary autoplay all use the same legal capture/start gate. Initial/main strategy remains untimed. Paths edit only in an uncommitted strategy phase; tower management resumes in combat.

**Implemented defense slice:** Arrow, Ballista, and Rune use resource-defined prices and stats. Coins pay for towers and one damage plus one speed upgrade per tower, with distinct stat gains. Tower level is I initially, II after either upgrade, and III after both; the click-open management title shows Roman numerals. Original base upgrade prices remain Arrow 30, Ballista 55, and Rune 45 Coins. Each level adds 50% of the original price without compounding; the second upgrade costs 45/83/68 Coins, respectively, rounding fractions up. Upgrade order does not affect price. Kills belong to the final attacking tower and pay its board once. Clearing both boards grants wave income once; selling refunds 60% of actual purchase/upgrade investment. All three targeting policies remain available. Range uses tile neighborhoods; Rune range one covers the center and eight neighbors and damages all enemies inside. Brief ground shimmer and local hit sparks show attacks; quiet tile highlights show selected range.

**Third upgrades and evolutions:** buying both stat upgrades exposes the final choices, raising III → IV when one is purchased. Fixed prices bypass level scaling: Arrow 200, either Ballista branch 300, either Rune branch 250 Coins. Arrow gains a visible second archer, independent targeting of a different enemy, and 10% more attacks/s; ordinary and dual attacks show small traveling arrows. Ballista permanently chooses Pierce 2 or Bounce 1. Pierce uses the selected target to aim a straight ray and hits its first two enemies within range at full damage, so intervening enemies can intercept. Bounce keeps the primary hit and redirects once to the nearest other living enemy for half damage rounded up, including beyond the tower's own range. Both preserve upgraded damage and cadence. Rune permanently chooses Boulders or Onyx Ring. Boulders deals continuous 6 DPS throughout the existing 3×3 neighborhood; its orbiting stones are cosmetic rather than contact hitboxes. Onyx Ring hits that neighborhood for 6 damage every 0.75 simulation seconds, with higher sustained DPS when enemies stay through successive pulses but gaps where passing enemies escape. Boulders alone offers a second evolution upgrade, Freeze Runes, for another fixed 250 Coins and level V. Its damage applies a nonstacking 20% slow for two simulation seconds once that individual Rune has cumulatively dealt at least 20% of the enemy's maximum HP; later qualifying damage refreshes the duration. Prior Rune damage counts, but buying Freeze never applies it retroactively. Branch damage/cadence are final effective values after the required stat upgrades; Freeze adds control without changing Boulders DPS. These are provisional balance choices, not measured competitive balance or a larger footprint.

**Implemented sends:** stable IDs and authenticated payer commands pass one host validator for ownership, funds, phase, committed readiness, and send-unlock round. Only Orclings are sendable in rounds 1–5; later send tiers trail regular-wave introductions, with delayed final NecOrcmancer sends chosen by the creator. Paid orders release through an independent FIFO throughout combat; planning orders wait for wave start. Orcling orders roll a group once, charge once, and retain normal cooldown after the last member. Rejections change no money, income, queues, counters, or RNG. Singleplayer mirrors through the same owner.

The tower palette stays visible with collection/funds/Ready locks. Click-select and native drag/drop share owned placement rules. Tower inspection exposes stats/kills/targeting/upgrades/refund; committed planning disables mutations but not inspection. Right-click/Escape cancels selection. Without placement selected, only uncommitted initial/main strategy accepts path strokes.

Regular waves fill a growing integer weight budget with one host-randomized group roster shared by both players. Resource-defined introduction/count/share limits pace Orclings and Orcs into Runner, Brute, Chief, and NecOrcmancer roles. Chiefs heal other living allies in a true circle every five simulation seconds; NecOrcmancers stop to raise bounded SkeleOrcs on their current captured route. Summons must clear before the wave ends; their zero bounty prevents farming. All rolls/actions remain authoritative, including animation state and per-type cumulative totals.

Movement progression is now diminishing and additive: each additional 10% of the original baseline takes successively longer spans of 5, 10, 15, 20… completed rounds, with interpolation between milestones. Per-type ratios remain unchanged, and health/count/spawn-cadence/playback scaling stay independent. The host's admitted rules own actual movement and preview speeds; client configuration cannot accelerate accepted enemies.

All seven enemies have real walk animation, with separate Chief heal/Necromancer casting poses, stable anchors/facing, current-frame alpha picking, and blue slowed palettes. Orcieary previews reuse those frames and show encounter/send availability, stats, descriptions, and saved owned-side kills/sends. Exact rules and provisional balance live in [enemy roster and sandbox](enemy-roster.md), with one resource catalog for authoring. Real 1v1 pressure, long-run density/performance, and separate-network reachability still need human validation.

**Implemented Arrow advancements:** after Second Archer, one exclusive level-V choice adds Four Archers, Fire Arrows, or Bomb Arrows. The host captures their fixed costs and validates the same purchase command; four independent distinct-target streams, fractional timed burn, circular reduced splash, and SkeleOrc fire/ice immunity are implemented with matching local visuals. See [advancement balance and rules](archer-advancements.md).

**Implemented results/playback:** both modes display the accepted local Victory/Defeat outcome and final match details with inspection/menu actions. Solo can create a fresh run from results and cycles 1×/2×/3× speed; multiplayer retains unanimous 2× consent. The completed model never restarts, countdowns stay real time, and progression is not granted by the result UI. See [results and playback](match-results.md).


## First playable proof of the core rules

The first implementation milestone remains deliberately smaller than the full direction. It tests the coupled maze, combat, and economy rules before building the collection and large content roster:

1. Two players connect, each with a board and camera access to inspect the opponent.
2. At least one known tower type and one enemy type support a basic defense loop.
3. Each player draws a legal path within an equal tile budget. Enemies follow the chosen route; route edits are unavailable during the current wave.
4. Construction, individual upgrades, and selling work during combat without obstructing the route. Direct relocation is free only during breaks; expanding upgrades require a legal enlarged footprint.
5. Regular waves threaten both bases. Sending enemies costs currency and increases the sender's future income. Each opponent-bound FIFO stream runs throughout combat independently of regular spawns; planning orders wait until combat starts. Pending sends prevent premature clearance.
6. Both players observe consistent currency, income, enemy state, health, and match results.
7. A base reaching zero health ends the run. Same-tick destruction of both bases is resolved by one host-owned random coin flip.

The current slice implements authoritative planning, committed readiness/deadlines, ten-round strategy phases, repeated map growth, paid construction/management, kill/wave/send income, weighted waves, split shortest routes, results, and local four-way/zoom scouting. Randomized purchases, relocation, expanding tower footprints, and loadouts are not implemented.

## Decisions still needed before their implementation

- **Board interaction:** final growth/budget tuning, long-run size limits, initial endpoint/art choices, and future relocation/footprints. Current timing and three-edge growth away from the portal are explicit rules.
- **Run pacing:** boss cadence, encounters beyond current numbered waves, final weighted/scaling/economy balance, and endgame pressure. Committed Ready, normal 20-second windows, untimed initial/main strategy, preserved autoplay consent, and terminal coin flips are confirmed.
- **Commanders, towers, and enemies:** choose between commander-linked boards and independent commander/map selection; define commander rules, additional structure/enemy archetypes, defenses, and counters. Arrow supports Furthest/Closest/Strongest targeting; tower stats and the weighted three-enemy roster remain provisional.
- **Active systems:** concrete ability effects on both boards and their targeting, costs, warnings, and counterplay; map interactions; non-tower buildings; and the selection and rules of multiple gambling activities.
- **Randomness and progression:** trait reveal/reroll rules, run reward choices, loadout limits, starter collection, permanent stat growth, and post-run payouts.
- **Balance and readability:** intended duration, economic scaling, late-run density, visual hierarchy, and performance targets.
- **Delivery:** desktop operating systems, future save ownership beyond the current local collection, and separate-machine/network connection verification.
