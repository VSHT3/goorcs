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

# Run workshop feedback-layout and compact navigation regressions.
godot --headless --path . --script tests/workshop_ui_test.gd

# Run continuous match-world camera, input, and fixed-HUD regressions.
godot --headless --path . --script tests/match_world_test.gd

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

# Run offline mirrored-opponent regressions.
godot --headless --path . --script tests/singleplayer_test.gd

# Run actual GUI tower-drag/drop regressions in an isolated viewport.
godot --headless --path . --script tests/match_drag_test.gd

# Run deterministic combat-rule regressions.
godot --headless --path . --script tests/match_combat_test.gd

# Run real two-process combat/result regressions.
godot --headless --path . --script tests/match_multiplayer_test.gd

# Run solo clocks/autoplay and real peer pacing/weighted-roster regressions.
godot --headless --path . --script tests/match_pacing_test.gd

# Run real host/client shortest-branch routing regressions.
godot --headless --path . --script tests/match_branch_test.gd

# Run rendered tower-size regressions (requires a graphical renderer).
godot --path . --script tests/tower_icon_test.gd

# Run movement interpolation and rendered path-junction regressions.
godot --path . --script tests/path_board_test.gd

# Run rendered enemy-inspection and live-instance UI regressions.
godot --path . --script tests/enemy_inspection_test.gd

