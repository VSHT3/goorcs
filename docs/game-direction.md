# Game direction

## Intent

Goorcs is a private game for its creators and a small group of friends. It combines top-down 2D pixel-art tower defense with roguelite and gacha-style collection or reward ideas. BTD Battles is a reference for opposing boards and sending enemies, not a source of assets or code.

## Established preferences

- Downloadable desktop game; exact supported operating systems remain to be selected.
- Players can view both sides and move the camera to inspect the opponent's board. This does not mean walking a player character across the map.
- Players defend their side and can send enemies to the opponent.
- Development should be mostly prompts and playtesting, with the agent handling implementation.
- Either player hosting with some connection setup or a small hosted service is acceptable.

## Technical baseline

- Engine release and implementation conventions: [development setup](development.md#setup) and [agent instructions](../AGENTS.md).
- Compatibility renderer and nearest-neighbor texture filtering as the starting point for 2D pixel art.
- Text-authored scenes and resources, kept under Git.
- No required MCP dependency. Editor automation is development tooling, not a game feature.

## Proposed multiplayer approach

Start with 1v1 and one authoritative host simulating both boards. Clients send gameplay commands; the host validates them and distributes the resulting state. Camera movement stays local.

Godot's ENet transport with a private network tool such as Tailscale is the initial recommendation, not an implemented or finalized connectivity choice. A small hosted match server is another acceptable option. Direct internet connections, relays, firewall behavior, and host disconnect handling must be exercised on real machines before claiming internet multiplayer works.

The initial design assumes trusted friends. Host migration and public matchmaking are not part of the first playable milestone.

## First playable milestone

1. Two players connect to one match.
2. Each has a board and can inspect the opponent's board with the camera.
3. One tower type attacks one enemy type following a path.
4. Currency can buy a tower or send enemies to the opponent.
5. Both players observe consistent currency, enemies, health, and match results.
6. A clear win/loss condition ends the match.

This milestone is planned work; the current project only displays its title.

## Design questions to resolve later

- Exact target desktop operating systems and players per match beyond the initial 1v1 assumption.
- Tower placement, path layout, economy, and match pacing.
- Whether roguelite rewards apply during a match, between matches, or both.
- What gacha-style rewards contain, how they are earned, and how progression affects fairness.
- Save ownership and persistence rules.
- Art resolution, palette, UI style, and asset sources.

No real-money purchases, public accounts, or monetization requirements have been specified.
