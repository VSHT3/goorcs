# Development workflow

## Setup

1. Install the standard Godot **4.7.2 stable** executable from the [official downloads](https://godotengine.org/download/). Keep collaborators on the same version; upgrade deliberately.
2. Clone the private repository and import `project.godot` into Godot.
3. Run the main scene with F5. Choose **Workshop** from the main menu.

No Node.js, .NET SDK, external packages, export templates, or MCP servers are required to run the current project in Godot. Export templates will be needed when distributing desktop builds.

The commands below assume the Godot binary is available as `godot`; substitute its absolute path if necessary.

```sh
# Confirm the installed version matches the required release above.
godot --version

# Open the editor.
godot --editor --path .

# Run the project.
godot --path .

# Import resources without opening a graphical editor.
godot --headless --path . --import

# Smoke-run the current main scene, then quit.
godot --headless --path . --quit-after 10

# Run path-rule regressions.
godot --headless --path . --script tests/path_layout_test.gd

# Run navigation and drawing-state regressions.
godot --headless --path . --script tests/navigation_test.gd

# Run collection grant and save-failure regressions.
godot --headless --path . --script tests/collection_store_test.gd

# Run chest presentation lifecycle and layout regressions.
godot --headless --path . --script tests/chest_reveal_test.gd

# Run collection-screen navigation and grant regressions.
godot --headless --path . --script tests/chest_flow_test.gd

# Run real multi-process connection/authentication regressions.
godot --headless --path . --script tests/multiplayer_session_test.gd

# Run real two-process shared-planning regressions.
godot --headless --path . --script tests/match_planning_test.gd

# Run deterministic combat-rule regressions.
godot --headless --path . --script tests/match_combat_test.gd

# Run real two-process combat/result regressions.
godot --headless --path . --script tests/match_multiplayer_test.gd

# Run rendered tower-size regressions (requires a graphical renderer).
godot --path . --script tests/tower_icon_test.gd
```

A headless pass verifies that the project loads and runs, not that the visuals or interactions are correct. Inspect runtime errors as well as the exit status.

## Repository editing rules

Read [AGENTS.md](../AGENTS.md) before editing. It owns implementation conventions, future state-ownership constraints, scope boundaries, and completion requirements. This document owns the engine release and executable commands; update them here rather than maintaining duplicate copies.

## Verification as the game grows

For a gameplay change, run the game and exercise the changed action. Use screenshots and input automation where available, plus human playtesting for feel and balance.

For networking changes, launch separate host and client processes and verify the resulting authoritative state. Before declaring internet support, play a match between separate machines and networks; localhost is not proof of NAT traversal or acceptable latency.

The first multiplayer milestone should be completed before building extensive progression and content systems.

### Interface hierarchy

Persistent UI text is limited to actions, phase/result, health, readiness, path budget, enemy counts, collection state, and relevant Arrow stats. Instructions, odds, descriptions, and connection guidance live in control tooltips. Gameplay/workshop rejection notices expire after 3.5 seconds, including during idle planning; connection and save errors remain visible.

Cleanup verification exercised menu/workshop/collection/lobby and two real gameplay peers in rendered 1280×720 and 1000×720 subviewports, including live targeting, ordinary/coin-flip results, rejoin, visible errors, and idle notice expiry. The unchanged reset warning was visually inspected; reset/cancellation behavior remains covered by the passing chest-flow regression. Linux save-directory preservation and corrected `GORCS1` peer admission also passed. PDF/brief files were intentionally unchanged.

## Direct connection lobby

**Play → Host / Join** uses built-in ENet; there is no game-hosted signaling, room-code lookup, or relay service, and no additional runtime package is required. One host admits one guest using native `SceneMultiplayer` authentication. `MultiplayerSession` exclusively owns the tree's default multiplayer API while active; future match networking must reuse that owner rather than install a competing peer.

Host with a numeric IP address your friend can reach:

- Same LAN: use the host's LAN address and allow the selected UDP port through its firewall.
- Private VPN/network: both players must already belong to that network; advertise the host's VPN address. Tailscale is an optional example, not installed or configured by this game.
- Public internet: advertise the public/routable address. Forward the chosen UDP port to the host computer if required and allow it through the firewall. Carrier-grade NAT may prevent forwarding; this game does not solve it.
- Two processes on this computer: use `127.0.0.1`. That address cannot connect a friend on another machine.

The host copies the full `GORCS1/address/port/credential` invite; the guest pastes it into Join. The default hosting port is UDP 7000, and both sides use the port encoded in the invite. The credential is regenerated for each new hosting attempt. After the Gorcs name correction, both players need the updated build and a fresh `GORCS1` invite; the former spelling is not accepted. Never publish a live code: it exposes the address and permits room admission. ENet traffic and its authentication exchange are not encrypted; use trusted networks or an encrypted private VPN if confidentiality is needed.

The creator reported successful friend admission over a shared hotspot after allowing the selected UDP port through the host's UFW firewall. This confirms that LAN setup, not reachability across separate internet networks.

Wrong credentials, incompatible invite/authentication versions, malformed endpoints, occupied ports, full rooms, and unreachable hosts fail visibly without admitting another player. Connecting has a bounded deadline and can be cancelled. The guest can leave and rejoin the same waiting host; leaving as host closes the room and invalidates its code. Returning to the menu or closing the lobby releases the connection and listening port. No host migration or automatic reconnect is implemented.

The regression command above launches three real Godot processes and covers admission, wrong/version/full rejection, an unfinished authentication deadline, cancellation, leave/rejoin, fresh credentials, host loss, node exit, and cross-process port reuse. Worker commands, results, and logs use isolated temporary files and do not touch the real collection save.

Graphical verification exercised Play/Host/Join, full-code clipboard copy, invalid-code correction with Enter, two-player admission, guest leave/rejoin, and host disconnection. Main/host and compact guest/error surfaces were inspected at 1280×720 and 1000×720. Navigation regressions also verify that Esc exits Play while a text field is editing, without affecting local workshop progress.

For a two-instance manual check, launch the project twice with the run command in Setup. Host in one using `127.0.0.1`, copy its invite into Join in the other, and check that both open planning with two boards. Leave as guest, rejoin, then leave as host and inspect the guest's disconnect error. For internet verification, repeat on two separate machines and networks with the actual forwarding/private-network setup. Localhost success does not establish internet reachability; that check remains outstanding.

Admission automatically opens shared planning. Both streams enter from the middle and move toward the outer bases; the left board mirrors presentation and input coordinates without changing authoritative route coordinates. **Place tower → Arrow tower** enables free Arrow placement on empty non-path ground. **None** or right-click cancels placement. With none selected, breaks automatically allow left-drag path placement and right-drag removal; clicking existing own towers inspects them rather than attempting a path edit. During waves, none selected only inspects. **Clear my tiles** clears your paths. Select an existing tower and use **Target** to choose Furthest, Closest, or Strongest. Construction and targeting work during planning and combat. Path edits cannot overlap towers.

**Ready for wave N** requires a legal connected path. Accepted path edits, tower placement, or actual targeting changes during planning clear that player's readiness. **Unready** withdraws it before both confirm. Both-ready captures the shortest routes and starts a regular wave; path edits, clear, and readiness are locked until both boards finish every scheduled spawn and clear. Towers, paths, and base health persist across planning breaks. Every next wave again requires both-ready. A base reaching zero ends the run; if both reach zero in the same host tick, one host RNG coin flip selects the winner. Finished outcomes cannot be rerolled or restarted. Leave/Esc closes the session.

`MatchPlanning` reuses `MultiplayerSession`'s authenticated API; it never installs a second peer. It owns authoritative `PathLayout` instances and a host-only `MatchCombat`, and validates host-player and remote commands through the same rules. Remote sender identity determines board/tower ownership. Clients receive reliable accepted snapshots; UI layouts and combat dictionaries are detached mirrors. A post-admission snapshot request avoids exposing guest commands before synchronization. Static commands/phase transitions publish full snapshots; in-wave combat snapshots publish every 0.1 seconds without rebuilding path mirrors. Planning paths and match towers are separate from workshop drafts and collection saves.

The planning regression launches separate host/guest Godot processes with deliberately different local configurations. It verifies distinct legal mazes and shortest routes agree, ownership/bounds/endpoints/budget rejections preserve state, illegal paths cannot ready, edits invalidate readiness, unready works before a wave, captured routes reject combat-time edits/clear/unready, and disconnect/rejoin yields fresh boards. Workers use isolated temporary files and never touch collection saves.

Initial planning-only graphical verification exercised Play/Host/Join, distinct mouse-built paths, read-only opponent input, Ready, readiness invalidation, removal, route locking, Esc, waiting, and Leave. The defense-loop verification below supersedes its old terminal locked-route screen.

### Combat simulation and verification

`CombatRules` and `resources/combat/prototype.tres` hold provisional playtest stats, referenced by the main scene's exported `combat_rules`. This slice implements one regular enemy and fixed-stat Arrow towers with free placement independent of collection unlocks. There is no currency, sending, purchase RNG, upgrading, selling, relocation, loadout gating, or post-run reward grant.

The host advances `MatchCombat` with fixed physics deltas. Enemy positions interpolate along captured grid routes. Scheduled spawns are equal on both boards; later waves apply configured enemy HP growth. Arrow attacks are instant-hit; targets must be in inclusive circular range. Furthest compares route progress, Closest compares squared distance to the tower, and Strongest compares current HP. All equal scores use lowest enemy ID. Attacks resolve before leak bookkeeping, so a killed enemy cannot damage a base. Leaks on both boards are batched before resolving defeat; only same-tick destruction of both consumes one host RNG draw. Selection, range outlines, and shot traces are cosmetic.

Combat-rule regressions verify policy-specific damage distributions, current-HP targeting, range boundaries/ties, immutable captured routes, killed enemies never leaking, pending-spawn gaps and both-board clearance, persistent health/towers, next-wave health growth, ordinary wins without randomness, and one frozen simultaneous-defeat roll. Real separate-process combat regressions verify owned live tower commands and all modes, rejected path/bounds/overlap/mode/ownership commands, readiness invalidation, combat path locks, both-ready wave transitions, host configuration replication, persistent damage, ordinary results, simultaneous coin-flip agreement, terminal command rejection, and fresh rejoin.

Graphical separate host/guest processes exercised actual Path/Tower controls, mouse-built paths, live Arrow placement/selection, native popup selection of all target modes, enemies and health bars, range outlines and shot traces, both-ready starts and breaks, ordinary win/loss, host-owned coin-flip results agreed by both peers, rejoin, Esc, and Leave. Visible Godot subviewports rendered at 1280×720 and 1000×720 because the compositor controls desktop window dimensions. Standard/compact gameplay, planning breaks, and results were inspected without clipping. The runtime used Intel OpenGL after NVIDIA driver warnings; isolated saves preserved real collection progress.

Center-entry and contextual-input verification exercised two rendered Godot peers: mirrored click coordinates, independent center-facing routes, menu-selected Arrow placement, right-click cancellation, no-selection inspection during breaks and combat, combat path locks, live construction, and automatic path editing in the next break. Wave and break screenshots were inspected. Navigation, separate-peer planning, separate-peer combat, resource import, and main-scene smoke passed.

For a manual check, connect two instances and draw different legal paths. Build Arrow towers on one side, select them, and switch all target modes. Ready just one player and verify no wave starts; ready both and inspect movement, hits, kills, and leaks on both boards. Try changing the path during combat: it must be rejected, while construction and targeting remain available. After both boards clear, verify damage and towers persist and both must ready again. An ordinary destroyed base must produce opposite Won/Lost screens. For a quick simultaneous-defeat check, use matching routes and no towers; both bases should fall together and display the same coin-flip winner. Leave/rejoin resets paths, towers, health, and wave state. Internet verification still requires separate machines and networks.

## Optional Godot bridges

### Coding-Solo/godot-mcp

[Repository](https://github.com/Coding-Solo/godot-mcp)

MIT-licensed bridge for launching Godot, capturing debug output, and basic scene/resource operations. During tool evaluation, its current source successfully reported the engine version, created a scene, and added a node; Godot then ran that generated scene headlessly. Its inspected tool list did not include screenshot capture or input simulation.

It is not installed in this project.

### Godot MCP Pro

[Asset listing](https://godotengine.org/asset-library/asset/4961) · [Repository](https://github.com/youichi-uda/godot-mcp-pro)

Candidate for screenshots, input simulation, and live game inspection. The public repository provides the editor addon; the required server is distributed in a paid package. Advertised runtime capabilities have not been independently verified for this project. Use matched addon/server versions if adopted.

Before relying on it, verify actual game screenshots, UI input and state changes, runtime error retrieval, and how separate multiplayer instances are targeted. A bridge does not remove the need for a working graphical runtime.

Keep development automation local, enable available connection authentication, and never expose editor-control ports as part of the game's multiplayer service. Ensure development-only tooling is excluded from distributed builds.

## Pixel-art asset workflow

**PixelLab sprites are development-time assets.** The game ships a cleaned user-supplied chest pair and accepted tower PNGs. Arrow tower was generated through the PixelLab API using locally supplied credentials; there is no persistent API/MCP integration or runtime network dependency. `API.txt` is ignored and must never be committed or distributed. Retro Diffusion remains an untested comparison option. Use Aseprite or Pixelorama for further manual cleanup.

- [PixelLab](https://www.pixellab.ai/) documents MCP/API access, directional characters, animation, transparent objects, editor integrations, and Godot tileset guides. Its free trial lists API/MCP access but excludes map tools.
- [Retro Diffusion](https://retrodiffusion.ai/) also documents a hosted MCP server, API access, reference-based generation, animations, and tilesets. Automation is not exclusive to PixelLab.
- At the time of assessment, PixelLab listed paid tiers at $12/$24/$50 per month. Retro Diffusion listed images at $0.03/$0.06/$0.18 depending on model, with animations from $0.07 and free starting balance. Recheck current pricing and terms before spending. PixelLab generations are billing units, not necessarily finished images; directional sets and animations may consume several.

### Imported chest sprite trial

- `assets/chests/orc_chest_closed.png` uses the supplied PixelLab `chest_0016.png`: its 64×64 pixels are unchanged, padded onto a 96×96 transparent canvas at (16, 32).
- `assets/chests/orc_chest_open.png` uses the first supplied open-chest candidate's lid. Generation had changed the lower body, so cleanup aligns the lid at (+3, +7), redraws the narrow opening rim, and restores the closed sprite's entire lower region from row 55 onward.
- Both frames have hard transparency. The closed frame and open frame have pixel-identical lower bodies. `CHEST_BODY_Y` (55) and `CHEST_FOOT_Y` (92) in `ChestReveal` describe this specific sprite pair; changing the art requires updating that geometry together.
- The reveal draws the fixed body once and crossfades only the lid/interior between two poses. This is not a generated frame-by-frame animation. Existing shake, light, decorative coins, reward timing, and skip behavior remain separate; audio is not implemented.
- Textures are losslessly imported without mipmaps, rendered with nearest filtering, and drawn at integer scale. More than three reward cards use a smaller chest so the open lid does not overlap the cards.
- Verified the original closed pixels and retained lower-body pixels, then inspected closed, opening, open, compact, and five-card surfaces in the graphical game. The layout regression also rejects reward cards overlapping the chest. Supplied source originals remain untouched.

### Accepted base crossbow tower sprite

`assets/towers/ballista_tower.png` is the accepted 96×96 PixelLab output `pixellab-A-gigantic-orc-siege-ballista--1791921366109.png`, copied byte-for-byte without refinement. It supplies the existing `orc_ballista` reward's base art; the saved ID, title, reward rules, and unlock state are unchanged.

The icon uses an `AtlasTexture` region `Rect2(12, 5, 74, 89)` to exclude its transparent border. The source PNG remains unchanged. Update the region if the sprite changes so its visible bounds remain comparable with the other towers.

`TowerReward.icon_texture` holds imported icon art. The shared `RewardIcon` renderer fits all three towers without stretching in both the collection archive and chest rewards, with dimming for locked entries. The obsolete procedural tower drawings and their icon selector were removed.

The source/copy checksums match. Graphical verification inspected locked, unlocked reward, and compact collection states, and reloaded the same saved ballista ID. Layout regressions use the real catalog icons. This establishes collection/base artwork, not combat behavior, a board camera angle, or an upgraded tower.

### Accepted Rune obelisk sprite

`assets/towers/rune_obelisk.png` is the user-supplied 256×256 PixelLab file `pixellab-A-rune-obelisk--an-ancient-sto-1791966274141.png`, copied byte-for-byte from the original file, not from the pasted preview. Source and copy SHA-256 match: `c4c3a6b6a2caa470ecd81962c63289753bcdbdad40ced44ddb784a705ec177b8`.

The existing `rune_obelisk` reward's `icon_texture` uses an ordinary `AtlasTexture` over its visible alpha bounds: `Rect2(78, 41, 98, 160)`. This excludes only transparent padding without modifying or resampling the PNG. Update this region if the source art changes. The same renderer fits the atlas into the collection and chest cards alongside the ballista, preserving proportions, nearest filtering, lossless import, and locked-state dimming.

The reward ID, resource UID, title, unlock/save format, and chest grant rules are unchanged. Collection/persistence, reveal-layout, and chest-flow regressions pass. Graphical verification inspected locked/unlocked Rune icons, a natural Rune-only reveal, and an actual two-reward Rune/ballista reveal at standard and compact window sizes; the same saved Rune ID reloaded successfully. Verification used isolated saves and did not change real player progress. This is collection artwork, not implemented combat behavior.

### Accepted Arrow tower sprite

`assets/towers/arrow_tower.png` is the creator-selected second variation from one PixelLab reference-based Pro generation: a green-bannered timber lookout on a visible stone base, with a pink-haired archer holding a bow. The 128×128 RGBA PNG is saved byte-for-byte from the API response with hard transparency. SHA-256: `8d28e2a2abcf49778de0195d189a0e451b1b2d7af01ed343b9c7df41448ea8ed`.

Generation used [`POST /v2/generate-image-v2`](https://api.pixellab.ai/v2/docs), seed `1792000017`, `no_background=true`, 128×128 output, and the existing 96×96 ballista as `style_image`. Outline, detail, and shading copying were enabled; palette copying was disabled to allow pink hair. The job returned four variations and reported a charge of 10 subscription generations. Job ID: `1d26bf5c-d23b-45ff-ad8f-573d44516c8b`; generation ID: `9bfba4ea-7868-4eac-b5fa-4277b645fb1e`. Earlier Bitforge candidates were rejected and never imported.

The generation description was:

> A complete fantasy archer tower sprite with its entire base clearly visible. A square pale stone foundation supports a sturdy brown timber watchtower with an open battlement platform. A clearly visible pink-haired female archer stands on top, holding a curved wooden bow with a nocked arrow, aiming to the right. Show her pink hair, head, arms, bow and upper body above the railing. One complete tower plus its archer, centered, with transparent margin on all sides; do not crop the foundation, bow or hair. Three-quarter low top-down viewpoint matching the supplied ballista. Copy its crisp pixel clusters, selective dark outline, light gray stone and warm wood shading, but not its crossbow. Keep the pink hair a distinct color accent. Transparent background, no terrain, no text.

The existing `arrow_tower` reward retains its ID and resource UID. Its ordinary `AtlasTexture` uses `Rect2(28, 24, 70, 86)`, excluding only transparent padding; the source pixels are neither resized nor retouched. Lossless import, no mipmaps, nearest filtering, and the shared 52×52 visual frame match the other towers. The old procedural Arrow drawing and its unused pixel helper were removed.

Import, main-scene smoke, collection/persistence, reveal-layout, chest-flow, and rendered icon-size regressions pass. Graphical verification exercised actual Collection/Open controls, locked and unlocked catalog entries, an actual three-reward reveal, a remaining-only Arrow reveal, 1280×720 and 1000×720 rendered collection surfaces, and reloading the same saved Arrow ID. Verification used isolated saves and did not change real progress. The same accepted sprite now supplies the prototype Arrow's board artwork; combat rules belong to `MatchCombat` and `CombatRules`, not the collection resource.

### Consistent tower icon sizing

Every tower uses a shared maximum 52×52 logical-pixel visual frame in both the archive and chest rewards, shrinking only when its available area is smaller. All icons fit their visible atlas bounds without stretching. Icons stay centered, and an expanding row or reward card cannot enlarge their artwork. PNG canvas dimensions do not determine display size.

The graphical `tower_icon_test.gd` regression renders all catalog icons into transparent viewports and compares their actual visible pixel bounds. It checks equal size across identities, containment, centering, compact areas, and unchanged artwork size when a card expands. Run it without `--headless`; a dummy renderer cannot prove pixel output. The rendered regression and the standard/compact collection and reward smoke passed after correcting the oversized obelisk.

### Next board-art trial

Choose a shared camera angle, outline style, palette, and pixel scale before generating a small sample:

1. One tower and an evolved version, checking that identity survives the change in size and function.
2. One enemy with a directional walk cycle, checking frame alignment and consistent appearance.
3. A crystal that remains readable against the terrain.
4. Ground and connecting path tiles, checking bends and adjacent sections. Defer paid map tooling until the initial asset results justify it.

Judge these together at the intended game zoom, including a crowded arrangement. Inspect silhouettes, animation timing, transparency, palette consistency, and manual cleanup required. Avoid generating the full roster or buying several subscriptions before this trial.

The commander is off-board, so a playable hero sprite is not the first asset priority. Most tower buildings do not need eight directional views; consider a separate aiming-weapon sprite where appropriate.

Tile size, sprite canvas size, and occupied gameplay footprint are separate decisions. Some PixelLab character modes pad the canvas for animation, so requested character size does not guarantee identical frame dimensions. Inspect exported dimensions and pivots before import; use nearest-neighbor filtering.

Generate assets during development and ship ordinary image files. Players should need neither an AI account nor an API key. Keep credentials out of Git and obtain approval before connecting paid services or spending credits.

References: [PixelLab MCP documentation](https://api.pixellab.ai/mcp/docs), [PixelLab API pricing and estimate caveats](https://www.pixellab.ai/pixellab-api), and [Retro Diffusion capabilities and pricing](https://retrodiffusion.ai/).


## Path workshop verification

The resource import, main-scene headless run, and path-rule regression command above pass. Regressions cover budget rejection/refunds, immutable endpoints, out-of-bounds placement, shortcut selection, disconnected islands, edge-only adjacency, and deterministic equal-length routes.

The graphical scene was exercised through mouse input: placement, dragging, bridge removal, endpoint protection, isolated-tile removal, budget rejection, and the clear button. Rendered screenshots were inspected for clipping and route readability. The desktop run used Intel OpenGL after NVIDIA driver warnings.

Navigation regressions pass both headlessly and graphically: keyboard opening/resuming, returning while drawing, preserving the route and budget, rejecting edits on the hidden board, idle hovering, and releasing the mouse outside the board. Idle motion checks the held-button state only when a drawing button is active; passing `MOUSE_BUTTON_NONE` to Godot's button query is invalid. Menu transitions cancel the stroke so returning cannot continue a stale drag.

The main menu, session-resume menu, and compact workshop were visually inspected. The actual Quit button terminated the graphical process. Menu navigation preserves the existing layout but does not save it to disk.

For manual verification, connect E to B, create a longer branch and a shortcut, remove a connecting tile, add/remove an isolated tile, exhaust the budget, and clear the board. Check that readiness, budget, and route preview follow each edit. Resize the window and check that controls remain visible and mouse coordinates still match tiles.

Also open the workshop by keyboard, draw while holding the mouse and press Esc, release outside the board, and resume. Hovering must not draw or emit mouse-button errors. Return through the Menu button and resume again; budget and route must remain unchanged.

Desktop exports are not implemented or verified. Direct connection, shared planning, and the Arrow-defense loop are implemented and locally verified; separate-machine internet connectivity is not verified.

## Collection and chest verification

Collection unlocks are stored in `user://collection.json`, separate from unsaved workshop layouts. Gorcs retains the existing collection directory through Godot's custom user-directory settings so the name correction does not reset progress. On Linux this remains `~/.local/share/godot/app_userdata/Goorcs/collection.json`; Windows/macOS overrides retain their previous `Godot/app_userdata/Goorcs` directories. The legacy directory spelling is internal storage, not displayed branding. Godot's resolved user-data path is authoritative; preservation was verified on Linux. Use one game instance at a time for this save. There is no cloud sync or concurrent-writer coordination.

Opening chooses rewards in `CollectionStore`, writes a sibling temporary file, and renames it over the previous save before committing the in-memory grant. The reveal receives that saved result and cannot change it. Unknown versions/IDs, malformed data, unreadable files, or write failures block openings with a visible error. Long error details are selectable and scrollable. Repair or move aside a damaged save and restart; the game never silently resets it. Moving the file aside starts a new collection, so preserve a copy if its unlocks matter.

**Reset progress** in the collection screen opens a confirmation dialog. Confirming persists an empty unlocked set through the same atomic save operation before clearing memory and the previous reveal; Cancel changes nothing. The workshop layout is unaffected. Reset is disabled during a reveal, when there are no unlocks, or while the save has an error. A failed reset preserves both the existing save and in-memory unlocks.

The commands above pass. Regressions cover count-roll boundaries, duplicate-free draws, remaining-count caps, persistence, catalog exhaustion, failed writes preserving both saved and in-memory state, malformed saves, idempotent reveal completion, one/three/five-card bounds and overlap, saved-before-reveal grants, repeated clicks/skips, and leaving/resuming mid-reveal.

Graphical verification exercised real collection-screen input, natural opening/reveal completion, skipping, navigation, collection exhaustion, and a corrupt-save error. Separate game processes confirmed a saved unlock survives restarting. Inspected one- and three-reward results, a five-reward standalone reveal using an expanded test catalog, and compact collection/error surfaces. Five actual rewards remain impossible with the production three-type catalog.

Reset verification exercised the actual button and confirmation dialog, cancellation, saved empty progress, cleared reward cards/closed chest, preserved workshop tiles, and opening a fresh chest. Compact screenshots were inspected. Regressions cover reset persistence, write failure preservation, invalid-save protection, and the confirmation/cancel/reopen flow.

For manual checks, open a chest, return to the menu during its animation, resume, and restart the game. Verify the same unlocks remain, skipping does not add rewards, and completing the collection disables opening. Use an isolated save for repeatable trials; tests never modify the real collection save.

## Shareable game brief

`docs/goorcs-brief.pdf` is the short, friend-facing summary of the design. Its editable source is `docs/goorcs-brief.typ`; `docs/game-direction.md` remains the design source of truth.

Install Typst and the Anton and Noto Sans fonts to regenerate the PDF from the repository root:

```sh
typst compile docs/goorcs-brief.typ docs/goorcs-brief.pdf
```

Check the rendered pages for clipping, overlapping text, and any provisional choice presented as settled. Keep the brief to three readable pages and commit the source with its updated PDF.
