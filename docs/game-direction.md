# Game direction

## Design status

This document records the direction agreed with the creators. **Confirmed** means a design requirement, not implemented behavior. **Working preference** is provisional. **Open** decisions must not be silently filled in as requirements.

The project contains a playable local path workshop, persistent collection chests, and host-authoritative two-player defense with shared planning, weighted waves, tower economy/management, sends/income, persistent health, and results. Matches use a continuous world with local WASD and bounded wheel/pinch zoom. Committed readiness, ordinary-round deadlines, ten-round strategy breaks, and three-sided growth from round 20 are implemented. Singleplayer mirrors the same rules locally. Loadouts, permanent stat growth, and final art remain unimplemented; the full milestone below is not complete.

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

The initial match grid is 14×9 with equal 30-tile budgets. Before round 20 and every main round after it, each board gains a row above/below and a column beyond its outer/crystal side, plus six path tiles. Portal-facing edges do not expand. Match/workshop share artwork, but the workshop remains local and fixed-size.

Both portal and crystal stay at exactly the same world positions, as do existing towers/paths. Logical x stays unchanged; logical y shifts down one. The mirrored host board's world origin moves left/up while the guest's centre-facing origin stays horizontally fixed and moves up. The central ravine/portal edges remain stationary. Each growth event frames the enlarged owned board once. Expansion overlays are removed; ordinary snapshots preserve the camera.

Enemies take shortest routes across connected path tiles, not placement order. When more than one next branch has the same remaining shortest distance, the host alternates assignments in stable round-robin order at that fork. Regular and sent enemies share a board's rotation, reset each wave; longer alternatives remain unused. Each enemy receives its complete captured route at spawn. Adjacent path sections can still create shortcuts. Towers and walls do not define routes by blocking otherwise walkable ground.

The whole board grows at the same host-owned milestones for both players, rather than selecting territory to buy. Main round 10 is the first redesign window without growth; rounds 20, 30, 40… each grow once. The +6 allowance supports routing through the new strips without granting either player extra Coins or bypassing connectivity. Final growth/budget balance remains subject to playtests.

The current wave's routing graph and each enemy's assigned shortest route are preserved throughout combat. Redesigning paths happens between waves, not as a tactic for repeatedly redirecting moving enemies.

Buildings also use square-grid placement. Building, upgrading, and selling remain available during combat, but must not invalidate the current route. Tower relocation that preserves upgrades and traits is free during breaks only; it is not available during combat.

Some major tower upgrades expand their occupied footprint. An expanding upgrade requires surrounding space and cannot overlap another building or obstruct the route. Players therefore need to plan room for future growth.

### Implemented path workshop

