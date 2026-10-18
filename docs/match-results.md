# Match results and playback

## Terminal outcome

The authoritative combat owner ends the run when a crystal reaches zero health. Same-tick destruction is resolved once by the host's existing coin flip. `MatchResultsMenu` presents that accepted outcome from each player's own slot, with the reached round, actually cleared rounds, combat simulation time, and the enemy responsible for the final crystal hit when recorded. A fatal-enemy label never replaces the simultaneous-destruction coin-flip explanation. The recap grants no currency, rewards, or progression.

The full-screen dimmed overlay blocks underlying HUD/world input without pausing the SceneTree or changing the terminal state. Multiplayer peers can leave independently through normal connection teardown. Repeated terminal snapshots do not reopen a dismissed result or steal keyboard focus. Main-menu navigation, disconnect, hidden screens, and a new model clear the overlay lifecycle.

- **View battlefield** or **Escape** dismisses only the local overlay. Camera scouting remains available. Click an owned tower still on the board to inspect its accepted final stats, rarity/attributes, performance counters, and current targeting where applicable.
- Final inspection is read-only: upgrade, reroll, and Sell controls are hidden; targeting is disabled. Path painting and placement stay disabled. Host validation still rejects every terminal mutation, including shortcuts or remote commands.
- Escape or right-click first clears tower selection; **Results**, the cogwheel, or another Escape reopens the recap.
- **Main menu** leaves the session normally.
- Solo additionally offers **Play again**, which creates a fresh Singleplayer model, maze, run identity, camera activation and 1× speed. It preserves collection and lifetime records. It does not revive the completed model.
- Multiplayer has no fake local-only rematch action. A new room/admission starts a fresh match as before.

The outcome/header and action footer stay fixed while the report scrolls, without scrollbar chrome, at both supported desktop widths. Mouse wheel scrolls the report rather than zooming the battlefield. Tab/Shift-Tab includes the report itself; with it focused, arrows, Page Up/Page Down, Home/End scroll its contents. Footer Left/Right wraps among visible actions only; Up/Down enters the report instead of moving sideways. Buttons retain keyboard activation. Solo initially focuses Play again; multiplayer initially focuses View battlefield. Match music stops on the terminal outcome, including while the result is visible.

## Recorded recap

Scroll down for:

- **Match overview:** own versus opponent/mirror crystal HP, killed/sent/leaked individuals, damage, and remaining Coins/Shards.
- **Economy:** kill rewards (including existing bounty/aura bonuses), wave-clear rewards, paid send income, direct Mine/Mint production, boss bonuses, and sale refunds; purchases, upgrades/evolutions, sends, attribute rerolls, and rarity-reroll Shards have separate spending categories.
- **Shard income:** enemy drops, round-clear grants, tower production, and first-boss bonuses.
- **Tower damage ranking:** rarity/evolution/level, actual damage share, kills, invested Coins, generated Coins/Shards, and indirect damage. Sold towers remain separate historical identities; replacing a tower on its old cell cannot inherit its counters.
- **Enemy breakdown:** kills and leaks on the player's board, individuals sent to the opponent, and actual crystal HP removed by each type. Lethal overkill is capped to remaining HP.
- **Boss rewards:** accepted first-kill rarity and Coin/Shard payout, not another roll or grant.

`MatchCombat` owns a `MatchRecap` event ledger. It records accepted transactions at their existing mutation owners, never reconstructs income from balances, and does not count starting balances or debug grants as earnings. Bounty/aura bonuses are already included in kill income, not counted again as production. Existing per-tower combat counters remain the single damage/performance owner. The ledger retains purchased tower dictionaries through sales so lingering burn damage can still update the sold source's final record.

Only terminal snapshots publish the detailed ledger, deeply detached from authoritative state. Combat duration uses the existing simulation clock: planning and actual simulation pauses add no time; accelerated simulation advances it faster than wall time. Combat continuing behind a multiplayer menu or cosmetic reel still counts, but a reel never creates its own gameplay time. Debug round jumps preserve actual accumulated history rather than inventing skipped clears or per-round trends. A fresh admitted model resets all recap history.

