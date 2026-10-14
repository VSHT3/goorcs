# Development workflow

## Setup

1. Install the standard Godot **4.7.2 stable** executable from the [official downloads](https://godotengine.org/download/). Keep collaborators on the same version; upgrade deliberately.
2. Clone the private repository and import `project.godot` into Godot.
3. Run the main scene with F5. Choose **Open workshop** from the main menu.

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

## Direct connection lobby

**Play → Host / Join** uses built-in ENet; there is no game-hosted signaling, room-code lookup, or relay service, and no additional runtime package is required. One host admits one guest using native `SceneMultiplayer` authentication. `MultiplayerSession` exclusively owns the tree's default multiplayer API while active; future match networking must reuse that owner rather than install a competing peer.

Host with a numeric IP address your friend can reach:

- Same LAN: use the host's LAN address and allow the selected UDP port through its firewall.
- Private VPN/network: both players must already belong to that network; advertise the host's VPN address. Tailscale is an optional example, not installed or configured by this game.
- Public internet: advertise the public/routable address. Forward the chosen UDP port to the host computer if required and allow it through the firewall. Carrier-grade NAT may prevent forwarding; this game does not solve it.
- Two processes on this computer: use `127.0.0.1`. That address cannot connect a friend on another machine.

The host copies the full `GOORCS1/address/port/credential` invite; the guest pastes it into Join. The default hosting port is UDP 7000, and both sides use the port encoded in the invite. The credential is regenerated for each new hosting attempt. Never publish a live code: it exposes the address and permits room admission. ENet traffic and its authentication exchange are not encrypted; use trusted networks or an encrypted private VPN if confidentiality is needed.

Wrong credentials, incompatible invite/authentication versions, malformed endpoints, occupied ports, full rooms, and unreachable hosts fail visibly without admitting another player. Connecting has a bounded deadline and can be cancelled. The guest can leave and rejoin the same waiting host; leaving as host closes the room and invalidates its code. Returning to the menu or closing the lobby releases the connection and listening port. No host migration or automatic reconnect is implemented.

The regression command above launches three real Godot processes and covers admission, wrong/version/full rejection, an unfinished authentication deadline, cancellation, leave/rejoin, fresh credentials, host loss, node exit, and cross-process port reuse. Worker commands, results, and logs use isolated temporary files and do not touch the real collection save.

Graphical verification exercised Play/Host/Join, full-code clipboard copy, invalid-code correction with Enter, two-player admission, guest leave/rejoin, and host disconnection. Main/host and compact guest/error surfaces were inspected at 1280×720 and 1000×720. Navigation regressions also verify that Esc exits Play while a text field is editing, without affecting local workshop progress.

For a two-instance manual check, launch the project twice with the run command in Setup. Host in one using `127.0.0.1`, copy its invite into Join in the other, and check **Connected · 2 of 2 players** on both. Leave as guest, rejoin, then leave as host and inspect the guest's disconnect error. For internet verification, repeat on two separate machines and networks with the actual forwarding/private-network setup. Localhost success does not establish internet reachability; that check remains outstanding.

This implements the connection lobby only. Boards, combat, economy, and collection progress are not synchronized; there is no match to start yet.

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

**PixelLab chest trial completed with user-supplied outputs.** The game now ships a cleaned closed/open sprite pair; PixelLab API/MCP access is not connected and no credentials were added. Retro Diffusion remains an untested comparison option. Use Aseprite or Pixelorama for further manual cleanup.

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

`TowerReward.icon_texture` holds imported icon art. The shared `RewardIcon` renderer fits it without stretching in both the collection archive and chest rewards, with dimming for locked entries. Arrow tower retains its procedural icon; the obsolete procedural ballista and Rune obelisk drawings and their icon selector were removed.

The source/copy checksums match. Graphical verification inspected locked, unlocked reward, and compact collection states, and reloaded the same saved ballista ID. Layout regressions use the real catalog icons. This establishes collection/base artwork, not combat behavior, a board camera angle, or an upgraded tower.

### Accepted Rune obelisk sprite

`assets/towers/rune_obelisk.png` is the user-supplied 256×256 PixelLab file `pixellab-A-rune-obelisk--an-ancient-sto-1791966274141.png`, copied byte-for-byte from the original file, not from the pasted preview. Source and copy SHA-256 match: `c4c3a6b6a2caa470ecd81962c63289753bcdbdad40ced44ddb784a705ec177b8`.

The existing `rune_obelisk` reward's `icon_texture` uses an ordinary `AtlasTexture` over its visible alpha bounds: `Rect2(78, 41, 98, 160)`. This excludes only transparent padding without modifying or resampling the PNG. Update this region if the source art changes. The same renderer fits the atlas into the collection and chest cards alongside the ballista, preserving proportions, nearest filtering, lossless import, and locked-state dimming.

The reward ID, resource UID, title, unlock/save format, and chest grant rules are unchanged. Collection/persistence, reveal-layout, and chest-flow regressions pass. Graphical verification inspected locked/unlocked Rune icons, a natural Rune-only reveal, and an actual two-reward Rune/ballista reveal at standard and compact window sizes; the same saved Rune ID reloaded successfully. Verification used isolated saves and did not change real player progress. This is collection artwork, not implemented combat behavior.

### Consistent tower icon sizing

Every tower uses a shared maximum 52×52 logical-pixel visual frame in both the archive and chest rewards, shrinking only when its available area is smaller. Imported icons fit their visible atlas bounds without stretching; the procedural Arrow tower is fitted using its actual drawing bounds. Icons stay centered, and an expanding row or reward card cannot enlarge their artwork. PNG canvas dimensions do not determine display size.

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

Desktop exports and combat are not implemented or verified. The direct connection lobby is implemented and locally verified; separate-machine internet connectivity is not verified.

## Collection and chest verification

Collection unlocks are stored in `user://collection.json`, separate from unsaved workshop layouts. On Linux with the current application name, this is normally `~/.local/share/godot/app_userdata/Goorcs/collection.json`; Godot's resolved user-data path is authoritative. Use one game instance at a time for this save. There is no cloud sync or concurrent-writer coordination.

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
