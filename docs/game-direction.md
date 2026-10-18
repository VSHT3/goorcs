# Game direction

## Design status

This document records the direction agreed with the creators. **Confirmed** means a design requirement, not implemented behavior. **Working preference** is provisional. **Open** decisions must not be silently filled in as requirements.

The project contains host-authoritative two-player defense, mirrored Singleplayer, collection/chests, Sandbox, and Orcieary with persistent enemy records. Six collectible tower roles, private loadouts, rolled attributes, rerolls, Shards, support/economy branches, fourteen enemies, weighted waves, staged sends/income, readiness/deadlines, map growth, and results are implemented. First kills of each boss type grant per-player, per-run tiered Coin/Shard rewards; the shared reel only reveals accepted outcomes. Permanent stat growth, post-run progression rewards, commanders, and spells remain unimplemented.

All authored rarity weights, role-specific slots/pools/bounds, reroll curves, drop/production amounts, tower stats/prices, and new branch tuning are provisional playtest values, not finalized creator-approved balance. Local rendered smoke now covers HUD/camera, inspection/accounting, and continuous Ballista tracking; neither this nor Towerieary checks establishes blanket battlefield-art approval, native-hardware/performance validation, or internet reachability. Detailed implemented resource mechanics belong in the [content pipeline](content-pipeline.md).

## The game in one paragraph

Gorcs is a private, desktop-first, top-down 2D pixel-art tower-defense game for friends. Two players build their own mazes, defend against regular waves, and send additional enemies at each other to earn future income and try to destroy the opposing base. Players bring a loadout from a persistent collection, buy known tower types with randomized stats and traits, and upgrade individual towers during a longer competitive run. Play remains active during combat. A run starts small and escalates into huge towers, powerful spells, and dense enemy waves. The world is broad fantasy with orcs as its foundation.

BTD Battles is a reference for opposing boards, scouting, and the send-to-grow-income economy, not a source of assets or code.

## Confirmed experience

- **Private play:** for the creators and a small group of friends, not a public-service game.
- **Desktop first:** downloadable game; exact desktop operating systems are still open.
- **1v1:** both players defend against regular waves and opponent-sent enemies while trying to defeat each other.
- **Two boards, one continuous world:** players initially view their owned side, use WASD or middle-mouse drag to pan, scroll/pinch to zoom, and Home to fit their current board. Local camera motion clamps at map bounds and leaves the HUD fixed. It grants neither a walking character nor permission to edit the opponent's board.
- **Player-authored routes:** each player lays out a connected path from the entrance to the base using an equal budget of path tiles on a square grid. Towers are not the mechanism that defines the route.
- **Longer runs:** favor substantial build development over a quick duel. Exact duration is open.
- **Persistent progression:** unlock more options and some lasting stat changes. Equal starting power is not a requirement.
- **Escalation:** an initially small defense grows into much larger and more intense combat over the course of a run.

## Run, rounds, and waves

### Confirmed

- A **run** is the complete 1v1 contest. Enemies reaching a base damage it; a destroyed base ends the entire run.
- Bases start at **100 HP**, shown as a health bar with the current value, and health carries between rounds. Losing a base is not merely losing one round or spending a run life.
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

The presentation places the host board on the left and guest on the right in one continuous world, with both streams entering from the middle toward outer bases. The left board mirrors rendering/input, not authoritative coordinates. Each player initially views their own side; WASD and middle-mouse grab pan, wheel/pinch zoom stays bounded and cursor-anchored, and Home fits the complete current owned board. A separate world viewport keeps the HUD fixed. Matches and Sandbox share camera controls with HUD/modal/typing/drag guards; gameplay commands remain restricted to owned cells regardless of the view. Both enemy sources join each board's stream, without requiring identical mazes, commanders, or defenses.

The initial match grid is 14×9 with equal 30-tile budgets. Before round 20 and every main round after it, each board gains a row above/below and a column beyond its outer/crystal side, plus six path tiles. Portal-facing edges do not expand. Sandbox shares the artwork/rule owners but permits manually resized maps and unlimited paths without affecting match settings.