# Run collection-driven tower-selection and resource-extension regressions.
godot --headless --path . --script tests/tower_selection_test.gd
```

A headless pass verifies that the project loads and runs, not that the visuals or interactions are correct. Inspect runtime errors as well as the exit status.

## Repository editing rules

Read [AGENTS.md](../AGENTS.md) before editing. It owns implementation conventions, future state-ownership constraints, scope boundaries, and completion requirements. This document owns the engine release and executable commands; update them here rather than maintaining duplicate copies.

## Verification as the game grows

For a gameplay change, run the game and exercise the changed action. Use screenshots and input automation where available, plus human playtesting for feel and balance.

For networking changes, launch separate host and client processes and verify the resulting authoritative state. Before declaring internet support, play a match between separate machines and networks; localhost is not proof of NAT traversal or acceptable latency.

The first multiplayer milestone should be completed before building extensive progression and content systems.

### Interface hierarchy

Routine match HUD text shows one instance of each actionable fact: wave/result, Coins, base health, the owned planning budget or combat alive counts, and current actions. Only positive opponent readiness, recurring income, and next-wave queue counts are displayed; zero summaries and duplicate opponent planning budgets are absent. Route legality, regular-spawn progress, A/D scouting instructions, repeated per-price currency units, and affordability explanations live in tooltips. Placement is shown by the pressed palette card plus Cancel, not another title/price caption. Locked/unavailable purchases remain distinguishable. Clear/Ready are absent during combat; their row keeps its fixed height so HUD/world geometry does not jump. Gameplay/workshop rejection notices expire after 3.5 seconds; connection and save errors remain visible.

Match path strokes on the fixed entrance/base or outside the board are silent no-ops. They remain invalid, but no rejection banner is emitted, avoiding layout jumps during ordinary drawing. Graphical verification clicked both endpoints and checked that the feedback stayed hidden and the board rectangle stayed unchanged; singleplayer and separate-peer planning regressions passed.

Cleanup verification exercised menu/workshop/collection/lobby and two real gameplay peers in rendered 1280×720 and 1000×720 subviewports, including live targeting, ordinary/coin-flip results, rejoin, visible errors, and idle notice expiry. The unchanged reset warning was visually inspected; reset/cancellation behavior remains covered by the passing chest-flow regression. Linux save-directory preservation and corrected `GORCS1` peer admission also passed. PDF/brief files were intentionally unchanged.

### Pixel typography

The game bundles [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans) by Stefie Justprince at `assets/fonts/PixelifySans.ttf`, with its copyright notice and SIL Open Font License in `assets/fonts/OFL.txt`. The unchanged variable font comes from upstream commit `39df74aba80df8157546034b878e8be1eb565ced`; keep the license with any redistributed build. No font service or runtime download is used.

Numeric readouts use [Silkscreen](https://github.com/googlefonts/silkscreen) by Jason Kottke, bundled unchanged at `assets/fonts/silkscreen/Silkscreen-Regular.ttf` from commit `206ccf3f5234c281461e63ecc59cbc6b0563472b`, with its separate `OFL.txt`. The creator found Pixelify's digits hard to read, so health, Coins, prices, stats, counters, and numeric host fields use this crisper **pixel** face—not a smooth font. Keep both licenses with redistributed builds.

`project.godot` owns the shared Pixelify `gui/theme/custom_font` setting. Scene themes retain colors/styles and inherit this font; the custom menu wordmark draws with the bundled Pixelify asset. Numeric controls override only their font with the shared Silkscreen asset. Tower-shop captions and native drag previews separate Pixelify titles from Silkscreen prices; explanatory tooltips and generic feedback remain Pixelify. Invite-code input/output stays Pixelify so letter case remains distinguishable. Small UI text stays at least 16px, and the original 72px/100px camera-fit bands are retained. Management stats use two lines; compact upgrades show benefit and numeric price/Purchased, with insufficient-Coins explanations only in tooltips.

Reward titles wrap rather than ellipsize. Card minimum-size changes coalesce a deferred layout pass: wrapped labels first receive their real width, then nominal card bounds are reapplied. This prevents inflated initial heights from covering neighboring rewards or the chest, without changing grant rules or artwork sizes. Chest geometry regressions cover fresh one/three/five-card presentations, full wrapped titles, reuse, and resize transitions.

Rendered verification exercised menu/workshop, Host/Join and connection errors, Singleplayer paths/purchases/upgrades/targeting/Ready/Leave, collection/reset dialog, one/three/five reward reveals, and invalid-save text at 1280×720 and 1000×720. The numeric cutover separately checked Silkscreen health, Coins, stats, prices, tile/enemy/reward counts, IP and port fields, and unchanged Pixelify names/menus/credential text at both sizes. Compact screenshots were inspected; native caption-child clicking, paid purchases, management, and waves remained functional without HUD reflow. Header/bottom panels measured 69px/101px in both rendered widths. Navigation, chest flow/geometry, selection, camera, native drag/drop, startup, rendered board, and tower-icon checks passed. Verification used isolated collection saves and Intel OpenGL after NVIDIA initialization warnings.

### Continuous match world and verification

Matches use `MatchWorld`, a separate world `SubViewport` with a local `Camera2D`, behind the fixed planning HUD. The host board is on the left and the guest board on the right; both retain fixed authoritative grid dimensions and the existing equal tile budget. Each player starts focused on their owned board, with that side filling the gameplay view. Hold A/D for smooth horizontal traversal, clamped at the outer map extents. This is scouting, not map expansion; future milestone-based growth remains unimplemented. Workshop painting stays local and camera-free while reusing match terrain/path materials and endpoint artwork.

Wave/Coins, health/readiness, Leave, palette, and actions remain anchored to the screen. Tower management and transient notices overlay the world rather than reflowing it. HUD panels consume their own input; uncovered world space remains interactive. Camera movement is local presentation, never accepted match state, and ordinary snapshots do not reset it. Fresh activation focuses the owned side; hiding/leaving the match or losing focus cancels held movement and path strokes. A/D yields to text input and targeting popups, and panning cancels an active stroke so moving the world cannot paint tiles.

Owned cell input must follow the camera's translated/scaled canvas, including after window resize. Native tower drag/drop travels from the root HUD viewport into the world viewport and reuses the owned board's placement legality. Scouting the opponent grants no editing, placement, or management commands. Multiplayer host authority, mirrored Singleplayer behavior, collection gating, combat interpolation, and workshop state ownership are unchanged.

Camera keys are handled by a separate root-viewport input node because `SubViewportContainer` changes its own native input registration with GUI focus. Visibility notifications cancel motion but never undo activation reentrantly during parent visibility propagation. Native HUD drags stay in the root viewport, with the container acting as the drop target and translating into the owned board's canvas. Input verification must exercise actual engine drag initiation/release, not only call drop validators directly.

`match_world_test.gd` checks host/guest own-side initial focus, continuous intermediate positions in both pan directions, edge clamping, snapshot stability, unchanged accepted match state, coordinate roundtrips and actual owned clicks after pan/resize, denied opponent input, stable HUD rectangles when management/notices appear, hidden/focus-lost cancellation, and Leave/reopen resets. `match_drag_test.gd` drives real GUI press/motion/release in an isolated non-native viewport, checking paid purchases after pan/zoom and unchanged state for occupied, path, out-of-bounds, and opponent drops. These are behavior invariants, not assertions about wording or scene wiring.

For graphical verification, exercise Play/Singleplayer and separate ENet host/guest processes. Hold and release physical A/D keys, inspect the intermediate view and both outer stops, open targeting while panning, lose/recover window focus, and leave/reopen. Draw paths, click/place/select towers, and perform native HUD-to-world drag/drop after panning and resizing. Check that notices and management never move the world or Ready button, opponent input is denied, endpoints remain readable, and accepted paths/Coins/health are unaffected by camera movement.

Resource import, main-scene startup, and all headless regressions in Setup passed, including continuous-world input/camera coverage and real separate-process admission, planning, and combat. Rendered board and tower-icon regressions passed. Graphical Singleplayer and two separate ENet host/guest processes exercised owned mouse-built routes, click purchases, upgrades, actual native HUD-to-world drag/drop, held physical A/D with intermediate views and both endpoints, read-only opponent clicks, and live waves. Singleplayer also exercised Leave/Escape, fresh reopen, and a compact 1000×720 logical viewport. Initial, intermediate, opponent, management, wave, compact, and both-peer screenshots were inspected. Isolated collection saves preserved real progress. The graphical runtime used Intel OpenGL after NVIDIA initialization warnings; internet reachability remains unverified.

### Enemy inspection

`MatchPlanningScreen` owns one local `(board slot, enemy ID)` selection. `PathBoard` hit-tests the interpolated sprite's opaque bounds in draw order, excluding transparent canvas padding, and draws corner highlights around only that instance. Either board permits inspection, but opponent commands remain read-only and active tower placement takes input priority. The fixed right-side `EnemyInspector` overlay never changes the world viewport or camera framing.

The panel displays the host catalog's title/short description and that enemy instance's current HP, maximum-backed health bar, movement speed (cells per simulation second), and base damage. Icons carry tooltip meanings without permanent stat labels or future-property placeholders. Speed comes from the same instance field used by movement, not next-wave/type previews; global 2× playback changes simulation time rather than that stat. Resource-owned damage is captured in the instance and consumed by the leak rule: Grunt/Runner 1, Brute 3. No slow/status-effect mechanic is added.

Another enemy replaces selection. Empty-ground clicks, close, right-click, or Escape dismiss it. A missing instance, results, leaving, or hiding the match clears it rather than following another same-type enemy. Inspection never sends a gameplay command or changes tower targeting.

Graphical smoke used actual main-scene enemy clicks and inspected 1280×720 and 1000×720 captures. Resource import, combat rules, mirrored Singleplayer, real separate-process peer combat, rendered board, camera/input, tower selection, and navigation regressions passed.

The rendered enemy-inspection regression also passed: same-type ID isolation, accepted per-instance HP/speed/damage changes, interpolation-following hit tests and highlight pixels, both board orientations, opponent read-only input, stable overlay anchoring, placement priority, Close/Escape, real kills/leaks, results, and leave/reopen with reused IDs. Native tower drag/drop and main-scene startup checks passed.

### Match soundtrack and presentation

`assets/audio/orcish_drone.mp3` is the unchanged user-supplied `Orcish_Drone_FULL_SONG_musicgpt.mp3` (SHA-256 `fd8ce059f07bc3de311caa7cb8805b7076c5bc286dd888ea97d544cf107ca2df`, approximately 178.57 seconds, stereo 48kHz MP3). The main scene's local `MatchMusic` player loops at −12 dB during active match planning, combat, and wave breaks. Menus, connection setup, workshop, collection, results, and leaving are silent. Match snapshots do not restart playback. This is presentation only; no host audio clock or network messages were added.

`TowerReward` and `EnemyDefinition` own `board_height` (opaque height in cells) and normalized `board_anchor` (base/feet within the displayed texture). Collection/chest icon sizing is unchanged. Shipped tower heights are Arrow 1.42, Ballista 1.40, Rune 1.50; enemies are Grunt 0.84, Runner 0.74, Brute 1.02. The common foot point is the cell center plus 0.28 cells downward. Cached opaque bounds prevent transparent padding from determining size. Foot-y sorting includes towers, enemies, and endpoints; health bars render above bodies only when damaged.

Match grass/soil and connected stone materials are cosmetic, not blocked cells or path rules. The playable field contrasts with a darker, quieter exterior; broad stepped sod variation replaces scattered rectangle noise. An external earth apron/rim marks the existing bounds, and a continuous jagged ravine separates the match boards without adding traversable cells. Orderly world-aligned masonry uses quiet stone variation, mortar, and soil/contact edges. Cached ground drawing remains continuous through bends, branches, endpoints, and mirroring. Workshop rendering now reuses the terrain/stone/rim drawing paths; `command_mode` controls edit authority rather than artwork. Selected towers get a base marker and quiet tile range; explicit click/native-drag placement shows legal/illegal cells. Idle combat has no hover square or permanent tower rectangles. Arrow/Ballista retain brief directional traces; Rune uses a 0.14-second faint neighborhood shimmer with local hit sparks instead of expanding gold rings.

Camera fitting retains the fixed HUD bands and horizontal scouting bounds but reserves resource-derived top headroom. Graphical smoke initially reproduced tall top-row towers hidden by the HUD; the corrected fit and a camera regression now check every tower resource on both owned orientations at 1280×720 and 1000×720. This changes framing, not board dimensions, footprints, range, path budget, or authoritative state.

Rendered main-scene verification used actual GUI Play/Singleplayer, mouse-built bent routes, paid adjacent Rune purchases, selection, placement hover, Ready, normal wave simulation, typed paid sends, damaged/full-health streams, panning, denied opponent clicks, Leave, and fresh matches in exact-sized 1280×720/1000×720 subviewports. Top-row Rune/Arrow captures were inspected at both widths. Real gameplay captures are retained in [the visual TODO](../TODO.md); static lineup/candidate composites are labelled separately. Existing source-facing metadata and mirrored facing remain intact. The MP3 was sought to 0.25 seconds before its end: playback crossed to the beginning while remaining active, and an `AudioEffectCapture` observed non-silent decoded mixer samples. Navigation also covers uninterrupted music across snapshots/waves/breaks and stopping at results/Leave.

Import/startup, path rules, navigation, camera/HUD/top-row bounds, actual native drag/drop, tower selection, collection grant/chest-flow/chest-layout, combat rules, Singleplayer, separate-process peer planning/combat, and rendered board/tower-icon regressions passed. Headless fixtures allow the audio mix thread to retire stopped playbacks before quitting. Rendered runs used Intel OpenGL after NVIDIA initialization warnings; private collection progress was isolated. These checks do not prove internet networking or a walk cycle. All original runtime PNGs remain unchanged; refined sprite candidates require explicit approval before integration.

The supplied `swappy-20261014_211722.png` showed that the first material pass blended the board into surrounding terrain and repeated readiness/route/zero-income text. The correction above was inspected in real 1280×720 and 1000×720 main-scene captures: empty boards, bent paths, both mirrored orientations, adjacent towers, legal/illegal placement, management, mixed full/damaged streams, nonzero queues/income, injected held-D scouting, and top-row artwork. Actual GUI upgrade, sale, and repurchase verified payment/refund and the smaller controls. Original runtime sprites remain installed. Current captures in [TODO](../TODO.md) replace the earlier rejected material/HUD pass.

Import/startup, rendered board, tower selection/HUD visibility, camera, native drag/drop, navigation, Singleplayer, combat rules, and separate-process peer planning/combat checks passed for the correction. Added rendered regressions cover four-edge board/exterior separation, stone/field contrast, uninterrupted ravine, and the empty cell inside a bent/branched route. A real combat-model consumer regression covers incoming-only queue visibility, queue delivery removing obsolete summaries, recurring-income visibility, and terminal hiding. No tests pin exact palette colors or UI wording.



## Local singleplayer testing

**Play → Singleplayer** starts the normal continuous-world match locally, with no ENet peer, listening port, or invite. The initial view focuses the player's side, and local hold-A/D scouting uses the same fixed HUD and world viewport as multiplayer. `MatchPlanning` owns the mode and authoritative simulation; `MultiplayerSession` remains idle. Accepted player commands are replayed for the second board through the same validators. Tower management resolves the counterpart by cell because tower IDs are distinct. The UI still permits editing only the player's board.

The opponent mirrors path edits/clear, purchases, targeting, upgrades, sales, enemy sends, and Ready. One Ready therefore starts both sides; planning breaks, collection gating, prices, rewards, and terminal coin-flip results are unchanged. Mirrored sends independently spend each board's Coins and attack the other board through the same validators.

The singleplayer regression covers silent endpoint/out-of-bounds no-ops, ownership, mirrored transactions and distinct tower IDs, rejected purchases/upgrades, live construction, locked wave routes, both-board leaks, planning breaks, terminal results, and fresh restart. Graphical verification exercised actual Play/Singleplayer, mouse-drawn paths, purchases/upgrades, Ready and live physics, Leave/Escape, fresh restart, and reopening the Host form. Menu, planning, and wave screenshots were inspected. Existing navigation and separate-process planning/combat regressions also passed. The graphical run used Intel OpenGL after NVIDIA initialization warnings; an isolated collection save preserved real progress.

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

For a two-instance manual check, launch the project twice with the run command in Setup. Host in one using `127.0.0.1`, copy its invite into Join in the other, and check that each opens planning focused on its own side of the same continuous world. Hold A/D to inspect the other side without gaining editing access. Leave as guest, rejoin, then leave as host and inspect the guest's disconnect error. For internet verification, repeat on two separate machines and networks with the actual forwarding/private-network setup. Localhost success does not establish internet reachability; that check remains outstanding.

Admission opens shared planning behind a fixed HUD, initially viewing the owned board. Hold A/D to traverse the separate world viewport locally. The visible resource-driven palette shows all tower identities, prices, and disabled collection locks. Click a type then legal ground, or drag it onto the owned board, including after camera movement. Right-click/Escape cancels placement. With no placement selected, breaks allow path strokes; clicking a tower opens its management overlay without resizing the world. The panel shows kills, effective stats, targeting, two one-time upgrades, and the host-computed sale refund. Close/Escape dismisses selection without selling or disconnecting.

Manual both-ready and unanimous autoplay require legal routes and use the same capture/start gate. Accepted planning edits, purchases, targeting, upgrades, and sales clear manual readiness. During waves paths stay locked and tower management stays available. Towers, upgrades, kills, Coins, paths, and health persist between waves. Finished runs reject mutations and clear pacing consent; leaving/rejoining starts fresh. Same-tick base destruction uses one host-owned coin flip.

`MatchPlanning` reuses `MultiplayerSession`'s authenticated API; it never installs a second peer. It owns authoritative `PathLayout` instances and a host-only `MatchCombat`, and validates host-player and remote commands through the same rules. Remote sender identity determines board/tower ownership. Clients receive reliable accepted snapshots; UI layouts and combat dictionaries are detached mirrors. A post-admission snapshot request avoids exposing guest commands before synchronization. Static commands/phase transitions publish full snapshots; in-wave combat snapshots publish every 0.1 seconds without rebuilding path mirrors. Planning paths and match towers are separate from workshop drafts and collection saves.

The planning regression launches separate host/guest Godot processes with deliberately different local configurations. It verifies distinct legal mazes and shortest routes agree, ownership/bounds/endpoints/budget rejections preserve state, illegal paths cannot ready, edits invalidate readiness, unready works before a wave, captured routes reject combat-time edits/clear/unready, and disconnect/rejoin yields fresh boards. Workers use isolated temporary files and never touch collection saves.

Initial planning-only graphical verification exercised Play/Host/Join, distinct mouse-built paths, read-only opponent input, Ready, readiness invalidation, removal, route locking, Esc, waiting, and Leave. The defense-loop verification below supersedes its old terminal locked-route screen.

### Combat simulation and verification

`CombatRules` owns enemy/wave and economy settings; `TowerDefinition` resources own each type's price, damage, range, interval, and two one-time upgrade costs/gains. The host snapshots these values and owns player Coins, tower investment, upgrades, kills, purchases, sales, attacks, and rewards. Invalid ownership, cells, funds, or repeat upgrades change nothing. A speed upgrade proportionally shortens the remaining reload; it does not grant an immediate extra shot. Sale returns floor(60% of purchase plus paid upgrades), removes the tower, and cannot be repeated.

For wave n≥1, baseline enemy HP is 8+2(n−1), speed is 2+0.15(n−1) cells per simulation second, and regular weight budget is 6+2(n−1) per board. HP/speed use each type's multipliers; the actual head count comes from the generated weighted roster, not an additional count curve. Starting Coins are 200/player; kills pay 3 Coins and both-board clearance pays 30+5n plus recurring income once to each surviving player. Terminal defeat pays no clear reward. These resource values are provisional. Tile-rounded enemy positions define Chebyshev range via `MatchCombat.cell_in_range`; Rune hits its center/eight-neighbor footprint, while Arrow/Ballista are single-target. Death/bounty resolve once before leaks.

`PathBoard` blends each surviving enemy's displayed progress toward its latest accepted snapshot over 0.1 seconds, evaluated on that enemy's own accepted `route` array. Interpolation, facing, hit testing, depth ordering, and selected-enemy highlights therefore stay on the assigned branch through corners rather than following a shared board route or cutting diagonally. Presentation is slightly delayed on both peers; positions, targeting, damage, and leaks remain host-owned. New IDs appear at their accepted position, absent IDs disappear immediately, and missing snapshots hold rather than extrapolate. Enemy animation stays active without towers/shots. Pavement connects shared edges, including branches/endpoints and mirroring, without a route-line overlay.

Combat-rule regressions verify policy-specific damage distributions, current-HP targeting, range boundaries/ties, immutable captured routes, killed enemies never leaking, pending-spawn gaps and both-board clearance, persistent health/towers, next-wave health growth, ordinary wins without randomness, and one frozen simultaneous-defeat roll. Real separate-process combat regressions verify owned live tower commands and all modes, rejected path/bounds/overlap/mode/ownership commands, readiness invalidation, combat path locks, both-ready wave transitions, host configuration replication, persistent damage, ordinary results, simultaneous coin-flip agreement, terminal command rejection, and fresh rejoin.

#### Equal-length branch routing

On manual or autoplay wave start, `PathLayout.capture_routing()` runs reverse breadth-first distances from the base and captures every neighboring successor whose remaining distance is exactly one smaller. This acyclic shortest-successor graph supports forks/rejoins without enumerating all complete paths. The workshop and planning's canonical `locked_routes` remain stable representative paths, not the routes used to move every enemy.

`MatchCombat.start_wave` accepts captured routing dictionaries rather than the former pair of simple route arrays. The host validates/copies both captures before changing wave state. Each spawn walks the graph once to assign `enemy["route"]`, rotating a per-board cursor only at multi-option forks. Two choices alternate; more choices cycle in stable right/down/left/up order. Queued sends, immediate sends, and regular enemies share their destination board's cursors. Cursors reset on each wave. Assignments happen at spawn, not arrival: an enemy killed before the fork still consumed its assignment, and surviving enemies are never rerouted to rebalance it.

Every assigned path on one board has the same shortest length, so scalar progress retains its targeting meaning. Host movement and leaks use the instance route; detached snapshots transmit it directly to clients. Longer connected detours are excluded, layout edits cannot mutate captured routes, and clients cannot choose or recompute authoritative branches. No new controls, status prose, or balance/stat changes were added.

Verification passed path capture/isolation, two-/three-way alternation, nested forks/rejoins, longer-route exclusion, regular/queued/immediate send rotation, per-board independence, wave resets, actual movement/targeting/leaks, and real separate host/client route/position agreement. Rendered board regressions cover both branches, corner-following interpolation, source-facing, hit selection, and isolated highlight pixels in both orientations. A graphical main-scene ring around a Rune tower assigned six enemies lower/upper/lower/upper/lower/upper; live combat and individual inspection were exercised and 1280×720/1000×720 captures inspected. Existing solo, weighted combat, peer combat/planning/pacing, camera, drag/drop, selection, navigation, import, and startup checks passed. Isolated saves were used; the throwaway harness was removed.


Graphical separate host/guest processes exercised actual Path/Tower controls, mouse-built paths, live Arrow placement/selection, native popup selection of all target modes, enemies and health bars, range outlines and shot traces, both-ready starts and breaks, ordinary win/loss, host-owned coin-flip results agreed by both peers, rejoin, Esc, and Leave. Visible Godot subviewports rendered at 1280×720 and 1000×720 because the compositor controls desktop window dimensions. Standard/compact gameplay, planning breaks, and results were inspected without clipping. The runtime used Intel OpenGL after NVIDIA driver warnings; isolated saves preserved real collection progress.

Center-entry and contextual-input verification exercised two rendered Godot peers: mirrored click coordinates, independent center-facing routes, menu-selected Arrow placement, right-click cancellation, no-selection inspection during breaks and combat, combat path locks, live construction, and automatic path editing in the next break. Wave and break screenshots were inspected. Navigation, separate-peer planning, separate-peer combat, resource import, and main-scene smoke passed.

Smooth-motion verification used two rendered host/guest processes with mouse-coordinate-built bent paths and branches. Both peers moved enemies on hundreds of frames without receiving a new position snapshot; the largest observed per-frame movement was 0.0142 cells in that run. Host/guest screenshots were inspected for continuous path junctions. The graphical board regression checks corner-following interpolation, snapshot immutability, missing-snapshot bounds, new/removed enemy IDs, animation without towers, and rendered horizontal/vertical/branch/endpoint joins in both orientations. Import, main-scene smoke, path rules, navigation, combat rules, and real-peer combat regressions passed.

Collection unlock gating remains local trusted-friends progression, while the host validates supported types, ownership, prices, and transactions. Locked types remain visible but disabled. Selection/resource-extension tests cover unlock/reset, affordability, effective upgraded stats, stale selection after sale, and a custom fourth resource; real-peer tests cover purchases, upgrades, sales, rewards, kills, terminal rejection, and fresh rejoin. Board tests render mirrored tile ranges and expanding Rune pulses and check drop legality.

Tower-management verification passed combat rules, separate-peer planning/combat, selection, rendered board, navigation, chest-flow, and startup checks. Two graphical ENet peers exercised actual click purchases, native desktop-cursor drag/drop, targeting popup key input, both upgrades, selling/refunds, cancellation, both-ready waves, Rune kills and circular pulses, income, and leaving. Standard and compact management/range surfaces were inspected on Apple M2 OpenGL. Isolated saves preserved real collection progress; the throwaway input harness was removed.

### Enemy sends and income

`MatchCombat.send_enemy(slot, type_id)` owns the transaction: validate phase, payer, configured type, and funds before charging that type's price, growing recurring income, and either spawning on the opposing captured route or reserving typed next-wave delivery. `MatchPlanning.send_enemy(slot, type_id)` carries the explicit ID through the existing authenticated reliable command path; sender identity decides the allowed payer, and the host derives the target. Host-player and guest actions use the same validator. Unknown IDs and rejected transactions change nothing. Planning sends clear readiness. No client calculation grants currency, enemies, or authoritative speed.

`CombatRules.enemy_definitions` registers `EnemyDefinition` resources from `resources/combat/enemies/`, owning identity, description, damage, health/speed multipliers, regular-wave composition constraints, send price/income, and local artwork. `prototype.tres` owns baseline HP/speed, wave weight/growth, spawn interval, and the 3-simulation-second send cutoff. Recurring income starts at zero, grows on accepted sends (including queued ones), and pays on both-board clearance, not immediately or on defeat. Planning/late orders preserve type IDs and drain once at the next manual or autoplay wave start. Sends are additional enemies outside the regular budget/caps; queued orders do not block current-wave clearance. Reset clears income and queues.

The fixed HUD has a local enemy selector and one **Send now / Send next** button in the header, with host cost/income gain and effective health/speed in tooltips. Selection persists across snapshots and cannot mutate match state. The footer shows only nonzero recurring income and incoming/outgoing next-wave counts (`Income +N`, `In N`, `Out N`); tooltips disclose per-clear payout and queued type composition. Poor, unavailable, and finished states disable sending; late delivery still permits purchasing a queued order. Camera keys yield to both targeting and enemy-selector popups. Alive includes every enemy; regular spawn progress excludes sends and is available in its tooltip.

Combat regressions cover exact-funds sends, insufficient-funds/invalid/terminal atomic rejection, detached snapshots, legal-route delivery, cutoff boundary, next-wave scaling, sent-enemy attacks/bounties/leaks, both-board clearance, and repeat income without repeat purchases. Separate-process ENet combat/send regressions, mirrored Singleplayer, peer planning, camera/HUD, native drag/drop, navigation, tower selection, resource import, and main-scene startup passed. A rendered throwaway main-scene smoke used actual GUI press/release on Send and Ready, real physics for immediate and deferred delivery, income payout, terminal/insufficient-funds disablement, and 1280×720/1000×720 screenshot inspection. The later HUD correction removes duplicate placement title/price and inline affordability prose while preserving selected palette state and full tooltip explanations. The smoke passed on Intel OpenGL after NVIDIA initialization warnings. Collection data used an isolated temporary save; the throwaway harness was removed.

### Enemy roster

Provisional type values, applied to the delivery wave's baseline:

| Type | Health multiplier | Speed multiplier | Send Coins | Added Coins/clear |
| --- | ---: | ---: | ---: | ---: |
| Grunt | 1.0 | 1.0 | 20 | 2 |
| Runner | 0.6 | 1.7 | 25 | 2 |
| Brute | 2.5 | 0.65 | 40 | 4 |

Maximum health is `max(1, ceil(baseline HP × multiplier))`; movement speed is `baseline speed × multiplier`. First-wave sends therefore still produce 5-HP Runners at 3.4 cells/s and 20-HP Brutes at 1.3 cells/s, although regular waves unlock them later. Grunt/Runner leaks deal 1 base damage; Brutes deal 3. Normal kill bounties remain shared across types; no armor, resistances, or status effects are introduced.

`MatchCombat` captures the configured type definitions on admission, just like tower stats. Each enemy snapshot carries its stable type ID and actual speed, so mixed streams never inherit a shared global movement speed. `enemy_types` publishes detached prices/income/multipliers plus current-wave effective HP/speed, or next-wave values during planning. `send_queues` preserves ordered IDs by target; `queued_sends` is a derived count, not another mutable queue owner. Type selection, artwork, facing, and interpolation stay cosmetic/local.

#### Weighted regular waves

| Type | Spawn weight | First regular wave | Count cap at wave n | Maximum budget share | Base damage |
| --- | ---: | ---: | ---: | ---: | ---: |
| Grunt | 1 | 1 | Unlimited | 100% | 1 |
| Runner | 2 | 3 | 4 + floor((n−3)/3) | 30% | 1 |
| Brute | 5 | 6 | 2 + floor((n−6)/4) | 35% | 3 |

At each accepted wave start, `MatchCombat` rolls one ordered roster using a host-only wave RNG, independent of terminal tie-breaking. Each draw must fit remaining weight, `first_wave`, the wave-specific count cap, and `floor(budget × max_weight_share)` for that type's total weight. A finite count cap is `max_per_wave + floor(max(0, n−first_wave) / count_cap_growth_interval) × count_cap_growth`; `max_per_wave = 0` stays unlimited, and zero growth keeps a fixed finite cap. Growth must be nonnegative and its interval positive. Caps are maxima, not guaranteed spawn counts; the weight-share ceiling still takes precedence if tighter. The always-unlocked, unlimited weight-one Grunt guarantees exact remainder fill. Invalid rules reject a wave start with errors instead of hanging or silently substituting a type. Both boards replay the same scheduled order with independent enemy IDs; actual per-type speed determines fractional-tick travel. `wave_roster`, `wave_weight`, and actual `total` are detached snapshot fields. Clearance waits for all actual roster entries and both boards, including sends.

The budget replaces `enemies_per_wave`/`count_growth`; current configuration uses `CombatRules.wave_weight` and `wave_weight_growth`, without compatibility aliases. Larger weights account for Runner leak pressure and Brute durability/three-point leaks. Unlocks introduce threats gradually; count/share caps retain mixed defenses and prevent heavy-only waves. This is a conservative playtest configuration, not a claim of measured balance. Tune weights and scaling together after real 1v1 play.

Count-growth verification passed deterministic unlock/interval-boundary, custom increment, unlimited-cap, late shipped roster, exact-budget, and weight-share-precedence regressions, plus real peer pacing/combat. A graphical isolated main-scene smoke completed 50 waves and observed later Runner/Brute counts exceeding their former fixed caps; the temporary harness was removed. Existing HP/speed curves, spawn cadence, and send rules are unchanged.


`assets/enemies/runner.png` and `brute.png` are original 48×48 transparent pixel art authored locally with Pillow, hard alpha, and embedded provenance metadata. Runner has a lean bandana/limb silhouette; Brute has broad armor and a larger silhouette. No external assets, generation service, model, credentials, or costs were used for these two installed images. `PathBoard` resolves local definition artwork rather than trusting remote resource paths. Facing follows horizontal route legs through corners and mirrors correctly with the board; damaged-only health bars stay unflipped above the bodies. All shipped enemies have real textures, resource-driven opaque height/foot anchors, and contact shadows. These are still sprites, not walk-cycle animation.

The installed Grunt image is a byte-identical copy of `~/Pictures/Gorcs-PixelArt/basic-orc-klein/selected/basic_orc.png` at `assets/enemies/grunt.png`, SHA-256 `7005092f2216a6d57556010196978f57213f5a8e98a359cad9055959bb0927ca`. This is also the selected west-facing export. The 64×64 PNG has 0/255 alpha, padded bounds `(10, 6)–(55, 58)`, and 23 opaque colors used from the shared 24-color export palette. Its local source directory retains prompts, references, raw outputs, three seeds (`202610142001`–`202610142003`), and `provenance.json`; the model was FLUX.2 Klein 9B FP8 distilled, using the existing Brute as its reference. Those generation artifacts and model weights are not runtime dependencies or copied into the build. The south-facing alternative is not installed.

`EnemyDefinition.source_faces_left` records the source artwork's orientation, with Grunt true and the existing right-authored Runner/Brute false. Rendering flips only when the required route-facing direction differs from that source orientation. This preserves the selected PNG unchanged instead of baking a mirrored derivative. The graphical regression exercises an asymmetric marker on both board orientations so backwards-facing left-authored art cannot pass by being merely mirrored consistently.

Installation verification passed resource import, graphical board regressions, combat rules, mirrored Singleplayer, and main-scene startup. A rendered main-scene smoke loaded the installed Grunt resource directly, with no temporary texture override, and exercised ordinary waves alongside Runner/Brute and towers. Both board orientations and 1280×720/1000×720 captures were inspected for actual orc silhouettes, correct facing, relative size, and clear health bars. Source/runtime checksums match. The smoke used an isolated collection save and Intel OpenGL after NVIDIA initialization warnings; its temporary harness was removed.

To add an enemy, create an `EnemyDefinition` resource with stable ID, real description/artwork, positive `base_damage`/`spawn_weight`, HP/speed multipliers, send price/income, and explicit `first_wave`, starting `max_per_wave`, `count_cap_growth`, `count_cap_growth_interval`, and `max_weight_share`. Choose weight against threat from durability, speed, leak damage, and counters—not sprite size. Choose an introduction wave, then cap early count and budget share and set how the count cap grows after unlock; a 20% cap is `max_weight_share = 0.2` and can exclude the type until its weight fits the floored allowance. Keep the baseline Grunt invariant. Register the resource in `CombatRules.DEFAULT_ENEMIES`; no new generation branch, selector branch, or RPC is needed. Custom matches may override definitions but both peers need the same art/IDs. Run combat and pacing/peer regressions, verify the new type's unlock/count-growth/share/exact-fill boundaries, and playtest its pressure before calling it balanced. New mechanics require real simulation and behavior coverage.

Typed-roster verification passed deterministic combat, mirrored Singleplayer, separate-process ENet combat/planning, camera/HUD/popup priority, native tower drag/drop, tower selection, navigation, import, and main-scene startup. The graphical board regression checks mixed silhouettes, correct centered mirroring, clear half-health bars, and facing through route corners. A separate rendered main-scene smoke exercised actual selector click plus keyboard navigation, Runner/Brute purchases, mixed queue order, immediate and next-wave delivery, real independent movement/leaks and recurring payouts, selection persistence, both camera orientations, compact placement, terminal disablement, and exact-funds Brute sending. Standard 1280×720 and compact 1000×720 captures were inspected. It ran on Intel OpenGL after NVIDIA initialization warnings, with an isolated collection save and throwaway harness.

### Shared pacing

The fixed HUD's pixel > / >> button requests normal/double simulation speed; the loop-arrow button requests autoplay. Pressed state represents local consent, gold denotes a pending request, and green denotes actual activation. State explanations stay in tooltips. `MatchPlanning.request_pacing` submits only the local slot; the host validates authenticated ownership and stores separate private speed/autoplay votes. Either option activates only when both votes are true. Withdrawing one vote stops it for both without erasing the other's vote. Solo mirrors its own consent immediately. Votes survive waves but reset on results, disconnect, and new matches.

Only host combat delta is multiplied by agreed speed. Movement, spawns, reloads, and send cutoff advance together; network snapshots remain on the real-time 0.1s cadence, and camera/UI/music time remains local/unscaled. Autoplay starts on activation with both legal paths, resumes after legalizing edits, and starts the next wave only after both boards clear and receive their normal reward. Invalid paths pause it without a timer/busy loop. Withdrawal leaves the current wave running and restores manual planning afterward. Manual readiness and autoplay capture routes through `_try_start_wave`; terminal results cannot restart.

Verification passed weighted/combat regressions (exact budgets, caps/unlocks, deterministic seed repeatability/diversity, identical actual streams, type scaling, extra sends, Brute damage/clamping, and a constrained fourth resource), solo clocks/autoplay, and separate authenticated host/client pacing with unilateral requests, unanimity, withdrawal, forged ownership, shared random rosters, clearance, results, disconnect, and rejoin. Existing solo/peer combat, peer planning, camera/input, native drag/drop, selection, navigation, rendered inspection/board, import, and main-scene smoke passed. Graphical main-scene clicks exercised > / >> and autoplay through six weighted waves; 1280×720 and 1000×720 captures were inspected for compact controls and mixed live enemies. Internet reachability remains unverified.

### Adding a tower

1. Create `resources/collection/<id>.tres` using `TowerReward`, with a unique stable `id`, title, description, artwork, and accent. Follow an existing atlas/icon resource. Never rename IDs already stored in saves.
2. Register that reward in `CollectionStore.DEFAULT_CATALOG` in `scripts/collection_store.gd`. The collection, chests, saved-unlock validation, and match artwork use this catalog.
3. Create `resources/combat/towers/<id>.tres` using `TowerDefinition`, referencing the reward and supplying price, positive damage/range/interval, damage/speed upgrade costs and gains, and the area-attack flag where applicable.
4. Register the definition in `CombatRules.tower_definitions` in `scripts/combat_rules.gd`. The shipped `prototype.tres` inherits that roster; if a custom combat resource explicitly overrides the array, add the definition to that resource too.
5. Run import, selection, combat, real-peer combat, and rendered checks from Setup. Open a chest in an isolated collection save, select the new tower, build it, inspect its stats/art/range, and observe its attack in separate peers. Commit the resource/script UID sidecars generated by Godot.

No menu, build RPC, rendering switch, or targeting branch is needed for another current-style direct-hit tower. Build commands carry stable type IDs; the host captures its configured definitions into a type lookup and publishes detached `tower_types` stats. Definitions with missing rewards/IDs, invalid stats, or duplicate IDs emit explicit errors. New mechanics such as splash or slowing require real gameplay-rule implementation and behavior regressions, not just a description in the reward.

Collection gating is local saved progression for trusted friends, not remote account verification. The host validates supported type IDs, board ownership, cell legality, and combat stats; it does not verify another computer's filesystem unlock claims. Both peers need the same artwork/catalog release. Adding catalog entries preserves existing known saved unlocks.


For a manual check, connect two instances and draw different legal paths. With autoplay off, ready one player and verify nothing starts; ready both and inspect enemies, hits, and leaks. Enable each pacing option on just one peer and verify no shared effect; enable the other to activate it, then withdraw either to stop it for both. Autoplay must wait for both boards to clear and never restart results. Inspect identical regular type order and Brute three-point leaks. Confirm combat rejects path edits but permits tower commands, and leaving/rejoining clears consent/state. Internet verification still requires separate machines and networks.

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

For the verified local ComfyUI/Klein setup, agent/API generation steps, iterative reference editing, and sprite exports, see the [AI-to-sprite pipeline](sprite-pipeline.md). Local Rune level-two candidates are not accepted runtime replacements; the current game art remains the accepted PNGs described below.

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

### Locally authored match endpoint sprites

`assets/world/health_crystal.png` and `assets/world/enemy_portal.png` are locally authored transparent 96×96 RGBA pixel-art PNGs, drawn with hand-authored integer-coordinate polygons and lines using Pillow. The base is a blue faceted magical crystal on a squat stone pedestal; the entrance is a red opening in an angular rough stone ring. Their three-quarter/top-down presentation follows the existing tower-art references, with hard alpha and nearest filtering. No external generation service, credentials, network access, external downloads, or paid credits were used for these endpoint assets.

In matches and the workshop, `PathBoard` fits the portal/crystal sprites inside their fixed endpoint tiles, above terrain and below enemies/tower effects, with contact shadows. The obsolete E/B glyph renderer is removed. Route coordinates, endpoint protection, budget, and match authority are unchanged. These ordinary shipped images introduce no runtime service dependency and do not claim to be PixelLab outputs or finalized world art.

### Next board-art trial

Choose a shared camera angle, outline style, palette, and pixel scale before generating a small sample:

1. One tower and an evolved version, checking that identity survives the change in size and function.
2. One enemy with a directional walk cycle, checking frame alignment and consistent appearance.
3. Refined crystal and portal art that remains readable against the terrain, using the current locally authored endpoints as a comparison.
4. Ground and connecting path tiles, checking bends and adjacent sections. Defer paid map tooling until the initial asset results justify it.

Judge these together at the intended game zoom, including a crowded arrangement. Inspect silhouettes, animation timing, transparency, palette consistency, and manual cleanup required. Avoid generating the full roster or buying several subscriptions before this trial.

The commander is off-board, so a playable hero sprite is not the first asset priority. Most tower buildings do not need eight directional views; consider a separate aiming-weapon sprite where appropriate.

Tile size, sprite canvas size, and occupied gameplay footprint are separate decisions. Some PixelLab character modes pad the canvas for animation, so requested character size does not guarantee identical frame dimensions. Inspect exported dimensions and pivots before import; use nearest-neighbor filtering.

Generate assets during development and ship ordinary image files. Players should need neither an AI account nor an API key. Keep credentials out of Git and obtain approval before connecting paid services or spending credits.

References: [PixelLab MCP documentation](https://api.pixellab.ai/mcp/docs), [PixelLab API pricing and estimate caveats](https://www.pixellab.ai/pixellab-api), and [Retro Diffusion capabilities and pricing](https://retrodiffusion.ai/).


## Path workshop verification

The main menu lives in `scenes/main_menu.tscn`; navigation remains owned by `main.gd`. `menu_wordmark.gd` centers ivory G/RCS around a green pixel-orc O with brows, eyes, and two tusks. A brief blink and one-pixel lift use a local idle clock; hidden menus stop that processing. `menu_button.gd` adds a short inner-bracket hover/focus response without moving controls or delaying visibility. The new theme preserves Pixelify labels, visible keyboard focus, a primary Play action, and quiet Quit. No new audio, settings, runtime services, or gameplay rules were added.

The O is raised two logical pixels. The first-load logo entrance lasts 1.1s: integer-stepped letter settling and center-out pixel-block assembly, then eye opening and a narrow warm sweep. `assets/ui/logo_entrance.gdshader` affects only the wordmark, retains a faint complete silhouette, and is detached after completion. Buttons/focus stay usable throughout. Hiding the menu during the entrance completes it immediately; returning never replays it. Glyph advances are cached rather than recalculated each animated draw.

Rendered smoke captured assembly, eye-opening/sweep, and the final compact menu. Actual clicks worked before the entrance completed; early hide/show, hidden-processing stop, stable control bounds, no replay, navigation, workshop UI, and main-scene startup passed. Temporary capture code was removed.

Workshop header/sidebar use the match HUD palette. The shared `PathBoard` draws grass/soil, connected stonework, rim, portal, and crystal for both local and command boards. A fixed visual margin keeps the workshop rim clear of controls. Rejection feedback moved out of the content VBox into a screen-anchored footer: warnings remain visible, but their appearance/expiry cannot change board bounds or cell coordinates.

Verification passed import/startup, the new workshop UI regression, navigation, chest flow, camera/input, native tower drag/drop, and rendered board regressions. Actual main-scene clicks exercised both endpoints/buttons, over-budget painting, notice expiry, legal paths, clear/resume and hover at 1280×720 and 1000×720. Menu/rest/hover and workshop empty/notice/path captures were inspected. A separate real-clock graphical smoke observed the logo lift/blink, stable button hit bounds, and hidden-menu processing stop. Isolated collection saves were used and temporary harnesses removed.


The resource import, main-scene headless run, and path-rule regression command above pass. Regressions cover budget rejection/refunds, immutable endpoints, out-of-bounds placement, shortcut selection, disconnected islands, edge-only adjacency, and deterministic equal-length routes.

The graphical scene was exercised through mouse input: placement, dragging, bridge removal, endpoint protection, isolated-tile removal, budget rejection, and the clear button. Rendered screenshots were inspected for clipping and route readability. The desktop run used Intel OpenGL after NVIDIA driver warnings.

Navigation regressions pass both headlessly and graphically: keyboard opening/resuming, returning while drawing, preserving the route and budget, rejecting edits on the hidden board, idle hovering, and releasing the mouse outside the board. Idle motion checks the held-button state only when a drawing button is active; passing `MOUSE_BUTTON_NONE` to Godot's button query is invalid. Menu transitions cancel the stroke so returning cannot continue a stale drag.

The main menu, session-resume menu, and compact workshop were visually inspected. The actual Quit button terminated the graphical process. Menu navigation preserves the existing layout but does not save it to disk.

For manual verification, connect the portal to the crystal, create a longer branch and a shortcut, remove a connecting tile, add/remove an isolated tile, exhaust the budget, and clear the board. Check readiness, budget, and connected pavement after edits. Click both fixed endpoints and verify that notices stay in the footer without changing the map size. Resize and check that controls remain visible and mouse coordinates still match tiles.

Also open the workshop by keyboard, draw while holding the mouse and press Esc, release outside the board, and resume. Hovering must not draw or emit mouse-button errors. Return through the Menu button and resume again; budget and route must remain unchanged.

Desktop exports are not implemented or verified. Direct connection, shared planning, and the resource-driven defense loop are implemented and locally verified; separate-machine internet connectivity is not verified.

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
