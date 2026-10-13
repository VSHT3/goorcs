// Build instructions and fonts: docs/development.md, "Shareable game brief".
// Editorial summary of docs/game-direction.md; update that specification first.
#let ink = rgb("24372E")
#let muted = rgb("60685F")
#let accent = rgb("48644A")
#let rust = rgb("99583F")
#let rule = rgb("D6DBD2")
#let wash = rgb("F1F4ED")
#let path-color = rgb("D9C99E")

#set document(title: "Goorcs | Game brief", author: "Goorcs", description: "A short overview of the planned game and its open design choices.")
#set page(paper: "a4", margin: (x: 18mm, top: 19mm, bottom: 18mm),
  header: context [
    #set text(font: "Noto Sans", size: 8pt, fill: muted)
    #grid(columns: (1fr, auto), [GOORCS / GAME BRIEF], [DESIGN DRAFT])
    #v(2mm)
    #line(length: 100%, stroke: 0.5pt + rule)
  ],
  footer: context [
    #line(length: 100%, stroke: 0.5pt + rule)
    #v(2mm)
    #set text(font: "Noto Sans", size: 8pt, fill: muted)
    #grid(columns: (1fr, auto), [Private game for friends], [#counter(page).display("01") / 03])
  ])
#set text(font: "Noto Sans", size: 11pt, fill: ink, lang: "en")
#set par(leading: 0.65em, spacing: 0.8em, justify: false)
#set heading(numbering: none)
#show heading.where(level: 1): it => block(above: 4mm, below: 6mm)[
  #text(font: "Anton", size: 31pt, weight: "regular", top-edge: "cap-height", bottom-edge: "baseline", it.body)
]
#show heading.where(level: 2): it => block(above: 5mm, below: 2mm)[
  #text(size: 13pt, weight: "bold", it.body)
]
#let small(body) = text(size: 8.5pt, fill: muted, body)
#let label(body) = block(below: 3mm)[#text(size: 8pt, weight: "bold", tracking: 0.7pt, fill: accent, upper(body))]
#let note(title, body) = block(width: 100%, inset: 4mm, fill: wash, radius: 1mm)[
  #text(size: 10pt, weight: "bold", title)
  #v(1.5mm)
  #text(size: 10pt, body)
]
#let step(n, title, body) = grid(columns: (8mm, 1fr), column-gutter: 2mm,
  text(font: "Anton", size: 20pt, fill: accent, top-edge: "cap-height", bottom-edge: "baseline", n),
  [#strong(title) #linebreak() #body],
)

#let board(route, towers, tint) = {
  let cell = 5.5mm
  block(width: cell * 9, height: cell * 7)[
    #for y in range(7) {
      for x in range(9) {
        let on-path = route.contains((x, y))
        place(top + left, dx: cell * x, dy: cell * y,
          rect(width: cell, height: cell, fill: if on-path { path-color } else { rgb("F7F8F4") }, stroke: 0.35pt + rule))
      }
    }
    #for tile in towers {
      place(top + left, dx: cell * tile.at(0) + 0.8mm, dy: cell * tile.at(1) + 0.8mm,
        rect(width: 3.9mm, height: 3.9mm, fill: tint, stroke: none))
    }
    #let start = route.first()
    #place(top + left, dx: cell * start.at(0), dy: cell * start.at(1) + 0.7mm,
      box(width: cell, align(center, text(size: 8pt, weight: "bold", "E"))))
    #let goal = route.last()
    #place(top + left, dx: cell * goal.at(0) + 1.5mm, dy: cell * goal.at(1) + 1.5mm,
      rotate(45deg, square(size: 2.5mm, fill: tint, stroke: none)))
  ]
}
#let route-a = ((8,1),(7,1),(6,1),(5,1),(4,1),(3,1),(2,1),(2,2),(2,3),(3,3),(4,3),(5,3),(6,3),(6,4),(6,5),(5,5),(4,5),(3,5),(2,5),(1,5),(0,5))
#let route-b = ((0,1),(0,2),(0,3),(0,4),(0,5),(1,5),(2,5),(3,5),(4,5),(4,4),(4,3),(4,2),(4,1),(5,1),(6,1),(7,1),(8,1),(8,2),(8,3),(8,4),(8,5))

#label[The idea]
#block(above: 4mm, below: 5mm)[#text(font: "Anton", size: 62pt, weight: "regular", top-edge: "cap-height", bottom-edge: "baseline")[Goorcs]]
#text(size: 12pt, weight: "bold")[A private 1v1 tower-defense game]
#v(3mm)

You build an enemy route and defend it while sending extra enemies at a friend. Both players also face regular waves. The game uses top-down pixel art in a broad fantasy world, with orcs as its foundation.

A run starts with a small defense. The board expands as towers evolve into larger structures. Powerful spells and much denser enemy waves make late combat increasingly intense. The intended sessions are longer; their duration is still open.

