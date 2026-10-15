# Gorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Playable local path workshop, persistent collection/chests, and host-authoritative two-player defense through **Play**, with a local **Singleplayer** mirror opponent for testing. Matches use one continuous world behind a fixed HUD; **WASD** pans and **scroll / pinch** zooms. Committed Ready, normal-round deadlines, ten-round strategy breaks, and repeated three-sided map growth are implemented alongside Coins, paid towers, upgrades/selling, weighted waves, typed sends/income, persistent health, and results. Loadouts, permanent stat growth, and final art remain unimplemented.

The UI pairs bundled **Pixelify Sans** labels with crisper **Silkscreen** pixel numerals for prices, health, stats, and counts. Small interface text stays at least 16px. Both fonts work offline and include their [Pixelify](assets/fonts/OFL.txt) and [Silkscreen](assets/fonts/silkscreen/OFL.txt) licenses.

The supplied **Orcish Drone** track loops during match planning, combat, wave breaks, and the in-match pause/settings menu. It stops on results or leaving the match; title menus, connection setup, workshop, and collection stay silent. Playback is local and does not restart on host snapshots or volume changes.

## Run

Use the standard Godot edition and the [required engine release](docs/development.md#setup). Import `project.godot` into Godot and press **F5** to run the project.

For command-line launch and verification, see the [development commands](docs/development.md#setup).

The centered main-menu wordmark uses a larger green pixel-orc O with pointed ears, heavy brows, a broad jaw, and upward tusks, aligned to the letters' bottom edge. On first load, the logo assembles in crisp pixel blocks, then the orc braces, squeezes its eyes shut, and opens its jaw for a short animated roar. The tusks descend with the jaw; the face recovers before the finishing light sweep. This is a silent animation, not a new sound effect. Buttons work throughout, and the entrance never replays on menu return; occasional blinking/tiny idle lift remain afterward. Hover/focus marks stay inside fixed button bounds.

Click the orc O to replay just his silent roar. Other letters do not trigger it; clicks during an active roar are ignored, and leaving the menu cancels it cleanly without replaying the full logo entrance.

**Play** uses a centered menu with a primary Singleplayer action, paired Host/Join choices, and the same button styling/hover effects as the title screen. Connection forms, waiting rooms, real errors, and Cancel/Leave stay in the compact column rather than spanning the screen.

Title and Play menus share one hover/keyboard selection: moving onto an enabled button moves focus there, and arrow navigation continues from it. These menus have no explanatory hover popups. The pointer uses the original 32×32 [“iron dagger” by ACC_10](https://www.cursor.cc/?action=icon&file_id=161259), listed by cursor.cc as “Creative Commons, no attribution,” with its original tip hotspot. Battlefield and workshop terrain, towers, and enemies retain the dagger; UI controls that request a hand use the locally authored ivory/green hand. Text editing and resize cursors retain their native shapes.

## Test solo

- Choose **Play → Singleplayer** to start immediately without a connection, port, or invite.
- The initial view shows your own side of the continuous world. Hold **WASD** to pan and inspect the mirrored opponent; use **scroll / pinch** to zoom. The HUD stays fixed and opponent-side input remains read-only.
- The opponent mirrors accepted path edits, tower purchases, targeting, upgrades, sales, enemy sends, and readiness. Pressing **Ready** starts both boards.
- The pixel **> / >>** button toggles 2× simulation speed; the loop-arrow button toggles autoplay. Solo consent applies immediately, but autoplay still waits for Ready in initial setup and main rounds. It continues ordinary rounds after both boards clear; disabling restores manual planning.
- Collection locks, prices, combat, wave breaks, and results use the same rules as multiplayer. Identical defenses can end in the existing simultaneous-defeat coin flip; this is a testing opponent, not AI.
- **Esc or the cogwheel** opens **Resume / Settings / Quit** without ending the run. Solo simulation pauses; Resume continues the same run. Settings has independent Music and Sound volume sliders, saved locally; zero mutes that category. Sound controls the effects bus, but no sound effects are shipped yet. Esc first cancels an active placement/inspection, returns from Settings to the pause menu, or resumes from the pause menu. Quit returns to the main menu; opening Singleplayer again starts fresh without changing workshop layouts or collection progress.

## Play with a friend

- Choose **Play → Host**, enter an IP address your friend can reach and a UDP port, then **Create room**.
- Use **Copy invite code** and share the complete code privately. Your friend chooses **Play → Join**, pastes it, and presses **Connect** or Enter.
- Admission opens shared planning in one continuous world: host on the left, guest on the right, initially focused on your own side. **WASD** pans in four directions and **scroll / pinch** zooms within bounds around the cursor. Only your own board accepts edits, wherever the camera is looking. Match paths are separate from the local workshop and are not saved.
- Round/Coins, health, the menu cogwheel, and tower controls stay in a fixed HUD over a separate world viewport. Planning shows tile budget and opponent readiness; combat shows alive counts. Camera hints, route explanations, and spawn progress remain in tooltips. Management/notices never resize the world. Typing and targeting popups take priority over camera keys; scrolling HUD panels never zooms the map.
- The visible tower palette shows all types, numeric Coin prices, and collection locks. Click a tower then empty non-path ground, or drag it onto your board. Right-click or Escape cancels placement. Clicking an owned tower opens its kills, stats, targeting, damage/speed upgrades, and Sell menu. Affordability explanations are in tooltips rather than repeated beneath every price.
- Build the initial path before round 1. Later, paths change only during **main-round planning before rounds 10, 20, 30…**. Clear path appears only in those main rounds. With no tower selected, left/right drag edits a permitted path; otherwise board clicks inspect. Combat and normal-round paths remain locked.
- **Ready commits your planning actions:** no Unready, path edits, purchases, upgrades, selling, targeting, or sends until combat starts. Both Ready starts sooner. On normal rounds, the first Ready starts a **20-real-second** host countdown and the round starts automatically at expiry; 2× speed does not shorten it. Initial setup and main rounds are untimed, requiring both Ready.
- Before rounds **20, 30, 40…**, both maps gain a row above, a row below, and a column on the outer/crystal side, plus **+6 path tiles**. The portal-facing edge never grows. **Portal and crystal positions do not move**, nor do existing towers/paths; the new outer column lies beyond the crystal. The camera frames the enlarged owned board once, without expansion highlights; subsequent snapshots preserve your view. Values remain provisional.
- The pixel **> / >>** and loop-arrow buttons request 2× speed/autoplay. Multiplayer needs both players' consent; either withdrawal stops the shared effect without erasing the other request. Gold is pending; green is agreed. Autoplay pauses for untimed initial/main strategy, keeps consent, and resumes ordinary rounds after both Ready. Results never restart.
- Arrow and Ballista initially hit one target; their third upgrades add a second distinct target or a single bounce. Rune damages every enemy in its surrounding 3×3 tile neighborhood, with a brief ground shimmer and local hit sparks. Selected range is quietly highlighted tiles, not an attack ring. All types support Furthest, Closest, and Strongest targeting; the upgraded second archer has its own selector.
- Enemies alternate between equally short branches instead of all taking one side. The host assigns each enemy its shortest route at spawn, using a per-board round-robin choice at each fork; regular and sent enemies share that rotation, reset each wave. Longer detours stay unused. Visuals, facing, and selected-enemy highlights follow that individual route smoothly through corners. Connected pavement still has no route-line overlay.
- Enemy visuals are smaller: Grunt 0.50, Runner 0.45, and Brute 0.70 tiles tall. Subtle, stable sideways spread lets units share a tile without stacking every silhouette on the centerline. It changes no routing, targeting, collision, or damage rules. Clicking uses visible sprite pixels so transparent overlap does not steal selection.
- Portal spacing is irregular but bounded: the host generates one timetable per wave and both players get it. Small clusters and breathing gaps replace the metronomic stream without changing its roster or that round's planned spawn window. Regular and sent enemies share a linear interval reduction: 0.5% of the original interval per round after round 1, capped at 50% from round 101 onward. Regular base spacing goes from 0.75 to 0.375 simulation seconds; paid-send spacing goes from 0.35 to 0.175. Existing HP, movement-speed, count, and reward scaling stay separate; 2× playback still applies normally.
- Click an enemy on either board to inspect that individual. Corner highlights follow it along the path; a fixed right-side overlay shows its short description, health bar, current HP, speed in cells/second, and damage to the base beside heart, boot, and sword icons. Stats update from accepted live enemy state. Click another enemy to switch; empty ground, ×, right-click, or Escape dismisses it. Death, reaching the base, results, and leaving also clear inspection. Tower placement takes priority while a tower is selected for building.
- Each match entrance is a red stone-ring portal and each base is a blue crystal on a stone pedestal. Both play restrained 16-frame idle loops in matches and the workshop: curling portal wisps/embers and shimmering crystal facets/sparks. Stonework stays fixed, and the 3.2-second cosmetic loops do not accelerate at 2× match speed. The original sprites remain preserved; all endpoint artwork was authored locally without external generation services or costs. Camera scouting does not expand either grid or increase its path-tile budget.
- Match artwork uses per-resource opaque height and foot/base anchors, contact shadows, and foot-height depth sorting. Towers are substantial structures beside enemies. The playable field has broad restrained grass/soil variation, an external earth edge, and clear contrast against darker surrounding scenery and the central ravine. Continuous orderly stonework defines paths; decoration implies no new blocked cells or footprints. Selection and placement legality are contextual, idle combat has no hover square, and only damaged enemies show health bars. Camera fitting reserves resource-derived headroom so top-row towers clear the fixed HUD.
- A destroyed base ends the run. If both bases reach zero in the same host simulation tick, one host-owned random coin flip chooses the winner and both players see that result. The finished run cannot restart; leave/rejoin begins fresh.
- Coins fund towers, one damage upgrade, one speed upgrade, and one type-specific special; kills and cleared waves earn Coins. Towers show **I → II → III → IV** in their click-open menu. The first two stat upgrades use the original linear pricing: Arrow **30 → 45**, Ballista **55 → 83**, Rune **45 → 68** Coins. After **both** are purchased, the two stat buttons are replaced by **one full-width special button**, with a fixed price unaffected by level scaling. Arrow's **Second archer (200)** adds a visible archer, independent second targeting, a distinct second arrow target, and 10% more attacks/s. **Bouncing bolts (300)** gives Ballista one nearest-other-enemy bounce for 50% damage, rounded up. **Freeze rune (250)** slows an enemy by 20% for **2 simulation seconds** once that individual obelisk has cumulatively dealt at least 20% of its maximum HP; further qualifying hits refresh the timer without stacking. Slowed enemies turn bluish and return to their original color/speed on expiry. Arrow shots are small moving arrows; Ballista bolts visibly travel through their bounce. Selling refunds part of the actual investment. Prices remain provisional playtest values in `resources/combat/towers/`.
- Choose **Grunt**, **Runner**, or **Brute**, then **Send**. Paid enemies use an independent FIFO stream on the opponent's board: starting at one every 0.35 simulation seconds and tightening with round progression, alongside regular spawns and outside their budget/caps. An idle stream starts immediately during combat; further orders keep their purchase order. Sends work throughout combat, with no delivery cutoff. Planning purchases wait until combat starts, then release at that round's cadence rather than all at once. Each type retains its price and recurring wave-clear income gain; rejected sends change nothing. Both pending deliveries and living enemies must clear before the round ends. The footer shows nonzero `Income +N`, incoming (`In N`), and outgoing (`Out N`) pending counts, with composition/payout tooltips. Continuous funded sends can prolong combat. Type values live in `resources/combat/enemies/`; cadence lives in `resources/combat/prototype.tres`.
- The host randomly fills each regular wave's weight budget and gives both players the identical ordered roster. Grunts weigh 1; Runners weigh 2 and unlock on wave 3; Brutes weigh 5 and unlock on wave 6. Runner count caps start at 4 and gain 1 every 3 waves after unlocking; Brute caps start at 2 and gain 1 every 4 waves. Their 30%/35% weight-share ceilings still apply. Sends remain extra. Grunt/Runner leaks deal 1 base damage; Brutes deal 3. Health and speed scale with the delivery wave. All three retain their sprites, facing, and damaged-only health bars. See [enemy roster values and extension rules](docs/development.md#enemy-roster).
- The code contains the host's address and a random room credential. There is no online room lookup or NAT traversal service. Use the same LAN, a private network/VPN, or a public host address with UDP forwarding and firewall access.
- **Esc or the cogwheel** opens the local match menu; multiplayer keeps running while it is open. **Quit** in that menu closes your connection and returns to the main menu. If the guest leaves, the host waits for another guest with the same code; rejoining starts with fresh boards. If the host leaves, the room closes and its code expires.
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
- Workshop terrain, stone paths, portal entrance, and crystal base share the match artwork. Header/sidebar use the same dark-green HUD palette. Endpoint and budget notices appear in a fixed footer without resizing the map or shifting click coordinates.
- Unused budget is allowed. A ready layout connects the base and every placed tile to the entrance.
- Enemies use the shortest route, not placement order. Branches and adjacent sections can create shortcuts; there is no route-line overlay.
- The 14×9 board, opposite-side endpoints, and 30-tile maximum are provisional. Adjust the main scene's exported settings together in the Inspector.

This workshop does not simulate waves, enemies, or combat-time route locking.

## Documentation

- [Game brief (PDF)](docs/goorcs-brief.pdf): a three-page introduction for friends, with [editable source](docs/goorcs-brief.typ).
- [Agent instructions](AGENTS.md): required reading, editing rules, state ownership, and completion criteria.
- [Game direction](docs/game-direction.md): intended experience, technical decisions, and first playable milestone.
- [Visual TODO](TODO.md): implemented presentation pass, real gameplay captures, shared actual-size lineup, and pending sprite-replacement approval.
- [Development workflow](docs/development.md): setup, verification, and optional MCP tooling.
- [AI-to-sprite pipeline](docs/sprite-pipeline.md): local reference editing, agent/API steps, cleanup, provenance, and approval before importing artwork.
- [Pixel-art archive](archive_assets/README.md): original candidates, prepared sprites, searchable tags, and source provenance; excluded from Godot imports.

## Layout

```text
project.godot       Engine settings and main scene
AGENTS.md          Repository editing instructions
scenes/            Main navigation, connection lobby, shared defense, local path workshop, collection, chest reveal
scripts/           Rule owners, networking, persistence, input, and presentation
resources/collection/  Tower reward definitions
resources/combat/  Provisional defense-loop configuration
assets/            Imported chest/tower sprites and locally authored enemy/crystal/portal PNGs
archive_assets/    Archived pixel-art variants and sources, with per-image catalog and tags
tests/             Path, navigation, collection, chest, real peer-session, planning, match-world, combat rules and peer combat
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
