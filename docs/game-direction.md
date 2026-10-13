# Game direction

## Design status

This document records the direction agreed with the creators. **Confirmed** means a design requirement, not implemented behavior. **Working preference** is provisional. **Open** decisions must not be silently filled in as requirements.

The project currently contains only a runnable title scene. Gameplay, multiplayer, progression, and final art are not implemented. This specification does not authorize starting gameplay implementation.

## The game in one paragraph

Goorcs is a private, desktop-first, top-down 2D pixel-art tower-defense game for friends. Two players build their own mazes, defend against regular waves, and send additional enemies at each other to earn future income and try to destroy the opposing base. Players bring a loadout from a persistent collection, buy known tower types with randomized stats and traits, and upgrade individual towers during a longer competitive run. Play remains active during combat. A run starts small and escalates into huge towers, powerful spells, and dense enemy waves. The world is broad fantasy with orcs as its foundation.

BTD Battles is a reference for opposing boards, scouting, and the send-to-grow-income economy, not a source of assets or code.

## Confirmed experience

- **Private play:** for the creators and a small group of friends, not a public-service game.
- **Desktop first:** downloadable game; exact desktop operating systems are still open.
- **1v1:** both players defend against regular waves and opponent-sent enemies while trying to defeat each other.
- **Two boards:** players can observe both sides and move the camera to inspect the opponent. Camera movement does not imply a playable character walking across the map.
- **Player-built routes:** placement freedom and shaping the enemy path are central sources of strategy.
- **Longer runs:** favor substantial build development over a quick duel. Exact duration is open.
- **Persistent progression:** unlock more options and some lasting stat changes. Equal starting power is not a requirement.
- **Escalation:** an initially small defense grows into much larger and more intense combat over the course of a run.

## Run, rounds, and waves

### Confirmed

- A **run** is the complete 1v1 contest. Enemies reaching a base damage it; a destroyed base ends the entire run.
- Base health carries between rounds. Losing a base is not merely losing one round or spending a run life.
- A **wave** is a group of regular enemies. Opponent-sent enemies provide additional pressure; exact delivery timing is open.
- The desired format combines a standalone competitive match with development across multiple encounters.

### Working preference

Keep and expand the same maze, towers, and upgrades throughout the run. A **round** would be a stage introducing threats, rewards, or modifiers, rather than a fresh scored match. The creator is leaning toward this continuity but has not finalized it.

The number of waves per round, round boundaries, breaks, boss cadence, and what else carries over are open. Breaks may exist, but they are not the only time construction is allowed.

## Core player loop

This is the conceptual sequence, not a fixed wave schedule or finalized reward cadence:

1. Outside the run, use earned progression rewards for collection pulls and lasting development.
2. Choose a limited loadout from the permanent collection before entering the run.
3. Start with a small defense. Buy known units from the loadout, receive randomized bonuses, and arrange defenses to shape an open route.
4. During waves, defend and actively develop the board, use available abilities and interactions, scout, and time enemy sends.
5. Balance immediate defense against spending on sends that increase future income. Develop towers and adapt to random rewards and escalating threats.
6. Continue the competitive run until a base is destroyed.
7. Receive progression currency under rules still to be defined. Run-specific towers, bonuses, and perks do not become permanent collection items.

## Boards and maze building

### Confirmed

Players can construct and alter the route enemies must follow. An open route to the base must always exist; reject placements that seal it or trap an enemy. A completely blocked route is not resolved by enemies destroying walls or towers.

Building remains available during combat. The map must therefore support legal changes while enemies are already traversing it.

### Open implementation-shaping decisions

- Grid-snapped placement, free-positioned footprints, or another placement representation.
- Whether towers themselves block movement, dedicated walls shape routes, or both.
- Whether upgraded towers change their occupied footprint or only their visual size.
- Whether a placed tower can be moved directly, rather than sold and bought again.
- The cost and limits of rebuilding so players cannot stall enemies indefinitely by alternating routes. Keeping a route open alone does not prevent that exploit.
- Board symmetry, terrain, entrances, exits, and how much of the opposing board is visible at once.

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

These are desired action categories, not defined content lists. Ability targeting and costs, map interactions, non-tower building roles, and gambling rules remain open. Free relocation of existing towers has not been confirmed.

## Collection, loadouts, and tower growth

### Persistent collection and loadout

