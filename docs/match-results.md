# Match results and playback

## Terminal outcome

The authoritative combat owner still ends the run when a crystal reaches zero health. Same-tick destruction is resolved once by the host's existing coin flip. The new `MatchResultsMenu` presents that accepted outcome from each player's own slot: Victory or Defeat, the cause, reached round, final own/opponent health, and that player's match kills/sent individuals. It grants no new currency, rewards, or progression.

The full-screen dimmed overlay blocks underlying HUD/world input without pausing the SceneTree or changing the terminal state. Multiplayer peers can leave independently through normal connection teardown. Repeated terminal snapshots do not reopen a dismissed result or steal keyboard focus. Main-menu navigation, disconnect, hidden screens, and a new model clear the overlay lifecycle.

- **View battlefield** or **Escape** dismisses only the local overlay. Camera scouting remains available; terminal build/send/upgrade/target commands remain rejected.
- The HUD **Results** action, cogwheel, or Escape reopens final details.
- **Main menu** leaves the session normally.
- Solo additionally offers **Play again**, which creates a fresh Singleplayer model, maze, run identity, camera activation and 1× speed. It preserves collection and lifetime records. It does not revive the completed model.
- Multiplayer has no fake local-only rematch action. A new room/admission starts a fresh match as before.

Buttons support Tab/Shift-Tab and arrow focus, Enter activation, and normal mouse input. Solo initially focuses Play again; multiplayer initially focuses View battlefield. Match music stops on the terminal outcome, including while the result is visible.

## Singleplayer speed

The pixel speed button cycles **1× → 2× → 3× → 1×** in Singleplayer. Its symbols are **> / >> / >>>**. `MatchPlanning` owns the selected multiplier and applies it once to the host simulation delta; UI state is not a second gameplay clock. Movement, spawns, reloads, burn/freeze, enemy abilities and local accepted-event playback therefore follow simulation speed consistently.

Ordinary wave transitions, autoplay and money-only debug changes retain solo speed. New runs, leaving/restarting, round-changing debug jumps and results reset it. Existing programmatic enable/disable pacing commands still mean 2×/1×; only the solo cycle API exposes 3×.

Multiplayer remains **1× or 2× with unanimous consent**. A guest cannot activate a solo 3× bypass. Normal-round Ready deadlines continue to use real seconds rather than accelerated simulation time; initial/main strategy still waits for readiness. Sandbox retains its separate existing 1×/2×/4× testing controls.

## Verification

`match_results_test.gd` checks the real screen lifecycle, modal/terminal command gates, compact/wide controls, inspect/reopen, repeated-snapshot focus preservation, fresh solo replay, and multiplayer leave. `solo_speed_test.gd` exercises the cycle, actual 3× simulation advancement, reset/preservation transitions, and multiplayer/terminal rejection. Existing real-peer pacing, real-time Ready, pause, navigation and enemy-inspection suites remain applicable.

The integrated result/speed pass passed **47/47 project checks**, followed by a focused result-input check with a selector open at defeat. A real graphical host and client connected in separate processes, played to terminal health `[1, 0]`, and displayed host Victory / guest Defeat with their own totals. A solo graphical smoke clicked the speed button through 2×/3×/1×, inspected the >>> indicator, played to simultaneous defeat, checked results at 1000×720/1280×720, dismissed/reopened them, and used Enter on Play again to create a fresh 1× run. Test saves were isolated; temporary scripts were removed after verification.
