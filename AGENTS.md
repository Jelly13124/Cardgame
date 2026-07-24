# Agent Instructions

Before changing art or UI, read `docs/project-rules.md` and
`docs/art-style-reference.md`. Those files are the source of truth; this file is
the short operational gate for agents.

## Non-negotiable visual direction

- Use original, simple flat 2D American-comic sci-fi-western TV-cartoon art.
- Use a Rick-and-Morty-style adult sci-fi TV-cartoon visual language: confident
  wobbly outlines, rubbery but recognizable anatomy, off-kilter proportions,
  expressive comedy faces, flat cel colors, and controlled medium-low detail.
- Never copy franchise characters, props, locations, logos, or exact designs.
- Add a few purposeful dents, seams, patches, crooked joints, cables, expressive
  eye marks, and sparse alien background lines. Do not simplify into clean
  corporate vector art, preschool illustration, or generic children's-book art.
- Reject painterly concept art, realistic lighting, dense metal panels, rivets,
  scratches, hatching, grunge, tiny debris, material texture, and over-rendering.
- The current illustrations under `battle_scene/assets/images/cards/player/`
  are the approved collective card-art reference set. Compare several cards for
  line weight, color, composition variety, and detail level; do not turn one card
  into a template for every illustration. Follow the recurring majority look,
  not an isolated outlier or a card explicitly queued for rework.

## Enemy-art gate

- Read `docs/enemy-art-direction.md` before changing any non-boss enemy.
- Use `docs/art/external-references/rick-morty-s3e2-wasteland/reference-board.png`
  only as a study board for grounded nuclear-wasteland population design,
  silhouette variety, line treatment, and color separation. Never copy a
  character, costume, mask, prop, vehicle, location, or composition from it.
- Start from a recognizable humanoid, complete animal, or functional salvage
  machine. Reject random blobs, object-with-legs bodies, abstract capsules,
  half-human/half-animal designs, and arbitrary extra anatomy.
- Standard enemy attacks use four frames: frame 0 rest/wind-up, frame 1 prepare,
  frame 2 exactly one small local hit, frame 3 recoil/return. Do not generate a
  separate enemy idle loop by default. Keep the base planted and let runtime
  feedback provide impact weight.

## Card-art gate

- Output is a `512x320` landscape PNG with no text or UI baked in.
- Use one primary action, one clear subject and at most one target.
- Build the background from three-to-seven large flat shapes plus sparse alien marks.
- Small paired action accents such as one muzzle flash plus one impact star are allowed.
- If the image contains dense rocks, debris clouds, scratches, texture, hatching,
  realistic mechanical panel lines, or cinematic rendering, reject and regenerate.

## UI gate

- Use UI07: light borders, flat fills, sparse lines, and clear hierarchy.
- The shared `run_system/ui/run_top_bar.gd` is persistent on every in-run screen.
  Map, battle, event, rest, card-upgrade, deck, reward, and shop content begins
  below its full `BAR_HEIGHT`. Scene art may continue behind the transparent relic
  shelf from `PAGE_ART_TOP`; never hide, duplicate, or paint over the run top bar.
- Card previews show only the card normally. A close outline appears only for
  hover/focus/selection feedback and disappears when the state ends. Never ship a
  permanent decorative glow or a large empty holder around a card.
- Layout rhythm may reference another game, but do not copy its rendered materials,
  assets, fonts, or ornamental chrome.
