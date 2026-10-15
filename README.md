# Gorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Playable host-authoritative two-player defense through **Play**, local mirrored **Singleplayer**, a free-build **Sandbox**, persistent collection/chests, and the **Orcieary** enemy guide with lifetime records. Seven animated enemy types include grouped Orclings, healing Chiefs, and NecOrcmancers raising SkeleOrcs. Matches retain weighted waves, staged paid sends/income, committed readiness, strategy breaks/map growth, tower branches, persistent health, and results. Loadouts and permanent stat growth remain unimplemented.

The UI pairs bundled **Pixelify Sans** labels with crisper **Silkscreen** pixel numerals for prices, health, stats, and counts. Small interface text stays at least 16px. Both fonts work offline and include their [Pixelify](assets/fonts/OFL.txt) and [Silkscreen](assets/fonts/silkscreen/OFL.txt) licenses.

The supplied **Orcish Drone** track loops during match planning, combat, wave breaks, and the in-match pause/settings menu. It stops on results or leaving the match; title menus, connection setup, Sandbox, Orcieary, and collection stay silent. Playback is local and does not restart on host snapshots or volume changes.

## Adding game content

Towers and enemies are authored as Godot resources and registered in one explicit content catalog. Follow the [content pipeline](docs/content-pipeline.md) for resource fields, registration, existing attack behaviors, and verification. New identities, stats, and artwork should not require adding ID branches to gameplay code; genuinely new mechanics still require implementation.

## Run