Both portal and crystal stay at exactly the same world positions, as do existing towers/paths. Logical x stays unchanged; logical y shifts down one. The mirrored host board's world origin moves left/up while the guest's centre-facing origin stays horizontally fixed and moves up. The central ravine/portal edges remain stationary. Each growth event frames the enlarged owned board once. Expansion overlays are removed; ordinary snapshots preserve the camera.

Enemies take shortest routes across connected path tiles, not placement order. When more than one next branch has the same remaining shortest distance, the host alternates assignments in stable round-robin order at that fork. Regular and sent enemies share a board's rotation, reset each wave; longer alternatives remain unused. Each enemy receives its complete captured route at spawn. Adjacent path sections can still create shortcuts. Towers and walls do not define routes by blocking otherwise walkable ground.

The whole board grows at the same host-owned milestones for both players, rather than selecting territory to buy. Main round 10 is the first redesign window without growth; rounds 20, 30, 40… each grow once. The +6 allowance supports routing through the new strips without granting either player extra Coins or bypassing connectivity. Final growth/budget balance remains subject to playtests.

The current wave's routing graph and each enemy's assigned shortest route are preserved throughout combat. Redesigning paths happens between waves, not as a tactic for repeatedly redirecting moving enemies.

Buildings also use square-grid placement. Building, upgrading, and selling remain available during combat, but must not invalidate the current route. The intended future relocation system preserves upgrades and traits and is free during breaks only; relocation is not implemented.

Future major upgrades may expand their occupied footprint. Such an upgrade would require surrounding space and could not overlap another building or obstruct the route. Current branches retain one-cell footprints; expanding footprints are not implemented.

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

These are desired action categories, not a fully implemented content list. Construction, upgrades, selling, sends, scouting, tower rerolls, and the support/economy structures below are implemented. Concrete spells/abilities, map interactions, additional building roles, and gambling activities beyond the two rerolls remain open. Direct relocation remains unimplemented; the intended rule permits it free only during breaks. Combat-time construction, upgrades, and selling preserve the current route.

### Abilities across both boards

**Confirmed:** abilities can affect both the player's own board and the opponent's board. Opponent-targeted spells cause temporary disruption, such as briefly slowing or disabling defenses. They cannot permanently destroy opposing towers or directly damage the opponent's base.

Exact effects, eligible targets, resource costs, cooldowns, visibility, and ways to respond remain open. Clear warnings or counterplay for powerful disruption are design proposals to evaluate, not an implemented system. A spell's ability to target the opposing board does not implicitly permit editing its path, violating route locks, or bypassing the open-route requirement.

## Collection, loadouts, and tower growth

### Persistent collection and implemented loadout

The collection permanently unlocks six identities: **Arrow tower, Orc ballista, Rune obelisk, Lightning (working name), War Drums, and Gold Mine**. **Arrow is guaranteed** on fresh saves and after reset. Valid existing saves atomically gain missing starter ownership without losing other unlocks.

Before every run, equip **one to four distinct owned tower types**; unused slots are allowed, an empty loadout is not. Evolution branches stay within their parent slot. In multiplayer both players select together after connection/admission, before any board planning, and both must press **Commit loadout**. Commitment freezes that player's deck for the run. Opponent deck lists and original collection ownership are omitted from targeted snapshots; only choosing/committed status is shared. Placed towers remain discoverable by scouting. Singleplayer has the same selection phase, mirrors the committed deck, and returns to selection on **Play again**.

The host validates every purchase against the frozen admitted loadout, not merely the local palette. A guest's local-save ownership is a trusted-friends claim, not remote save attestation or an account-backed entitlement. Permanent stat growth and currency/reward integration from completed runs remain unimplemented; their strengths, limits, and payout rules are open.

### Implemented collection chest

