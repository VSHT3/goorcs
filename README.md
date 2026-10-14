# Gorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Playable local path workshop, persistent collection/chests, and host-authoritative two-player defense through **Play**, with a local **Singleplayer** mirror opponent for testing. Matches use one continuous camera-scrolled world behind a fixed HUD; each player starts looking at their own side and holds **A / D** to scout across it. Match Coins, paid towers, kills, damage/speed upgrades, selling, tile ranges, Rune area attacks, scaling waves, enemy sends with recurring income, persistent base health, and results are implemented. Loadouts, permanent stat growth, map expansion, and final art are not implemented.

The UI pairs bundled **Pixelify Sans** labels with crisper **Silkscreen** pixel numerals for prices, health, stats, and counts. Small interface text stays at least 16px. Both fonts work offline and include their [Pixelify](assets/fonts/OFL.txt) and [Silkscreen](assets/fonts/silkscreen/OFL.txt) licenses.

## Run

Use the standard Godot edition and the [required engine release](docs/development.md#setup). Import `project.godot` into Godot and press **F5** to run the project.

For command-line launch and verification, see the [development commands](docs/development.md#setup).

## Test solo

- Choose **Play → Singleplayer** to start immediately without a connection, port, or invite.
- The initial view shows your own side of the continuous world. Hold **A / D** to inspect the mirrored opponent; the HUD stays fixed and opponent-side input remains read-only.
- The opponent mirrors accepted path edits, tower purchases, targeting, upgrades, sales, enemy sends, and readiness. Pressing **Ready** starts both boards.
- Collection locks, prices, combat, wave breaks, and results use the same rules as multiplayer. Identical defenses can end in the existing simultaneous-defeat coin flip; this is a testing opponent, not AI.
- **Leave / Esc** ends the local run. Opening Singleplayer again starts fresh without changing workshop layouts or collection progress.

## Play with a friend

- Choose **Play → Host**, enter an IP address your friend can reach and a UDP port, then **Create room**.
- Use **Copy invite code** and share the complete code privately. Your friend chooses **Play → Join**, pastes it, and presses **Connect** or Enter.
- Admission automatically opens shared planning in one continuous world: host on the left, guest on the right, with your own side filling the initial gameplay view. Hold **A / D** to pan smoothly left/right and inspect the opponent; movement stops at the outer edges. Only your own board accepts edits, wherever the camera is looking. Match paths are separate from the local workshop and are not saved.
- Wave/Coins, health/readiness, Leave, and tower controls stay in a fixed HUD over a separate world viewport. Tower management and notices overlay the world rather than moving or resizing it. Camera movement stays local and does not change match state; text fields and targeting popups take priority over A/D.
- The visible tower palette shows all types, prices, and collection locks. Click a tower then empty non-path ground, or drag it onto your board. Right-click or Escape cancels placement. Clicking an owned tower opens its kills, stats, targeting, damage/speed upgrades, and Sell menu.
- During planning breaks, no tower selected automatically enables path editing: left-drag places tiles, right-drag removes them. Existing towers remain inspectable. During waves, no tower selected only inspects; paths stay locked. Only your own board accepts commands; building and target changes remain available during combat.
- **Ready for wave N** requires a legal path. Accepted path edits, purchases, upgrades, sales, and target changes clear planning readiness. Both players ready captures routes and starts the wave; paths remain locked until both boards clear.
- Arrow and Ballista hit one target. Rune damages every enemy in its surrounding 3×3 tile neighborhood and displays a circular pulse. Selected range is highlighted tiles, not a circle. All types support Furthest, Closest, and Strongest targeting.
- Enemy visuals move smoothly between host snapshots along the captured route, including corners. Adjacent path tiles form continuous pavement through straights, bends, and branches, without a route-line overlay.
- Each match entrance is a red stone-ring portal and each base is a blue crystal on a stone pedestal. These transparent PNG sprites were authored locally, without external generation services or costs. Camera scouting does not expand either grid or increase its path-tile budget.
- A destroyed base ends the run. If both bases reach zero in the same host simulation tick, one host-owned random coin flip chooses the winner and both players see that result. The finished run cannot restart; leave/rejoin begins fresh.
- Coins fund towers and two one-time upgrades per tower; kills and cleared waves earn Coins. Selling refunds part of the actual investment. Wave health, speed, and count increase. Provisional values live in `resources/combat/prototype.tres` and `resources/combat/towers/`.
- One **Send now / Send next** button spends 20 Coins to put one existing wave-scaled enemy on the opponent's route and adds +2 recurring Coins at each future both-board wave clear. Orders during the first 3 seconds of combat deliver immediately; planning and later orders queue for the next wave. The host accepts payment, delivery, and income together; rejected sends change nothing. `Income +N/clear` shows your recurring bonus; `Qincoming/outgoing` shows next-wave queues. These values are provisional and live in the same combat resource.
- The code contains the host's address and a random room credential. There is no online room lookup or NAT traversal service. Use the same LAN, a private network/VPN, or a public host address with UDP forwarding and firewall access.
- **Leave / Esc** closes your connection and clears shared planning. If the guest leaves, the host waits for another guest with the same code; rejoining starts with fresh boards. If the host leaves, the room closes and its code expires.
- For network setup, security limits, and two-instance verification, see [direct connection development](docs/development.md#direct-connection-lobby).

## Collection and chests

- Choose **Collection**, then **Open free chest**. The chest shakes, opens with light and decorative coins, and reveals the actual rewards together. There is no roulette reel.
- Unlock Arrow tower, Orc ballista, and Rune obelisk. Saved unlocks control your placement-menu options. Collection resources supply stable identity/artwork; separate combat resources supply tower stats. All three can now be placed and fight in matches.
- All three towers use accepted PixelLab sprites with unchanged source PNGs. Arrow tower is the selected green-bannered stone-and-timber tower with a pink-haired archer and bow. All three share a consistent square display size in the collection and chest cards, preserving proportions.
- The orc chest uses cleaned user-supplied PixelLab sprites. Its lid transitions between closed/open poses; light and coin effects remain native Godot effects. Sound is not implemented yet.
- Provisional reward-count odds are 80% for one, 15% for three, and 5% for five. Draws contain only locked types and are capped to those remaining; the three-type roster cannot grant five actual rewards.
- **Skip reveal** changes only the animation. Rewards are saved before it starts; leaving and returning cannot reroll or grant them again.
- Unlock all three types to complete the collection; further openings are disabled.
- **Reset progress** clears all saved collection unlocks after confirmation, so you can open chests again. It also clears the previous reward display, but leaves the workshop layout unchanged.
- Collection unlocks survive restarting on this computer. Workshop layouts still last only for the running session. See [save ownership and verification](docs/development.md#collection-and-chest-verification).

## Path workshop

- Choose **Workshop** from the main menu. **Menu** or Esc returns to it; **Resume workshop** or Esc resumes without clearing tiles.
- Menu navigation preserves the layout only for this session. **Quit** exits; layouts are not saved after quitting.
- Left click or drag to place tiles; right click or drag to remove them. **Clear tiles** resets the board.
- Only shared edges connect. Entrance and base are fixed and do not spend budget.
- Unused budget is allowed. A ready layout connects the base and every placed tile to the entrance.
- Enemies use the shortest route, not placement order. Branches and adjacent sections can create shortcuts; there is no route-line overlay.
- The 14×9 board, opposite-side endpoints, and 30-tile maximum are provisional. Adjust the main scene's exported settings together in the Inspector.

This workshop does not simulate waves, enemies, or combat-time route locking.

## Documentation

- [Game brief (PDF)](docs/goorcs-brief.pdf): a three-page introduction for friends, with [editable source](docs/goorcs-brief.typ).
- [Agent instructions](AGENTS.md): required reading, editing rules, state ownership, and completion criteria.
- [Game direction](docs/game-direction.md): intended experience, technical decisions, and first playable milestone.
- [Development workflow](docs/development.md): setup, verification, and optional MCP tooling.
- [Pixel-art archive](archive_assets/README.md): original candidates, prepared sprites, searchable tags, and source provenance; excluded from Godot imports.

## Layout

```text
project.godot       Engine settings and main scene
AGENTS.md          Repository editing instructions
scenes/            Main navigation, connection lobby, shared defense, local path workshop, collection, chest reveal
scripts/           Rule owners, networking, persistence, input, and presentation
resources/collection/  Tower reward definitions
resources/combat/  Provisional defense-loop configuration
assets/            Imported chest/tower sprites and locally authored match crystal/portal PNGs
archive_assets/    Archived pixel-art variants and sources, with per-image catalog and tags
tests/             Path, navigation, collection, chest, real peer-session, planning, match-world, combat rules and peer combat
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
