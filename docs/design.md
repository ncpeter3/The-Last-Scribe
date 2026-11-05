# Design notes

- **Premise:** In 2060 physical books are obsolete and digital copies are distrusted (corrupted by governments and bad actors). Scribes travel back to be eyewitnesses and record scripture faithfully. The Codex device translates, logs verses, and cannot change history.
- **Player:** male or female scribe (aide to each chapter's hero).
- **Scope:** every story, chronological, starting with Adam and Eve. Chapters are self-contained so they can ship one at a time.
- **Loop:** arrive, serve, act, reflect (see the shared design doc).
- **View:** top-down 3D (angled bird's-eye camera, free movement with a thumb joystick). Art is free CC0 low-poly 3D from Quaternius (see shared_assets/CREDITS.md), built by tools/art/.
- **Combat:** occasional, period weapons, no blood. Not every chapter has combat (Genesis 1-3 has none; it uses exploration and care-taking challenges instead).
- **Text:** KJV (public domain).
- **Monetization:** free for now.
- **Scribe role:** mostly an observer of the main story, but the world is open to explore and interact with (animals, plants, objects). In Adam and Eve there are no other characters to talk to until they have children.

## Opening: home in 2060

The game starts in the scribe's home the night they leave (`chapters/00_home/`). The family is
there: Mom (kitchen), Dad (living room window), Grandma (her armchair; she remembers paper Bibles)
and little brother Sam with Biscuit the dog. Each talk asks the scribe a question ("Are you sure?",
"Why the very beginning?", "Why you?") and every answer gets a loving, supportive reply; two
answers share a verse that goes into the Scroll Journal. Talking is optional, but if the scribe
walks up to the time machine in the garage without talking to anyone, it asks first. Whoever they
talked to comes to the garage to see them off, then Chapter 1 starts. Text: `data/home.json`.
`tools/test/home_playtest.tscn` plays it headless in CI.

## Chapter 1 challenges (Eden)

Each challenge starts right after the verse it teaches, and the next story beat waits until it
is done, so the story is never skipped or reordered. None can be failed: a wrong answer gets a
hint and another try. Data lives in `beats.json` (`challenge`, `after_lines`); code is in
`chapters/01_adam_and_eve/challenges/` on top of `core/challenges/challenge.gd`.

| After | Challenge | Teaches |
|---|---|---|
| Genesis 2:15-17 | Dress and keep the garden: fill a jar at the river, water thirsty plants | 2:15, 2:10 |
| Genesis 2:18-19 | Record every creature as cattle, fowl of the air, or beast of the field (walk up slowly or they startle) | 2:19-20 |
| Genesis 2:21-25 | Gather fruit from every tree but the forbidden one | 2:16-17 |
| Genesis 3:1-7 | None: the serpent scene is only watched | |
| Genesis 3:8-9 | Where art thou? Follow rustling leaves to where Adam and Eve hid | 3:8-13 |
| Genesis 3:21-23 | Scroll check: fill in missing words from recorded verses | review |

`tools/test/playtest.tscn` plays the whole chapter headless and runs in CI.
