# Game direction

## Design status

This document records the direction agreed with the creators. **Confirmed** means a design requirement, not implemented behavior. **Working preference** is provisional. **Open** decisions must not be silently filled in as requirements.

The project contains a playable local path workshop, a persistent collection chest flow, and a direct two-player connection lobby. Combat, synchronized boards, loadouts, permanent stat growth, and final art are not implemented. These are narrow implemented features; the full first playable milestone below is not complete.

## The game in one paragraph

Goorcs is a private, desktop-first, top-down 2D pixel-art tower-defense game for friends. Two players build their own mazes, defend against regular waves, and send additional enemies at each other to earn future income and try to destroy the opposing base. Players bring a loadout from a persistent collection, buy known tower types with randomized stats and traits, and upgrade individual towers during a longer competitive run. Play remains active during combat. A run starts small and escalates into huge towers, powerful spells, and dense enemy waves. The world is broad fantasy with orcs as its foundation.

BTD Battles is a reference for opposing boards, scouting, and the send-to-grow-income economy, not a source of assets or code.

## Confirmed experience

- **Private play:** for the creators and a small group of friends, not a public-service game.
- **Desktop first:** downloadable game; exact desktop operating systems are still open.
- **1v1:** both players defend against regular waves and opponent-sent enemies while trying to defeat each other.
- **Two boards:** players can observe both sides and move the camera to inspect the opponent. Camera movement does not imply a playable character walking across the map.
- **Player-authored routes:** each player lays out a connected path from the entrance to the base using an equal budget of path tiles on a square grid. Towers are not the mechanism that defines the route.
- **Longer runs:** favor substantial build development over a quick duel. Exact duration is open.
- **Persistent progression:** unlock more options and some lasting stat changes. Equal starting power is not a requirement.
- **Escalation:** an initially small defense grows into much larger and more intense combat over the course of a run.

## Run, rounds, and waves

### Confirmed

- A **run** is the complete 1v1 contest. Enemies reaching a base damage it; a destroyed base ends the entire run.
- Base health carries between rounds. Losing a base is not merely losing one round or spending a run life.
- A crystal is the current suggested representation of the base and its health; its exact appearance is not finalized.
- A **wave** is a group of regular enemies. Opponent-sent enemies join the current wave until a delivery cutoff. Later orders wait for the next wave. The cutoff allows both boards to clear before the planning break; its timing is still open.
- The desired format combines a standalone competitive match with development across multiple encounters.

### Working preference

Keep and expand the same maze, towers, and upgrades throughout the run. A **round** would be a stage introducing threats, rewards, or modifiers, rather than a fresh scored match. The creator is leaning toward this continuity but has not finalized it.

The number of waves per round, round boundaries, boss cadence, and what else carries over are open. Construction is not limited to breaks. For planning breaks, the creator is considering a fixed timer, a player-ready action that starts a short countdown for the opponent, or a combination. **30 seconds was an example, not a chosen duration.** Neither the trigger nor the final timing is locked.

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

The preferred presentation places one player on the left and the other on the right, with both enemy streams entering from the middle. Regular waves and opponent-sent enemies join each board's own stream. This visual arrangement does not require identical player-built paths, map mechanics, or commanders.

The entrance and crystal stay in place as the board expands. New territory becomes available around the existing board, and extra path tiles let players route enemies through it. The crystal's visual design and the initial endpoint positions still need map sketches.

Enemies take the shortest route across connected path tiles. They do not follow the order in which the player placed the tiles. Adjacent path sections can therefore create shortcuts. This replaces the earlier tower-blocked-maze assumption: towers and walls do not define the enemy route by blocking otherwise walkable ground.

Both the available path tiles and the map's buildable area grow during the run. The whole board expands at milestones rather than the player selecting individual land sections to unlock. Milestone timing, amounts, and whether both players expand at the same time remain open.

The current wave's route is preserved throughout combat. Redesigning the route happens between waves, not as a tactic for repeatedly redirecting moving enemies.

Buildings also use square-grid placement. Building, upgrading, and selling remain available during combat, but must not invalidate the current route. Tower relocation that preserves upgrades and traits is free during breaks only; it is not available during combat.

Some major tower upgrades expand their occupied footprint. An expanding upgrade requires surrounding space and cannot overlap another building or obstruct the route. Players therefore need to plan room for future growth.

### Implemented path workshop

