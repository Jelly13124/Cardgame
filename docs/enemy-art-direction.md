# Enemy Art Direction

**Status:** Active source of truth for non-boss enemy identity and attack art
**Reference board:** `docs/art/external-references/rick-morty-s3e2-wasteland/reference-board.png`
**Frame guide:** `docs/art/external-references/rick-morty-s3e2-wasteland/README.md`

## Direction

Enemies belong to a grounded nuclear-wasteland sci-fi western. The external
study frames establish the intended adult TV-cartoon linework, flat color
separation, body variety, costume economy, and comedic face acting. They are
reference-only: every production enemy must be an original design and may not
copy a visible character, costume, mask, vehicle, prop, location, or exact
composition.

The rejected July 24 batch is not a visual reference. Do not preserve its
randomized anatomy, object-with-legs bodies, floating abstract shapes, or
name-literal designs when rebuilding enemies.

## Population Mix

Use this as a roster-level target rather than a quota for every encounter:

- About half: recognizable humanoid wasteland survivors, raiders, mechanics,
  scavengers, guards, medics, prospectors, or cultists.
- About one quarter: recognizable mutated animals that still read immediately
  as a dog, rat, lizard, bird, insect, or other complete animal.
- About one quarter: simple functional salvage robots, drones, turrets, or
  devices with one obvious job.

Do not create human/animal hybrids such as pig people. A mutated animal stays an
animal; a humanoid stays humanoid. Aliens are allowed only when their anatomy is
coherent and their nuclear-wasteland survival story is obvious.

## Identity Rules

- Design from combat role and survival occupation, not from the current enemy
  name. The name is an asset-routing label, not an image prompt.
- Start from a stable, recognizable body category. Add at most one strong
  mutation, malfunction, prosthetic, or salvage-tech idea.
- Every humanoid enemy needs one immediately visible identity break from an
  ordinary present-day human. Prefer one controlled mutation (uneven eyes,
  abnormal skin color, one enlarged or elongated limb, crooked proportions)
  or conceal the face with one crude survival mask, bucket helmet, hood, or
  respirator. A plain uncovered human in generic workwear is not enough.
- Give each identity one readable silhouette, one dominant color family, and
  one small high-contrast accent.
- Show three or four large wasteland cues: a broad torn garment, crude mask or
  bucket helmet, tire rubber, car-body scrap, cloth wraps, respirator,
  improvised tool or weapon, radiation burn, faded hazard color, damaged
  utility pack, or shelter salvage. These cues must read as large silhouette or
  color-block decisions rather than a collection of small accessories.
- Comedy comes from expression, posture, proportions, social role, or a
  malfunction. It does not come from arbitrary extra limbs or grotesque body
  horror.
- Keep detail at medium-low density: broad flat fills, sparse seams, one broad
  shadow, and only the lines needed to explain the form. Do not simulate
  wasteland wear with rust speckles, scratch fields, rivet rows, layered
  straps, pouch clusters, or surface grime; the world identity must survive
  after all of that noise is removed.
- Enemies face left in combat and remain readable over the active battle
  background at gameplay scale.

## Reject

- Random floating blobs, abstract capsules, appliance bodies with legs, or
  unrelated objects combined only to appear strange.
- Half-human/half-animal bodies, grotesque mutations, excessive limbs, gore, or
  horror-first silhouettes.
- Handsome generic soldiers, polished fantasy armor, realistic military gear,
  dense hard-surface mechs, or high-detail rendered metal.
- Literal illustrations of an enemy's English name.
- Copies of any franchise character, costume, mask, prop, vehicle, location,
  or scene composition from the study frames.

## Attack Animation

Standard enemy attacks use four frames:

0. Rest or local wind-up.
1. The attacking part prepares while the base stays planted.
2. Exactly one small hit, bite, jab, shot, pulse, or bump.
3. Recoil or return toward the rest pose.

Keep the body translation small. Feet, wheels, treads, or the main base remain
stable. Do not add a full-frame charge, repeated strike, exaggerated jump,
large slash trail, dust cloud, or separate impact burst. Runtime flash, shake,
numbers, audio, and combat-feedback FX provide the weight.

Do not generate a separate enemy idle loop by default. Frame 0 is the production
rest pose unless a dedicated idle is explicitly requested and wired.

## Review Gate

Before replacing a production enemy, review its frame-zero identity against:

1. `reference-board.png` for grounded world fit and character readability;
2. neighboring enemies for silhouette and dominant-color separation;
3. the active battle background at gameplay scale;
4. the four-frame GIF for a single restrained attack beat.

If the identity reads as random sci-fi weirdness before it reads as a nuclear
wasteland person, animal, or functional machine, reject it.