#v(3mm)
#block(width: 100%, inset: 4mm, stroke: 0.6pt + rule, radius: 1mm)[
  #grid(columns: (1fr, 39mm, 1fr), align: center,
    [#label[Left player] #v(2mm) #board(route-a, ((6,2),(4,4),(1,3)), accent)],
    [#label[Central entry] #v(2mm) #block(height: 38.5mm)[#block(above: 2mm, below: 3mm)[#text(size: 24pt, fill: rust)[← →]] #text(size: 8.5pt)[Regular waves\ and sent enemies]]],
    [#label[Right player] #v(2mm) #board(route-b, ((2,3),(6,3),(5,4)), rust)],
  )
  #v(3mm)
  #small[E = entrance · Squares = towers · Diamond = proposed crystal base]
  #v(1mm)
  #small[Entrances and crystals stay fixed as maps grow. Layouts and art are illustrative.]
  #v(1mm)
  #small[Your sends join the opponent’s stream. Each player designs a separate path.]
]

== A run at a glance
#step("1", [Prepare a loadout], [Choose a limited set of tower types from your permanent collection. Your hero is an off-board commander.])
#v(3mm)
#step("2", [Build and fight], [Buy and improve towers during combat. Sending enemies costs currency and increases future income, competing with spending on your own defense.])
#v(3mm)
#step("3", [Develop the defense], [Buy upgrades and adapt to random rewards. Both your path allowance and the whole map grow at milestones.])
#v(3mm)
#step("4", [Finish the duel], [Enemies that reach a base damage it. Base health carries between rounds; destroying the opposing base wins the run.])

#pagebreak()
#label[Playing the game]
= Building the defense

== You lay the path
Both players begin with an equal budget of path tiles on a square grid. The tiles must connect the entrance to the base. Enemies take the *shortest route across connected tiles*, so joining two nearby sections can create a shortcut.

Towers use the same grid. Their placement must preserve the route. Some major upgrades need more space, so room for a larger tower is part of planning. Exact board dimensions and tile allowances are undecided.

#v(2mm)
#table(
  columns: (1fr, 1fr),
  inset: 4mm,
  stroke: 0.5pt + rule,
  fill: (x, y) => if y == 0 { wash } else { none },
  table.header([*During a wave*], [*During planning breaks*]),
  [Build, upgrade and sell towers. Use abilities on either board. Send enemies, scout, gamble, construct other buildings and interact with map features. The current route stays fixed.],
  [Redesign the path and freely relocate existing towers while keeping their upgrades and traits. Break timing is still being decided.],
)

== Enemy sends and spells
Purchased enemies enter the opponent’s current wave until a cutoff. Later orders wait for the next wave. Both boards clear before the planning break.

Spells aimed at the opponent cause temporary disruption. They cannot permanently destroy towers or directly damage the base.

== Known towers, different results
You buy a chosen tower type from your loadout. Its bonuses are randomized, with both stat changes and traits that can change how it works with the rest of your defense. When those bonuses become visible is still open.

Tower growth combines ordinary levels with major branching evolutions. An evolution can change the tower’s role and appearance, and sometimes its footprint. Buying individual upgrades is the chosen system; duplicate merging is outside the current plan.

== Gambling has several risk levels
Possible activities include paying for another bonus roll, wagering currency for a random reward, or risking a tower for a transformation. We want several kinds of gambling, but the exact activities, odds and losses are still open. These use game resources. No real-money gambling is planned.

#v(3mm)
#note([What survives a run], [Earn currency for random collection draws and permanent upgrades. Your collection unlocks more tower options and some lasting stat changes. Run-specific towers, bonuses and perks reset. How wins and losses affect the payout still needs a decision.])

#pagebreak()
#label[Decisions for us]
= What is still open

The direction above describes the planned game. The choices below still need discussion or playtesting.

== Commanders and maps
Commanders stay off the battlefield. Most defenses are physical structures, such as towers and other buildings. We want maps with meaningful mechanical differences. There are two possible ways to connect them to commanders:

#v(1mm)
#grid(columns: (1fr, 1fr), gutter: 6mm,
  block(inset: (left: 3mm), stroke: (left: 2pt + accent))[
    #block(below: 2mm)[*Commander-linked boards*]
    Your commander determines or changes parts of the board, such as special zones or expansion behavior.
  ],
  block(inset: (left: 3mm), stroke: (left: 2pt + rust))[
    #block(below: 2mm)[*Independent choices*]
    Choose a commander and map separately. Each has its own mechanics, allowing different combinations.
  ],
)
#v(3mm)
Matching starting boards with different player-built paths also remain possible. We have not chosen a final rule for board symmetry.

== The shape of a long run
The current preference is to keep the same maze and towers across rounds. That would let a defense develop over several encounters. This remains provisional.

Planning could use a fixed timer, a ready button that starts a short countdown for the other player, or a mixture. Neither the timing nor the number of waves per round is fixed. The earlier examples of 30 path tiles and a 30-second countdown were suggestions.

== What needs concrete rules next
#grid(columns: (1fr, 1fr), gutter: 6mm,
  [
    *Economy and progression*
    #v(1.5mm)
    Starting funds, income growth, sale refunds and permanent stat advantages need limits. Early luck or collection strength should be considered when balancing a match.
  ],
  [
    *Abilities and content*
    #v(1.5mm)
    We need tower branches, enemy counters and actual spells. Offensive abilities need readable effects and rules for how the opponent can respond.
  ],
)

#v(4mm)
#note([Where the project stands], [We are building this with AI assistance in Godot, using GDScript. One player hosting the match is the proposed networking model; connection details remain open. A local path workshop now supports tile editing, budget checks, and shortest-route previews. Combat and multiplayer are not implemented.])
#v(3mm)
#text(size: 9.5pt)[*First playable:* connect two boards with one tower type and one enemy type. Prove the path rules, live building and upgrades, selling, income from sends, and base defeat before adding the collection and larger content roster.]
#v(2mm)
#small[Source: docs/game-direction.md. The full match design remains planned; only the local path workshop is implemented.]