- **Confirmed rules:** four-direction edge adjacency; the tile budget is a maximum, so unused tiles are allowed.
- **Prototype configuration:** a 14×9 board, entrance at (0, 4), base at (13, 4), and 30 placeable tiles. Endpoints are fixed, traversable, and free. These map/balance values are provisional and exported on the main scene.
- **Connectivity:** disconnected tiles are allowed during editing, but readiness requires every placed tile and the base to connect to the entrance. Connected branches are legal.
- **Routing convention:** breadth-first shortest path, with right/down/left/up neighbor order resolving equal-length alternatives deterministically. The green preview shows actual shortcuts rather than placement order.
- **Navigation:** the main menu opens/resumes the workshop or quits. Esc and the workshop's Menu button return to navigation without changing the layout. Layouts persist only within the running session, not after quitting.
- **Check:** build a detour, add a shorter connection, and inspect the changed preview; remove a bridge or add an island to invalidate readiness. Headless regressions and graphical checks are described in [development](development.md#path-workshop-verification).

There are no waves in the workshop. Free editing here does not decide combat route locks, between-wave redraw rules, or expansion behavior.

### Open implementation-shaping decisions

- Initial path-budget size and the timing and amounts of milestone-based path-tile and whole-board growth.
- Final route-preview presentation; equal-length route selection currently uses the workshop's deterministic convention.
- Whether paths can be redrawn freely between waves and whether unused tiles are retained.
- Placement relative to path tiles, initial board dimensions, terrain, and the placement of the fixed entrance and crystal.
- How much of the opposing board is visible at once.
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
- **Initial identities:** Arrow tower, Orc ballista, Rune obelisk. The ballista uses the accepted user-supplied PixelLab crossbow-tower sprite unchanged as its base art; the other two icons remain procedural. These are collection identities with no combat stats or behavior.
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

Do not assign balance numbers yet. Baseline income, kill rewards if any, payout intervals, send costs, income increments and caps, tower costs, sale refunds, and gambling payouts remain open.

Important design risks to address:

- An early income lead becoming impossible to recover from.
- Endless cheap sending becoming the only sensible economic action.
- Buying, selling, and rerolling producing free money or effectively unlimited trait rolls.
- Permanent stats, favorable trait rolls, and reward luck compounding into an overwhelming advantage.

These are risks, not decisions to remove progression, income growth, or randomness.

## World, art, and escalation

**Confirmed:** top-down pixel art, broader fantasy, with orcs as the foundation rather than the only possible faction. Defenses are mostly physical structures rather than stationed characters or creatures. Exact factions, tone, structure roster, palette, asset sources, and pixel resolution are open.

The run should start small and become increasingly extreme: larger towers, stronger and more spectacular spells, and much higher enemy density. This is a desired experience, not a measured engine capacity or a fixed enemy-count target.

**Design constraints to validate:** players should still be able to understand routes, important threats, and the results of their actions during late-run spectacle. Visual size and simulation footprint are separate decisions. Representative late-run scenes must be measured on the chosen target hardware before performance is claimed.

## Technical direction

- Required engine release and run commands: [development setup](development.md#setup).
- Editing and state-ownership conventions: [AGENTS.md](../AGENTS.md).
- Godot's Compatibility renderer, text-authored scenes/resources, and nearest-neighbor texture filtering are the current starting configuration.
- The proposed networking model has one authoritative host simulate both boards, validate actions, and distribute results. Camera state stays local.
- **Implemented connection setup:** Play offers Host and Join using Godot ENet. The creator chose no game-hosted online infrastructure. A shared invite contains a numeric host address, UDP port, and fresh random room credential; it admits only one guest. LAN, a private VPN/network, or a reachable public address with UDP forwarding/firewall access is required. The invite is not a short-code lookup service and cannot bypass NAT.
- MCP/editor bridges are optional development tools, not something players must run.

Host migration, public matchmaking, accounts, monetization, and real-money purchases have not been requested. The game is intended for trusted friends. Real internet play must be checked between separate machines and networks, not inferred from localhost success.

The connection lobby authenticates admission and reports waiting/connected/disconnected states. Workshop layouts and collection saves are not synchronized. There is no match simulation, remote-board view, host migration, or relay fallback. Separate-process and graphical lobby checks pass; separate-machine internet connectivity remains unverified. See [connection setup and checks](development.md#direct-connection-lobby).

## First playable proof of the core rules

The first implementation milestone remains deliberately smaller than the full direction. It tests the coupled maze, combat, and economy rules before building the collection and large content roster:

1. Two players connect, each with a board and camera access to inspect the opponent.
2. At least one known tower type and one enemy type support a basic defense loop.
3. Each player draws a legal path within an equal tile budget. Enemies follow the chosen route; route edits are unavailable during the current wave.
4. Construction, individual upgrades, and selling work during combat without obstructing the route. Direct relocation is free only during breaks; expanding upgrades require a legal enlarged footprint.
5. Regular waves threaten both bases. Sending enemies costs currency and increases the sender's future income. Sends enter the current wave until a delivery cutoff; later orders wait for the next wave.
6. Both players observe consistent currency, income, enemy state, health, and match results.
7. A base reaching zero health ends the run. A simultaneous defeat rule must be chosen before completion.

This milestone is not the finished game and does not discard the requested abilities, other buildings, map interactions, gambling, traits, collection, or escalation. Those systems need concrete rules and later playable milestones. The approved path workshop proves only local editing and routing, not the multiplayer/combat milestone.

## Decisions still needed before their implementation

- **Board interaction:** final path-budget and map-expansion rules, placement relative to the path, final entrance/crystal positions, and sale/refund rules.
- **Run pacing:** confirm board continuity; define round boundaries, wave scheduling, the fixed/ready-up planning timer, send cutoff timing, endgame pressure, and simultaneous defeat.
- **Commanders, towers, and enemies:** choose between commander-linked boards and independent commander/map selection; define commander rules and the initial structure/enemy archetypes, targeting, attacks, defenses, and counters.
- **Active systems:** concrete ability effects on both boards and their targeting, costs, warnings, and counterplay; map interactions; non-tower buildings; and the selection and rules of multiple gambling activities.
- **Randomness and progression:** trait reveal/reroll rules, run reward choices, loadout limits, starter collection, permanent stat growth, and post-run payouts.
- **Balance and readability:** intended duration, economic scaling, late-run density, visual hierarchy, and performance targets.
- **Delivery:** desktop operating systems, future save ownership beyond the current local collection, and separate-machine/network connection verification.
