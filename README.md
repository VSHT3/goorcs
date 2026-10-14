# Gorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Playable local path workshop, persistent tower collection and animated reward chests, plus a host-authoritative two-player Arrow-defense loop reached through **Play**. Shared mazes, regular waves, live tower placement/targeting, persistent base health, and final results are implemented. Match economy, enemy sends, upgrades, selling, loadouts, permanent stat growth, and final art are not implemented. No MCP plugin is installed.

## Run

Use the standard Godot edition and the [required engine release](docs/development.md#setup). Import `project.godot` into Godot and press **F5** to run the project.

For command-line launch and verification, see the [development commands](docs/development.md#setup).

## Play with a friend

- Choose **Play → Host**, enter an IP address your friend can reach and a UDP port, then **Create room**.
- Use **Copy invite code** and share the complete code privately. Your friend chooses **Play → Join**, pastes it, and presses **Connect** or Enter.
- Admission automatically opens shared planning: both boards are visible, but only your own accepts edits. Match paths are separate from the local workshop and are not saved.
- Both enemy streams enter from the middle, with bases on the outer edges. Use **Place tower** to select **Arrow tower**, then click empty non-path ground to build. Choose **None** or right-click to cancel placement. With no tower selected, click an existing own tower to inspect it and choose **Furthest**, **Closest**, or **Strongest** targeting.
- During planning breaks, no tower selected automatically enables path editing: left-drag places tiles, right-drag removes them. Existing towers remain inspectable. During waves, no tower selected only inspects; paths stay locked. Only your own board accepts commands; building and target changes remain available during combat.
- **Ready for wave N** requires a legal path. Editing paths, building, or changing targeting during planning clears your readiness; **Unready** withdraws it. Both players ready starts each regular wave and captures its routes. Paths cannot change until all scheduled enemies and both boards clear.
- Arrow attacks deal instant-hit damage in circular range. Enemies follow the captured shortest routes; a leak deals one base damage. Paths, towers, and base health persist between waves. Both players must ready again.
- A destroyed base ends the run. If both bases reach zero in the same host simulation tick, one host-owned random coin flip chooses the winner and both players see that result. The finished run cannot restart; leave/rejoin begins fresh.
- Combat numbers are provisional settings in `resources/combat/prototype.tres`, referenced by the main scene's exported combat rules. Arrow access is independent of collection unlocks. Free placement proves defense, not the unimplemented match economy.
- The code contains the host's address and a random room credential. There is no online room lookup or NAT traversal service. Use the same LAN, a private network/VPN, or a public host address with UDP forwarding and firewall access.
- **Leave / Esc** closes your connection and clears shared planning. If the guest leaves, the host waits for another guest with the same code; rejoining starts with fresh boards. If the host leaves, the room closes and its code expires.
- For network setup, security limits, and two-instance verification, see [direct connection development](docs/development.md#direct-connection-lobby).

## Collection and chests

- Choose **Collection**, then **Open free chest**. The chest shakes, opens with light and decorative coins, and reveals the actual rewards together. There is no roulette reel.
- Unlock Arrow tower, Orc ballista, and Rune obelisk. Collection resources supply identity/artwork, not combat stats. The match currently implements only Arrow; Ballista and Rune have no combat behavior, and collection progress does not gate prototype placement.
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
- The green line previews the shortest route, not placement order. Branches and adjacent sections can create shortcuts.
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
assets/            Imported chest and tower-trio sprites
archive_assets/    Archived pixel-art variants and sources, with per-image catalog and tags
tests/             Path, navigation, collection, chest, real peer-session, planning, combat rules and peer combat
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