## Singleplayer speed

The pixel speed button cycles **1× → 2× → 3× → 1×** in Singleplayer. Its symbols are **> / >> / >>>**. `MatchPlanning` owns the selected multiplier and applies it once to the host simulation delta; UI state is not a second gameplay clock. Movement, spawns, reloads, burn/freeze, enemy abilities and local accepted-event playback therefore follow simulation speed consistently.

Ordinary wave transitions, autoplay and money-only debug changes retain solo speed. New runs, leaving/restarting, round-changing debug jumps and results reset it. Existing programmatic enable/disable pacing commands still mean 2×/1×; only the solo cycle API exposes 3×.

Multiplayer remains **1× or 2× with unanimous consent**. A guest cannot activate a solo 3× bypass. Normal-round Ready deadlines continue to use real seconds rather than accelerated simulation time; initial/main strategy still waits for readiness. Sandbox retains its separate existing 1×/2×/4× testing controls.

## Verification

`match_results_test.gd` checks the real screen lifecycle, modal/terminal command gates, compact/wide controls, read-only board input/tower selection, hidden mutation controls, inspection Escape precedence, inspect/reopen, repeated-snapshot focus preservation, fresh solo replay, and multiplayer leave. `match_recap_test.gd` covers accepted/rejected transactions, actual sold-source burn damage, capped lethal leaks, terminal immutability, detached history, and new-run boundaries. `match_recap_peer_test.gd` uses separate authenticated host/client processes to check matching terminal reports, payer ownership, sold identities, capped fatal leaks, and rejected client/terminal mutations. `solo_speed_test.gd` retains speed-cycle and timing coverage; existing pacing, Ready, pause, navigation and enemy-inspection suites remain applicable.

The integrated result/speed pass passed **47/47 project checks**, followed by a focused result-input check with a selector open at defeat. A real graphical host and client connected in separate processes, played to terminal health `[1, 0]`, and displayed host Victory / guest Defeat with their own totals. A solo graphical smoke clicked the speed button through 2×/3×/1×, inspected the >>> indicator, played to simultaneous defeat, checked results at 1000×720/1280×720, dismissed/reopened them, and used Enter on Play again to create a fresh 1× run. Test saves were isolated; temporary scripts were removed after verification.

The recap extension's isolated full run passed **75/76 checks**, including both new model/real-peer suites, result lifecycle/read-only input, and all headless suites. `enemy_inspection_test.gd` completed its behavior assertions but emitted **“7 resources still in use at exit”**, so the full run is not green. Logs: `.verify-logs/20261018T165111Z-all-aa390886/`. No failure was exempted.

A separate **4.67-second actual-main-scene graphical walkthrough** passed on macOS Apple M2 Compatibility/OpenGL with dummy audio. It played early rounds, sold/replaced a damaging tower, credited a real boss kill, and ended through an actual fatal leak; inspected scrolling economy, retained/sold damage rankings, enemy breakdown, and boss payouts at 1000×720/1280×720; exercised native wheel, Tab order, Home/End/Page Down, View battlefield, final Mine/Arrow inspection, selection-first Escape, and fresh replay. A synthetic simultaneous-destruction presentation also retained both the coin-flip explanation and fatal enemy label. Screenshots were inspected; native-audio attempts completed the scenario but reported retained audio resources at shutdown, so physical audio teardown is not validated by the passing dummy-audio visual run. Test saves were isolated and temporary scaffolds removed.

The footer navigation polish reproduced the old sideways Up behavior before editing, then passed a **6.92-second graphical native-key walkthrough** after the fix: horizontal action wrapping, vertical entry into the report, scrolling, Tab/Shift-Tab, and unchanged final gameplay at both desktop widths with solo and multiplayer footer layouts. The existing result lifecycle regression also passed after integrating current main. Captures were inspected; saves and the temporary walkthrough were isolated and removed. This focused dummy-audio UI check does not supersede the full-run shutdown limitation above.