- **Confirmed rules:** four-direction edge adjacency; the tile budget is a maximum, so unused tiles are allowed.
- **Prototype configuration:** a 14×9 board, entrance at (0, 4), base at (13, 4), and 30 placeable tiles. Endpoints are fixed, traversable, and free. These map/balance values are provisional and exported on the main scene.
- **Connectivity:** disconnected tiles are allowed during editing, but readiness requires every placed tile and the base to connect to the entrance. Connected branches are legal.
- **Workshop routing convention:** breadth-first shortest path, with right/down/left/up neighbor order selecting one stable representative route. Match combat captures all equally short successors and alternates enemy assignments at forks. Connected pavement is shown without a shortest-route overlay.
- **Navigation:** the main menu opens/resumes the workshop or quits. Esc and the workshop's Menu button return to navigation without changing the layout. Layouts persist only within the running session, not after quitting.
- **Check:** build a detour and add a shorter connection; remove a bridge or add an island to invalidate readiness. Headless regressions and graphical checks are described in [development](development.md#path-workshop-verification).

There are no waves in the workshop. Free editing here does not decide combat route locks, between-wave redraw rules, or expansion behavior.

### Open implementation-shaping decisions

- Final growth/budget balance and long-run board limits; current milestones add one outer column, two rows, and six path tiles.
- Final route-preview presentation; the workshop retains a stable representative route, while match enemies alternate among equal shortest branches.
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
- **Initial identities:** Arrow tower, Orc ballista, Rune obelisk. All three use accepted PixelLab sprites with unchanged source PNGs; atlas regions exclude transparent canvas padding. Arrow tower uses the creator-selected green-bannered tower with a visible stone base and a pink-haired archer holding a bow. All three use a consistent visual-size limit in the collection and chest cards without stretching. These resources own collection identities/art, not combat stats; separate `TowerDefinition` resources give all three real direct-hit combat behavior. Saved unlocks determine local placement-menu options.
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

The creator authorized provisional playtest Coins and balance values: host-owned paid towers, kill and wave-clear income, two one-time damage/speed upgrades, and a partial invested-cost sale refund. Sends now offer Grunt, fast/fragile Runner, and slow/durable Brute, with resource-defined prices and recurring income gains. Income starts at zero and is paid with the existing both-board clear reward, not on a wall-clock timer or immediately on purchase. Each accepted send grows that bonus, including a late queued order; terminal defeat pays no clear reward or bonus. These prototype values/cadence do not settle final balance, gambling, purchase randomness, or long-run progression.

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
- One authoritative host validates both players' commands and simulates captured routes, regular enemies, Arrow attacks, base damage, and results. Clients display detached accepted snapshots; camera position, selection, tool choice, target defaults for future placement, and visual effects stay local.
- **Implemented connection setup:** Play offers Host and Join using Godot ENet. The creator chose no game-hosted online infrastructure. A shared invite contains a numeric host address, UDP port, and fresh random room credential; it admits only one guest. LAN, a private VPN/network, or a reachable public address with UDP forwarding/firewall access is required. The invite is not a short-code lookup service and cannot bypass NAT.
- **Local testing:** Play also offers Singleplayer, with no network connection. A mirror opponent repeats accepted path/tower/send commands and readiness through the same authoritative rules; no independent AI or progression bypass is added.
- MCP/editor bridges are optional development tools, not something players must run.

Host migration, public matchmaking, accounts, monetization, and real-money purchases have not been requested. The game is intended for trusted friends. Real internet play must be checked between separate machines and networks, not inferred from localhost success.

Admission opens initial planning with local owned-side focus. The host validates ownership, cells, paths, funds, tower transactions, readiness, and pacing; scouting grants no opponent commands. Ready locks own planning mutations. Manual both-ready, normal deadline, and ordinary autoplay all use the same legal capture/start gate. Initial/main strategy remains untimed. Paths edit only in an uncommitted strategy phase; tower management resumes in combat.

**Implemented defense slice:** Arrow, Ballista, and Rune use resource-defined prices and stats. Coins pay for towers and one damage plus one speed upgrade per tower, with distinct stat gains. Tower level is I initially, II after either upgrade, and III after both; the click-open management title shows Roman numerals. The first upgrade costs 10 Coins and the second 15, regardless of stat order or tower type. Kills belong to the final attacking tower and pay its board once. Clearing both boards grants wave income once; selling refunds 60% of actual purchase/upgrade investment. All three targeting policies remain available. Range uses tile neighborhoods; Rune range one covers the center and eight neighbors and damages all enemies inside. Brief ground shimmer and local hit sparks show attacks; quiet tile highlights show selected range.

**Implemented sends:** local type selection submits a stable ID and payer through the existing authenticated command path. The host validates ownership, funds, type, phase, and committed planning permissions, then charges/delivers-or-queues/increases income atomically. The first three simulation seconds permit immediate delivery; planning/later orders queue for the next legal wave start. Sends are extra to the shared regular roster/caps. A committed Ready rejects sends without spending. Singleplayer mirrors through the same validator.

The tower palette stays visible with collection/funds/Ready locks. Click-select and native drag/drop share owned placement rules. Tower inspection exposes stats/kills/targeting/upgrades/refund; committed planning disables mutations but not inspection. Right-click/Escape cancels selection. Without placement selected, only uncommitted initial/main strategy accepts path strokes.

Regular waves fill a growing integer weight budget with one host-randomized ordered roster shared by both players. Resources own weight, introduction wave, growing count cap, share limit, HP/speed multipliers, and base damage. Grunts are weight-one remainder; Runner/Brute constraints and scaling remain documented in development. Brutes leak for three, other shipped types for one. Weight replaces part of head count; it does not stack another count curve. Values and expansion allowance remain playtest balance, not measured fairness. No armor/status, relocation, footprint, loadout, or permanent-growth system is added; separate-network reachability remains unverified.

Regular spawn spacing uses a separate host-owned random timetable shared by both players. Bounded variation permits close groups without unbounded gaps; first and last regular spawn times retain the previous window. This changes spacing, not roster size, weight, income, speed, or damage. Clustered AoE effectiveness still needs playtesting before any broader horde balance change.

The horde presentation uses smaller resource-sized enemies with Brutes still visibly heavier, plus narrow deterministic cosmetic spread within paths. Existing continuous movement already permits shared tiles; no crowd collisions, physics steering, or gameplay hitbox change is introduced. Actual-size artwork and overlap/AoE readability remain playtest concerns before changing counts or animation assets.

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