- **Approved prototype rules:** free collection-screen openings unlock only missing identities, without duplicates. Openings stop when all six are owned.
- **Prototype reset:** confirmed Reset progress atomically returns ownership to Arrow only and clears the previous reveal. Cancel leaves progress unchanged; reset does not affect Sandbox state or lifetime enemy records. Reset is unavailable during an active reveal or save error.
- **Provisional payout odds:** one reward 80% of the time, three 15%, and five 5%; cap to the number still locked. A fresh Arrow-owning collection has five locked identities, so a five-reward opening can grant all five.
- **Content ownership:** each `TowerDefinition` references its `TowerReward` identity/art resource, with one typed catalog registering towers and enemies. Arrow/Rune retain accepted PixelLab runtime art; Gold Mine/Lightning use approved GameLab stills. The original Ballista is archived, and its creator-authorized provisional eight-direction trial uses one fixed base plus host-target-driven weapon layers. Remaining procedural/branch art and the reconstructed Ballista roof are not final art approval. Resource fields and authoring rules live in the [content pipeline](content-pipeline.md).
- **Save ownership:** `CollectionStore` selects rewards and atomically saves the complete unlock set before granting it in memory. Invalid saves or write failures grant nothing and do not silently replace existing data. The local `user://collection.json` belongs to one running instance; there is no cloud sync, account, concurrent-writer coordination, or host-authoritative post-run reward integration.
- **Presentation:** `ChestReveal` displays a supplied reward list using the existing chest poses, shake, light, decorative coins, and simultaneous cards, not a roulette reel. Skip/navigation cannot reroll or grant rewards again.
- **Collection checks:** persistence, reset, exhaustion, and save-error procedures are documented in [development](development.md#collection-and-chest-verification); this status update does not claim a new visual check.

Free prototype openings do not settle completed-run collection currency/chests, permanent duplicates, or permanent stat changes.

### Implemented in-run purchases and randomness

**Choose the identity, randomize its bonuses.** Each successful paid placement rolls **Broken → Shoddy → Common → Uncommon → Rare → Epic → Legendary → Mythic**, then role-compatible attributes. The authored rarity profile defines positive/drawback slot counts, pools, and value bounds; the lowest tiers may have only drawbacks. Attributes include numerical modifiers and compatible mechanics, with no duplicate effects or opposing modifiers on the same stat. Ballista-only Pierce/Bounce cannot appear on Rune; rolled capacities add to compatible purchased mechanics.

Accepted rarity and attributes apply immediately and appear in inspection. There is no pre-purchase preview, choice-of-offers flow, bench, or automatic random placement. Rolls survive evolutions, including transitions to pure support or bounty roles. The shipped prototype enables rolls; custom deterministic configurations can omit `roll_rules`. See the [content pipeline](content-pipeline.md) for exact profiles, bounds, compatibility, and effective-stat rules.

**Reroll rarity** spends run-only **Shards**, excludes the current rarity, renormalizes the same placement weights, and regenerates every attribute. Downgrades are allowed. **Reroll attributes** spends Coins, retains rarity, and regenerates every attribute and value. Each placed tower has independent smoothly accelerating quadratic cost counters (`base + linear × n + quadratic × n²`); rarity rerolls reset the attribute counter, never their own.

The prototype starts a run with **8 Shards**, awards **3 per round clear**, and permits enemy-specific random drops from all registered enemy types, including sent enemies and summons. Drops belong to the killing board. Rerolls work during planning/combat wherever tower management is allowed; committed Ready locks them until combat. The host applies purchases/rerolls and costs atomically: rejected actions change no currency, attributes, counters, or gameplay RNG. Singleplayer rolls an accepted action once and mirrors its result while charging both boards.

Random upgrade/reward offers and gambling beyond these two tower rerolls remain desired but unimplemented. Their cadence, risk, failure outcomes, and exploit safeguards remain open; the existing reroll/rebuy economy still needs balance playtests.

### Implemented tower progression branches

Purchased upgrades and permanent per-tower branch choices replace duplicate merging. The current branches retain one-cell footprints; relocation and larger occupied footprints remain future work.

- **Arrow:** damage/speed → Second Archer → one exclusive branch: Four → Eight Archers → three-crew Arrow Minigun; Fire Arrows → Molotov Cocktails → Quick Pitch → single-operator Flamethrower; or Bomb Arrows → Bigger Explosions → Anti-Orc Grenades → A.O.M. → two 10% Rapid Reload upgrades. See [prices, fuel rules, and verification](archer-advancements.md).
- **Ballista:** upgrades → permanent Pierce 2 (then Bigger Wood I–II and The Biggest Wood I–III) or Bounce 1 (then Magic Ballista, Double Magic, Stronger Magic and S.U.M.G.G.M.); compatible rolled extra hits add to purchased mechanics. The host continuously acquires/reacquires tracking targets independently of reload and released-shot aim; the shared renderer follows only accepted targets using the authored eight weapon views over fixed masonry.
- **Rune:** upgrades → continuous Boulders or Void Monolith, or pulsed Onyx Ring or Storm Sigil, each continuing through three ordered upgrades to an endgame finale; only Boulders can also buy Freeze Runes. Positive Boulders exposure immediately slows every ice-susceptible enemy by 20%, even before fractional damage becomes a whole HP. The host refreshes a nonstacking timer of `2 / (1 + max_hp / 100)` simulation seconds while exposed: higher maximum HP thaws faster, regardless of remaining HP. Leaving range or selling the tower preserves the existing slow until expiry; ice-immune enemies ignore it. Rolled/support modifiers remain effective through those transitions.
- **Lightning (working name):** direct chains choose the nearest eligible unhit enemy within jump distance, hitting each individual at most once per chain for full base damage. The shared Escalating Chain special increases successive-hit damage before Longer Reach expands initial targeting range and jump distance. **Longer Reach is the only current provisional evolution direction**; final identity and any additional choices remain undecided, not an invented finished tree.
- **War Drums:** mixed nearby damage/attack-speed support → permanent Forge (pure damage) or Command Banner (pure speed). Strongest duplicates apply per component within a support group; different groups add together. Purchased bonuses transfer to the remaining pure component.
- **Gold Mine:** round-clear Coins → Royal Mint (retains clear income plus periodic combat-simulation-time production, not interest) or Bounty Board (replaces production with marking). Bounty Board then chooses permanent stronger marking, currently named Greater Bounty, or the Tribute Office income aura. These follow-up names and numerical tuning are provisional.

Bounty Board selects the highest-maximum-HP eligible in-range enemy, resolving ties stably, and holds one exclusive mark until death/crystal arrival even outside range. Another Board must choose another eligible target. Marks increase damage taken and normal Coin bounty; the stronger branch improves marking. The income-aura branch clears its active mark and instead rewards kills by towers located within its range, not enemies dying there. Strongest duplicate income auras apply; another Board's mark can combine with the aura. The host rounds the combined payout once, upward; zero-normal-bounty summons gain no percentage bonus Coins but remain eligible for Shard drops. Tower accounting credits the mark's incremental rounded bonus first, then the remaining bonus to the strongest aura, with oldest-source ties. Generated Coins include this bonus and Mine/Mint production, not ordinary kill bounty. Accounting does not change payout rules. Exact composition and resources are in the [content pipeline](content-pipeline.md).

### Tower growth and reset

All placed towers, rarity, attributes, reroll counters, Coins, Shards, upgrades, and branches are run-specific. The host also retains each tower's cumulative kills, direct damage, generated Coins, and Board indirect damage through upgrades, evolutions, rerolls, and waves. Attacker direct damage and Board amplification partition actual enemy HP loss without double counting or overkill; sub-HP source contributions carry per stream until they become whole HP. Accounting does not change damage rules. These run records do not become permanent collection items. Permanent stat growth and post-run progression rewards remain unimplemented; how victory, defeat, survival, and run length affect future payouts is open.

### Gambling: multiple risk levels

**Confirmed direction:** several kinds of in-run gambling with different stakes. The two tower rerolls are implemented. Wagering currency for random rewards and risking a tower for transformation remain candidates, not shipped systems. Their selection, losses, decline rules, odds disclosure, and safeguards need decisions. No real-money gambling or purchases have been requested.

## Economy and attacking

Sending enemies spends match currency now and increases future income. This creates a tradeoff between immediate defensive investment, economic growth, and pressure on the opponent.

The creator authorized provisional playtest Coins and balance values: host-owned paid towers, role-specific upgrades and branches, kill/wave-clear income, send income, production, bounty bonuses, attribute-reroll spending, and a partial invested-cost sale refund. Send tiers cover Orclings, Orcs, Runner, Brute, Chief, and NecOrcmancer; SkeleOrcs remain summon-only outside Sandbox. Income starts at zero and is paid with the both-board clear reward, not on a wall-clock timer or immediately on purchase. Each accepted send grows that bonus, including a late queued order; terminal defeat pays no clear reward or bonus. Tower production and Shard drops have their own resource-defined rules. These implemented systems do not settle final balance or long-run progression.

Important design risks to address:

- An early income lead becoming impossible to recover from.
- Endless cheap sending becoming the only sensible economic action.
- Buying, selling, and rerolling producing free money or effectively unlimited trait rolls.
- Permanent stats, favorable trait rolls, and reward luck compounding into an overwhelming advantage.

These are risks, not decisions to remove progression, income growth, or randomness.

## World, art, and escalation

**Confirmed:** top-down pixel art, broader fantasy, with orcs as the foundation rather than the only possible faction. Defenses are mostly physical structures rather than stationed characters or creatures. Exact factions, tone, structure roster, palette, asset sources, and pixel resolution are open.

The creator approved the board composition study's overall visual direction: stronger tower/enemy proportions, grounded sprites, layered terrain/path materials, and quieter contextual highlights. The existing-art presentation pass is implemented and rendered in the game; art consistency is not final. [Visual TODO](../TODO.md) preserves the approved reference, actual runtime captures, shared actual-size lineup, and remaining replacement-approval work. The working sprite standard is elevated three-quarter artwork, upper-left lighting, restrained contact shadows, dark readable contours, and deliberate pixel clusters. The square-grid gameplay camera is unchanged in kind; resource-derived visual headroom keeps tall top-row artwork below the fixed HUD.

The follow-up readability correction makes the playable field distinct from darker outer scenery and the central ravine, with a cosmetic external earth edge and quieter continuous stonework. The fixed HUD shows adjacent icon-backed Coin/Shard balances and a continuous blue crystal-health gauge/value; debug sits immediately left of the cogwheel. Alive/mirror counters and tower-palette number hints are absent. Routine text is limited to current facts/actions, and zero income/queues are absent. These are presentation decisions, not changes to usable cells, match rules, or sprite approval.

The run should start small and become increasingly extreme: larger towers, stronger and more spectacular spells, and much higher enemy density. This is a desired experience, not a measured engine capacity or a fixed enemy-count target.

**Design constraints to validate:** players should still be able to understand routes, important threats, and the results of their actions during late-run spectacle. Visual size and simulation footprint are separate decisions. Representative late-run scenes must be measured on the chosen target hardware before performance is claimed.

## Technical direction

- Required engine release and run commands: [development setup](development.md#setup).
- Editing and state-ownership conventions: [AGENTS.md](../AGENTS.md).
- Godot's Compatibility renderer, text-authored scenes/resources, and nearest-neighbor texture filtering are the current starting configuration.
- `resources/content_catalog.tres` is the one authored tower/enemy registration list. `CombatRules.catalog` and the collection share it; combat captures authoritative stats, while UI and renderers resolve the same registered identities. Variants of existing attacks/enemy behavior need resources and one catalog edit; novel mechanics still require code and behavior regressions. Duplicate/invalid entries are rejected, and weighted waves require an always-eligible unlimited weight-one enemy of any ID. Exact authoring and validation rules are in the [content pipeline](content-pipeline.md).
- One authoritative host validates both players' commands and simulates captured routes, enemies, all six tower roles, support, production, marks, rolls/drops, base damage, and results. Clients display detached accepted snapshots; camera position, selection, tool choice, target defaults for future placement, and visual effects stay local.
- **Implemented connection setup:** Play offers Host and Join using Godot ENet. The creator chose no game-hosted online infrastructure. A shared invite contains a numeric host address, UDP port, and fresh random room credential; it admits only one guest. LAN, a private VPN/network, or a reachable public address with UDP forwarding/firewall access is required. The invite is not a short-code lookup service and cannot bypass NAT.
- **Local testing:** Play also offers Singleplayer, with no network connection. After loadout commitment, a mirror opponent repeats accepted path/tower/reroll/send commands and readiness through the same authoritative rules; no independent AI or progression bypass is added.
- **In-match menu:** Escape/cogwheel opens Resume, Settings, and Quit. Solo pauses while multiplayer continues behind its local overlay; no peer can unilaterally freeze the shared run. Quit returns to title through normal session teardown. Music/Sound preferences are local and persistent; match music and combat/transaction effects are implemented.
- MCP/editor bridges are optional development tools, not something players must run.

Host migration, public matchmaking, accounts, monetization, and real-money purchases have not been requested. The game is intended for trusted friends. Real internet play must be checked between separate machines and networks, not inferred from localhost success.

Admission opens private concurrent loadout selection; only both commitments open initial board planning with local owned-side focus. The host validates admitted deck access, cells, paths, funds, tower transactions, rolls, readiness, and pacing; scouting grants no opponent commands. Ready locks own planning mutations, including rerolls. Manual both-ready, normal deadline, and ordinary autoplay use the same legal capture/start gate. Initial/main strategy remains untimed. Paths edit only in an uncommitted strategy phase; tower management resumes in combat.

**Implemented defense slice:** all six tower roles use resource-defined prices, upgrades, rarity pools, and behavior. Towers begin at I, reach II after either base upgrade and III after both, then unlock their authored special/evolution prerequisites and eligible follow-ups. Non-attacking roles upgrade support or production rather than pretending to deal damage. Prices, sale investment/refunds, and accepted effective stats belong to the authoritative model. Direct attackers retain First/Last/Closest/Strongest targeting where applicable, with one host-owned policy per tower used by every archer/operator and preserved through upgrades, evolutions, and reloads. Archers prefer distinct eligible enemies, then share targets when too few remain; shared policy does not force a shared victim. Selected range uses quiet tile highlights. See the [content pipeline](content-pipeline.md) for exact baseline values, roll/support interactions, and role schemas.

**Specials and evolutions:** the implemented branch list is recorded above. Original Arrow, Ballista, and Rune mechanics remain, extended by retained rolled modifiers and support. Rune pulses, continuous Boulders damage, burning, and bounty vulnerability use fractional accumulation where needed rather than amplifying damage through tick cadence. All branch prices and effective strengths are provisional; no branch adds a larger footprint. Authoritative mechanics and resource authoring belong in the [content pipeline](content-pipeline.md).

**Implemented sends:** stable IDs and authenticated payer commands pass one host validator for ownership, funds, phase, committed readiness, and send-unlock round. Only Orclings are sendable in rounds 1–5; later send tiers trail regular-wave introductions, with delayed final NecOrcmancer sends chosen by the creator. Paid orders release through an independent FIFO throughout combat; planning orders wait for wave start. Orcling orders roll a group once, charge once, and retain normal cooldown after the last member. Rejections change no money, income, queues, counters, or RNG. Singleplayer mirrors through the same owner.

The tower palette is limited to the admitted loadout, with funds/Ready locks. Click-select and native drag/drop share owned placement rules. Number/numpad shortcuts retain their slot mapping without displayed hints; B reselects the inspected tower's base identity for a fresh purchase, without a visible Build another button. Inspection pins only a rarity-prefixed title in a distinct static color and X above scrolling accepted stats, attributes, cumulative counters, the tower-wide targeting selector, purchases, rerolls, and refund. All upgrade/evolution choices occupy one consistent scrolling section above Sell, which remains the final action. Received support is labeled **Buff**, and purchased upgrade controls are hidden. Backspace sells the inspected own tower through the same guarded action as Sell; accepted sales play a cash cue respecting Sound settings. Committed planning disables mutations but not inspection. Right-click/Escape cancels selection. Without placement selected, only uncommitted initial/main strategy accepts path strokes.

Regular waves fill a growing integer weight budget with one host-randomized group roster shared by both players. Resource-defined introduction/count/share limits pace Orclings and Orcs into Runner, Brute, Chief, and NecOrcmancer roles. Chiefs heal other living allies in a true circle every five simulation seconds; NecOrcmancers stop to raise bounded SkeleOrcs on their current captured route. All summons must clear before the wave ends. SkeleOrcs retain zero normal Coin bounty, while Shard drops remain intentionally eligible. All rolls/actions remain authoritative, including animation state and per-type cumulative totals.

**Implemented boss:** NecOrcmancer Mancer is a distinct slower, heavy-weight, unsendable enemy with a guaranteed round-40 debut and gradually increasing occasional later encounters, capped at one per wave. It summons ordinary NecOrcmancers, which retain their own SkeleOrc rituals. The host reserves boss weight before ordinary selection and validates acyclic summon chains. The normal NecOrcmancer's movement multiplier is now 0.50 rather than 0.55; the boss uses 0.30. Shared HP now gains one baseline point per completed round rather than two, retaining starting health and type ratios. Exact provisional values live in the [enemy roster](enemy-roster.md).

**Late bosses:** the round-60 **Trollorc** and round-100 **Orc king war orchine** extend that encounter contract; all three boss types can coexist in later waves and none is sendable. Trollorc retains 1.5× nonphysical damage vulnerability, collateral stomps, and nearest-tower 30-second club stuns. Orchine follows its captured painted route on wheels, periodically advances 2–5 route tiles through leg deployment/crouch/jump/landing, stuns two distinct random towers, and deploys increased infantry batches. Its fire/lightning incoming multipliers are 1.2×/0.9×. Every tower role is inactive while stunned, including support, production, marking and income auras; previously applied burns persist. Stable internal IDs retain existing records despite renamed titles. Host-owned rolls, timers and outcomes remain separate from cosmetic poses/stars/audio. [Enemy roster](enemy-roster.md#late-game-bosses) owns provisional values and verification.


Movement progression is now diminishing and additive: each additional 10% of the original baseline takes successively longer spans of 5, 10, 15, 20… completed rounds, with interpolation between milestones. Per-type ratios remain unchanged, and health/count/spawn-cadence/playback scaling stay independent. The host's admitted rules own actual movement and preview speeds; client configuration cannot accelerate accepted enemies.

All ten enemies have real walk animation, with separate ability poses, stable anchors/facing, current-frame alpha picking, and blue slowed palettes. Orcieary previews reuse those frames and show encounter/send availability, stats, descriptions, and saved owned-side kills/sends; bosses preview their own debut rounds rather than wave one. Exact rules and provisional balance live in [enemy roster and sandbox](enemy-roster.md), with one resource catalog for authoring. Real 1v1 pressure, long-run density/performance, and separate-network reachability still need human validation.

**Towerieary:** a separate read-only tower guide exposes every catalog identity through connected artwork nodes, including parallel stat upgrades, evolution splits, follow-ups, role-specific stats, and cumulative costs. Previews run through an isolated combat model rather than duplicating upgrade formulas or touching collection, match, or network state. The interface uses compact X/Escape navigation without an explanatory footer, hover popups, ownership labels, visible scrollbar chrome, or a file-explorer-style text tree.

**Implemented Arrow advancements:** the three exclusive entry choices now have complete late-game chains. Eight archers occupy two decks and use one tower-wide targeting policy, retaining distinct accepted targets, aim, and shot origins, before merging into a single twenty-archer-rate stream with three crew. Molotovs/grenades use thrown splash; Flamethrower uses stronger focused continuous FIRE damage, longer burn, and a host-owned 60-second uninterrupted firing / 6-second mandatory refuel cycle. A.O.M. trades cadence for heavy circular explosions, then buys two multiplicative 10% reload improvements. Guide nodes and portraits share battlefield art; deep branches scroll at readable sizes. See [rules, provisional balance, and exercised verification](archer-advancements.md).

**Implemented results/playback:** both modes display the accepted local Victory/Defeat outcome and final match details with inspection/menu actions. Solo Play again returns to loadout selection for a fresh run and cycles 1×/2×/3× speed; multiplayer retains unanimous 2× consent. The completed model never restarts, countdowns stay real time, and progression is not granted by the result UI. See [results and playback](match-results.md).


## First playable proof of the core rules

The original first implementation milestone was deliberately smaller than the full direction, proving the coupled maze, combat, and economy rules before the later collection/loadout and six-role expansion:

1. Two players connect, each with a board and camera access to inspect the opponent.
2. At least one known tower type and one enemy type support a basic defense loop.
3. Each player draws a legal path within an equal tile budget. Enemies follow the chosen route; route edits are unavailable during the current wave.
4. Construction, individual upgrades, and selling work during combat without obstructing the route. Intended relocation/expanded-footprint rules remain unimplemented, rather than prerequisites already delivered by this milestone.
5. Regular waves threaten both bases. Sending enemies costs currency and increases the sender's future income. Each opponent-bound FIFO stream runs throughout combat independently of regular spawns; planning orders wait until combat starts. Pending sends prevent premature clearance.
6. Both players observe consistent currency, income, enemy state, health, and match results.
7. A base reaching zero health ends the run. Same-tick destruction of both bases is resolved by one host-owned random coin flip.

The current slice goes beyond that initial milestone with private four-slot loadouts, six tower identities and their branches, randomized purchases, role-compatible attributes, two rerolls, Shards/drops, support overlap, production/bounty rewards, authoritative planning, committed readiness/deadlines, ten-round strategy phases, repeated map growth, paid construction/management, kill/wave/send income, weighted waves, split shortest routes, results, and local four-way/zoom scouting. Relocation, expanding tower footprints, commanders/spells, permanent stat growth, and post-run progression rewards are not implemented.

## Decisions still needed before their implementation

- **Board interaction:** final growth/budget tuning, long-run size limits, initial endpoint/art choices, and future relocation/footprints. Current timing and three-edge growth away from the portal are explicit rules.
- **Run pacing:** final boss balance/later-encounter frequency, encounters beyond current numbered waves, weighted/scaling/economy tuning, and endgame pressure. Guaranteed boss debuts at rounds 40/60/100, committed Ready, normal 20-second windows, untimed initial/main strategy, preserved autoplay consent, and terminal coin flips are confirmed.
- **Commanders, towers, and enemies:** choose between commander-linked boards and independent commander/map selection; define commander rules, additional archetypes, defenses, and counters. The six-role/ten-enemy roster and all authored stats remain provisional. Lightning still needs a final identity and decisions about any evolution directions beyond the current Longer Reach; no additional branch has been agreed.
- **Active systems:** concrete ability effects on both boards and their targeting, costs, warnings, and counterplay; map interactions; additional building roles; and gambling activities beyond the two implemented rerolls.
- **Randomness and progression:** final rarity/attribute odds, bounds, slot counts, reroll/drop economy tuning, sale/rebuy safeguards, random run reward offers, permanent duplicate handling/stat growth, and post-run payouts. Four distinct owned slots, guaranteed Arrow, private pre-match commitment, immediate accepted-roll display, and both reroll semantics are implemented rules, not undecided placeholders.
- **Balance and readability:** intended duration, economic scaling, late-run density, visual hierarchy, and performance targets.
- **Delivery:** desktop operating systems, future save ownership beyond the current local collection, and separate-machine/network connection verification.
