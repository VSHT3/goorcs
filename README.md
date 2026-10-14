# Goorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Playable local path workshop, persistent tower collection and animated reward chests, plus direct two-player connection and host-authoritative shared maze planning reached through **Play**. Combat, loadouts, permanent stat growth, and final art are not implemented. No MCP plugin is installed.

## Run

Use the standard Godot edition and the [required engine release](docs/development.md#setup). Import `project.godot` into Godot and press **F5** to run the project.

For command-line launch and verification, see the [development commands](docs/development.md#setup).

## Play with a friend

- Choose **Play → Host**, enter an IP address your friend can reach and a UDP port, then **Create room**.
- Use **Copy invite code** and share the complete code privately. Your friend chooses **Play → Join**, pastes it, and presses **Connect** or Enter.
- Admission automatically opens shared planning: both boards are visible, but only your own accepts edits. Match paths are separate from the local workshop and are not saved.
- Draw a legal route, then press **Ready**. Editing clears your readiness; **Unready** withdraws it before both players confirm. Once both are ready, the host captures and locks both shortest routes. Combat is not implemented; this is the end of the current planning slice.
- The code contains the host's address and a random room credential. There is no online room lookup or NAT traversal service. Use the same LAN, a private network/VPN, or a public host address with UDP forwarding and firewall access.
- **Leave / Esc** closes your connection and clears shared planning. If the guest leaves, the host waits for another guest with the same code; rejoining starts with fresh boards. If the host leaves, the room closes and its code expires.
- For network setup, security limits, and two-instance verification, see [direct connection development](docs/development.md#direct-connection-lobby).

## Collection and chests

- Choose **Collection & chests**, then **Open free chest**. The chest shakes, opens with light and decorative coins, and reveals the actual rewards together. There is no roulette reel.
- Unlock Arrow tower, Orc ballista, and Rune obelisk. These are collection identities with original icons, not implemented combat units.
- All three towers use accepted PixelLab sprites with unchanged source PNGs. Arrow tower is the selected green-bannered stone-and-timber tower with a pink-haired archer and bow. All three share a consistent square display size in the collection and chest cards, preserving proportions.
- The orc chest uses cleaned user-supplied PixelLab sprites. Its lid transitions between closed/open poses; light and coin effects remain native Godot effects. Sound is not implemented yet.
- Provisional reward-count odds are 80% for one, 15% for three, and 5% for five. Draws contain only locked types and are capped to those remaining; the three-type roster cannot grant five actual rewards.
- **Skip reveal** changes only the animation. Rewards are saved before it starts; leaving and returning cannot reroll or grant them again.
- Unlock all three types to complete the collection; further openings are disabled.
- **Reset progress** clears all saved collection unlocks after confirmation, so you can open chests again. It also clears the previous reward display, but leaves the workshop layout unchanged.
- Collection unlocks survive restarting on this computer. Workshop layouts still last only for the running session. See [save ownership and verification](docs/development.md#collection-and-chest-verification).

## Path workshop

- Choose **Open workshop** from the main menu. **Menu / Esc** returns to it; **Resume workshop** or Esc resumes without clearing tiles.
- Menu navigation preserves the layout only for this session. **Quit** exits; layouts are not saved after quitting.
- Left click or drag to place tiles; right click or drag to remove them. **Clear placed tiles** resets the board.
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
scenes/            Main navigation, connection lobby, shared planning, path workshop, collection, chest reveal
scripts/           Rule owners, networking, persistence, input, and presentation
resources/collection/  Tower reward definitions
assets/            Imported chest and base ballista sprites
archive_assets/    Archived pixel-art variants and sources, with per-image catalog and tags
tests/             Path, navigation, collection, chest, real peer-session and shared-planning regressions
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