Use the standard Godot edition and the [required engine release](docs/development.md#setup). Import `project.godot` into Godot and press **F5** to run the project.

For command-line launch and verification, see the [development commands](docs/development.md#setup).

The centered main-menu wordmark uses a green pixel-orc O with pointed ears, heavy brows, a broad jaw, and upward tusks. Its neutral face matches the letters' top and bottom edges, with pixel-snapped rows and matching pointer hit detection. On first load, the logo assembles in crisp pixel blocks, then the orc braces, squeezes its eyes shut, and opens its jaw for a short animated roar. The tusks descend with the jaw; the face recovers before the finishing light sweep. This is a silent animation, not a new sound effect. Buttons work throughout, and the entrance never replays on menu return; occasional blinking/tiny idle lift remain afterward. Hover/focus marks stay inside fixed button bounds.

Click the orc O to replay just his silent roar. Other letters do not trigger it; clicks during an active roar are ignored, and leaving the menu cancels it cleanly without replaying the full logo entrance.

**Play** uses a centered menu with a primary Singleplayer action, paired Host/Join choices, and the same button styling/hover effects as the title screen. Connection forms, waiting rooms, real errors, and Cancel/Leave stay in the compact column rather than spanning the screen.

Menus support mouse hover and visible keyboard focus; arrows/Tab navigate and Enter activates. Main-menu shortcuts are **P** Play, **S** Sandbox, **B** Orcieary, and **C** Collection. Escape returns or resumes the last activity; text fields/dialogs take priority. The gameplay pointer uses the steel variant from [Gauntlet Cursor by itsmars](https://opengameart.org/content/gauntlet-cursor), based on yd's CC0 artwork, at its original 32×32 size. Clickable UI retains the separate hand pointer; text/resize cursors remain native.

## Test solo

- Choose **Play → Singleplayer** to start immediately without a connection, port, or invite.
- The initial view shows your own side of the continuous world. Hold **WASD** to pan and inspect the mirrored opponent; use **scroll / pinch** to zoom smoothly around the cursor. Panning slows down when zoomed in. The HUD stays fixed and opponent-side input remains read-only.
- The opponent mirrors accepted path edits, tower purchases, targeting, upgrades, sales, enemy sends, and readiness. Pressing **Ready** starts both boards.
- The pixel **> / >>** button toggles 2× simulation speed; the loop-arrow button toggles autoplay. Solo consent applies immediately, but autoplay still waits for Ready in initial setup and main rounds. It continues ordinary rounds after both boards clear; disabling restores manual planning.
- Collection locks, prices, combat, wave breaks, and results use the same rules as multiplayer. Identical defenses can end in the existing simultaneous-defeat coin flip; this is a testing opponent, not AI.
- **Esc or the cogwheel** opens **Resume / Settings / Quit** without ending the run. Solo simulation pauses; Resume continues it. Settings has saved independent Music and Sound sliders; no effects audio is shipped yet. Escape first cancels placement/inspection, backs out of Settings, or resumes. Quit returns to the main menu without changing Sandbox, collection, or lifetime records.
- The small **#** button at the bottom right opens **Round / Money / Apply** in solo and for multiplayer hosts. Changing the round returns to planning before that round without clearing your build or granting rewards; money-only changes keep combat running. Solo changes both mirrored balances; online changes only the host's balance. Earlier rounds retain already-grown ground.

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
- Arrow and Ballista initially hit one target. Arrow's later special adds a second distinct target; Ballista instead chooses a straight-through **Pierce 2** bolt or a redirected **Bounce 1** bolt. Unevolved Rune hits every enemy in its surrounding 3×3 tile neighborhood in discrete pulses, with a 0.7-simulation-second base interval and no damage between pulses. Each pulse retains the brief ground shimmer and local hit sparks. Its later evolution chooses continuous Boulders damage or heavier Onyx Ring pulses. Selected range is quietly highlighted tiles, not an attack ring. All types support Furthest, Closest, and Strongest targeting; the upgraded second archer has its own selector.
- Enemies alternate between equally short branches instead of all taking one side. The host assigns each enemy its shortest route at spawn, using a per-board round-robin choice at each fork; regular and sent enemies share that rotation, reset each wave. Longer detours stay unused. Visuals, facing, and selected-enemy highlights follow that individual route smoothly through corners. Connected pavement still has no route-line overlay.
- Every enemy has its own face/anatomy in a unified pixel-art style, articulated twelve-frame walking, and a distinct death collapse. Chiefs raise a palm to heal and NecOrcmancers raise their staff to cast. Living Orc deaths leave a small blood splatter; SkeleOrcs collapse into bloodless bones. Bodies/effects fade, never remain targetable, and never change rewards or wave clearance.
- The host creates the same weighted group roster/timetable for both boards. Orcling events roll 2–4 members in close succession, then wait the ordinary cooldown. Spawn cadence still tightens linearly with rounds; grouping, health/speed, weight/share caps, and reward scaling are separate rules.
- Click an enemy on either board to inspect that individual. Corner highlights follow it along the path; a fixed right-side overlay shows its short description, health bar, current HP, speed in cells/second, and damage to the base beside heart, boot, and sword icons. Stats update from accepted live enemy state. Click another enemy to switch; empty ground, ×, right-click, or Escape dismisses it. Death, reaching the base, results, and leaving also clear inspection. Tower placement takes priority while a tower is selected for building.
- Each entrance is an animated red stone-ring portal and each base a blue crystal on a stone pedestal. Their cosmetic loops are shared by matches and Sandbox and do not accelerate at 2× simulation speed. Camera scouting never grants additional usable ground or path budget.
- Match artwork uses per-resource opaque height and foot/base anchors, contact shadows, and foot-height depth sorting. Towers are substantial structures beside enemies. The playable field has broad restrained grass/soil variation, an external earth edge, and clear contrast against darker surrounding scenery and the central ravine. Continuous orderly stonework defines paths; decoration implies no new blocked cells or footprints. Selection and placement legality are contextual, idle combat has no hover square, and only damaged enemies show health bars. Camera fitting reserves resource-derived headroom so top-row towers clear the fixed HUD.
- A destroyed base ends the run. If both bases reach zero in the same host simulation tick, one host-owned random coin flip chooses the winner and both players see that result. The finished run cannot restart; leave/rejoin begins fresh.
- Coins fund towers, damage/speed upgrades, and specials/evolutions; kills and cleared waves earn Coins. Towers show **I → II → III → IV**, with Boulders' follow-up reaching **V**. The first two stat upgrades use linear pricing: Arrow **30 → 45**, Ballista **55 → 83**, Rune **45 → 68** Coins. Buying both exposes the final choices at fixed prices unaffected by level scaling. Arrow's **Second archer (200)** adds a visible archer, independent second targeting, a distinct second arrow target, and 10% more attacks/s. Ballista permanently chooses **Pierce 2 (300)** or **Bounce 1 (300)**: Pierce hits the first two enemies along the aimed straight line within range at full damage; Bounce keeps the primary hit and redirects once to the nearest other enemy for half damage, rounded up, even beyond tower range. Both retain upgraded damage and firing cadence. Rune chooses **Boulders (250)** or **Onyx Ring (250)** permanently for that tower. Boulders continuously spins stones and deals **6 damage per simulation second** throughout the existing 3×3 neighborhood, not just on stone contact. Onyx Ring deals **6 damage every 0.75 simulation seconds** to that neighborhood: higher sustained damage with uninterrupted coverage, but gaps between pulses. Boulders then offers **Freeze Runes (250)**: after that tower has dealt at least 20% of an enemy's maximum HP, its upgraded damage applies a nonstacking **20% slow for 2 simulation seconds**; later qualifying damage refreshes it. Earlier damage from that Rune counts, but purchase alone cannot slow. Icy stones and bluish affected enemies show the effect. Onyx cannot buy Freeze Runes. Selling refunds part of the actual investment. Prices and evolution balance remain provisional in `resources/combat/towers/`.
- Only **Orclings** can be sent in rounds 1–5. **Orc / Runner / Brute / Chief / NecOrcmancer** sends unlock at rounds **6 / 12 / 22 / 34 / 46**. Orders use an independent paced FIFO throughout combat; planning orders wait for wave start. One Orcling order buys its whole rolled group. Rejected orders spend/roll nothing; pending sends and living summons must clear before a wave ends.
- Regular waves introduce **Runner at 6**, **Brute at 12**, **Chief at 22**, and **NecOrcmancer at 34**, with count/share limits. Chiefs periodically heal nearby allies; NecOrcmancers raise bounded SkeleOrcs on their remaining captured route. SkeleOrcs are summon-only outside Sandbox. See [enemy balance, abilities, and verification](docs/enemy-roster.md).
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
- **Reset progress** clears collection unlocks after confirmation. It does not alter Sandbox state or enemy lifetime records.
- Collection unlocks and enemy statistics survive restarting. Sandbox layouts last for the running session. See [save ownership and verification](docs/development.md#collection-and-chest-verification).

## Sandbox and Orcieary

- **Sandbox** replaces Workshop: every tower, upgrade branch, enemy, and chosen round is available without collection locks, Coin costs, tile spending, or defeat.
- Draw paths while stopped, choose a weighted round or an exact enemy/count, pause/resume with **Space**, and test at 1×/2×/4× speed.
- Resize the map through width/height controls with confirmation. Menu/Escape pauses and preserves the current build, map, and camera; leaving never changes progression.
- **Orcieary** orders enemies by earliest encounter/send availability and lists their descriptions, portraits, stats, mechanics, and lifetime records. Click a portrait—or focus it and press Enter/Space—to play its action once. Sandbox actions are excluded from records.
- Full controls, balance rules, save behavior, and verification: [enemy roster and sandbox](docs/enemy-roster.md).

## Documentation

- [Game brief (PDF)](docs/goorcs-brief.pdf): a three-page introduction for friends, with [editable source](docs/goorcs-brief.typ).
- [Agent instructions](AGENTS.md): required reading, editing rules, state ownership, and completion criteria.
- [Game direction](docs/game-direction.md): intended experience, technical decisions, and first playable milestone.
- [Visual TODO](TODO.md): implemented presentation pass, real gameplay captures, shared actual-size lineup, and pending sprite-replacement approval.
- [Development workflow](docs/development.md): setup, verification, and optional MCP tooling.
- [Enemy roster and sandbox](docs/enemy-roster.md): grouped spawns, abilities, staged sends, animated presentation, lifetime statistics, and testing controls.
- [AI-to-sprite pipeline](docs/sprite-pipeline.md): local reference editing, agent/API steps, cleanup, provenance, and approval before importing artwork.
- [Pixel-art archive](archive_assets/README.md): original candidates, prepared sprites, searchable tags, and source provenance; excluded from Godot imports.

## Layout

```text
project.godot       Engine settings and main scene
AGENTS.md          Repository editing instructions
scenes/            Main navigation, connection lobby, shared defense, sandbox, Orcieary, collection, chest reveal
scripts/           Rule owners, networking, persistence, input, and presentation
resources/collection/  Tower reward definitions
resources/combat/  Provisional defense-loop configuration
assets/            Imported chest/tower sprites and locally authored enemy/crystal/portal PNGs
archive_assets/    Archived pixel-art variants and sources, with per-image catalog and tags
tests/             Path, navigation, collection, chest, real peer-session, planning, match-world, combat rules and peer combat
tools/             Single-command project verification
.github/workflows/ Automated verification using the same local commands
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