Earn currency from runs for collection pulls and progression outside the match. Collection progress provides additional options plus some permanent stat changes. The strength and limits of those advantages are open.

Choose a limited loadout before a run. That loadout determines the known unit types available to buy. Loadout size, duplicate slots, purchase limits, starter access, and permanent duplicate handling are open.

### In-run purchases and randomness

**Choose the unit identity, randomize its bonuses.** Buying a tower is not a roll for an unknown tower type. Bonuses should include both numerical stats and meaningful traits that can affect behavior or synergies.

Random upgrade/reward choices also remain part of the desired roguelite direction. Their cadence and relationship to tower traits are open. In-run gambling is desired, but it has not been defined as rerolling, a separate wager, or another mechanic.

When bonuses become visible, whether players can reroll them, what can stack, and how sale/rebuy affects a roll are open. Do not assume a bench or automatic random placement.

### Tower growth and reset

Buy upgrades for individual towers. Duplicate merging is not the chosen in-run upgrade system. Upgrade branches, costs, and trait interactions are open.

Run-specific towers, traits, upgrades, and perks reset after the run rather than being carried home as items. The enduring reward is currency for collection pulls and permanent progression. How victory, defeat, survival, and run length affect payouts is open.

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

**Confirmed:** top-down pixel art, broader fantasy, with orcs as the foundation rather than the only possible faction. Exact factions, tone, unit roster, palette, asset sources, and pixel resolution are open.

The run should start small and become increasingly extreme: larger towers, stronger and more spectacular spells, and much higher enemy density. This is a desired experience, not a measured engine capacity or a fixed enemy-count target.

**Design constraints to validate:** players should still be able to understand routes, important threats, and the results of their actions during late-run spectacle. Visual size and simulation footprint are separate decisions. Representative late-run scenes must be measured on the chosen target hardware before performance is claimed.

## Technical direction

- Required engine release and run commands: [development setup](development.md#setup).
- Editing and state-ownership conventions: [AGENTS.md](../AGENTS.md).
- Godot's Compatibility renderer, text-authored scenes/resources, and nearest-neighbor texture filtering are the current starting configuration.
- The proposed networking model has one authoritative host simulate both boards, validate actions, and distribute results. Camera state stays local.
- Either player hosting with some setup or a small hosted service is acceptable. ENet with a private network tool such as Tailscale is a recommendation, not a final service choice or an implemented feature.
- MCP/editor bridges are optional development tools, not something players must run.

Host migration, public matchmaking, accounts, monetization, and real-money purchases have not been requested. The game is intended for trusted friends. Real internet play must be checked between separate machines and networks, not inferred from localhost success.

## First playable proof of the core rules

The first implementation milestone remains deliberately smaller than the full direction. It tests the coupled maze, combat, and economy rules before building the collection and large content roster:

1. Two players connect, each with a board and camera access to inspect the opponent.
2. At least one known tower type and one enemy type support a basic defense loop.
3. Tower placement shapes enemy routes; invalid blocking placements are rejected without spending currency.
4. Construction, individual upgrades, and selling work during combat; route-switching restrictions are explicitly chosen before this is considered complete.
5. Regular waves threaten both bases. Sending enemies costs currency and increases the sender's future income.
6. Both players observe consistent currency, income, enemy state, health, and match results.
7. A base reaching zero health ends the run. A simultaneous defeat rule must be chosen before completion.

This milestone is not the finished game and does not discard the requested abilities, other buildings, map interactions, gambling, traits, collection, or escalation. Those systems need concrete rules and later playable milestones. No gameplay implementation begins as part of this specification work.

## Decisions still needed before their implementation

- **Board interaction:** placement representation, what blocks movement, direct relocation, upgrade footprints, refund rules, and route-switching limits.
- **Run pacing:** confirm board continuity; define round boundaries, wave scheduling, breaks, send delivery timing, endgame pressure, and simultaneous defeat.
- **Tower and enemy content:** initial archetypes, targeting, attacks, enemy defenses, and counters.
- **Active systems:** abilities, map interactions, non-tower buildings, and the exact gambling mechanic.
- **Randomness and progression:** trait reveal/reroll rules, run reward choices, loadout limits, starter collection, permanent stat growth, and post-run payouts.
- **Balance and readability:** intended duration, economic scaling, late-run density, visual hierarchy, and performance targets.
- **Delivery:** desktop operating systems, save ownership, collection persistence, and connection setup.
