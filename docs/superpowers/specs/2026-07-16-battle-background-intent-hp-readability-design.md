# Battle Background, Intent, and HP Readability Design

Date: 2026-07-16

## Goal

Reduce visual competition in battle, align enemy intent presentation with the Slay the Spire 2 model selected by the user, and restore a clear size hierarchy between HP bars and their numeric labels. Preserve all combat rules, encounter balance, character placement, cards, energy, block arithmetic, and the approved battle controls.

## Approved direction

Use option B for enemy intents: follow the STS2 category-based intent language. A debuff action uses the generic debuff/down-arrow intent rather than a status-specific Bleed, Weak, Frail, or Vulnerable icon. The exact status and amount appear only in the existing hover tooltip.

The three changes are one readability pass:

1. Replace the current detailed battlefield with a deliberately quiet battle background derived from the map background's negative-space logic.
2. Replace persistent intent words with compact category icons and numbers; multi-part actions display separate icons side by side.
3. Enlarge HP bars and reduce their numeral scale so the bar remains the primary shape.

## 1. Quiet battle background

### Composition

- Generate one new 1920x1080 opaque background in the project's clean 2D American-comic style.
- Use pale dusty beige and warm gray with low saturation and restrained contrast.
- Keep approximately 80% of the central combat area visually quiet.
- Confine the strongest linework and small environmental marks to the lowest 12–15% and far left/right edges.
- Use only faint, flat horizon silhouettes in the middle distance. No central landmark or dramatic focal point.
- The player and enemy lanes must remain readable at a glance without needing an extra dark overlay.

### Exclusions

- No foreground pipes, utility poles, giant cacti, skulls, characters, text, UI, or encounter props.
- No strong black outlines across the center, bright sun, dramatic cloud mass, glow, or high-frequency ground cracks.
- Do not reuse the current detailed desert vista as a composited layer.

### Runtime

- Save the approved asset as `battle_scene/assets/images/backgrounds/wasteland_battlefield_quiet_v3.png`.
- Replace only the battle scene background resource path.
- Keep the existing `TextureRect` behavior, viewport scaling, combatant anchors, and foreground UI positions unchanged.

## 2. STS2-style category intent system

### Always-visible information

- Basic attack: attack/sword icon plus final incoming damage number.
- Multi-hit attack: attack/sword icon plus the existing compact multi-hit number format.
- Block: block icon plus block amount.
- Heal: healing category icon plus amount.
- Buff: buff category icon; include a number only when it is necessary to communicate magnitude.
- Charge/summon/special setup: their category icons, with no persistent action name.
- Debuff: generic red debuff/down-arrow category icon, regardless of whether the underlying effect is Bleed, Weak, Frail, or Vulnerable.

### Multi-part actions

- An action that attacks and applies a debuff displays two intent cells side by side: `attack + damage` and `generic debuff`.
- Do not merge damage and debuff into a sentence or one long badge.
- Multiple intent cells share one compact horizontal group and animate as a unit when the action changes.

### Text and hover behavior

- Remove all persistent intent words, including `Bleed`, `Weak`, `Frail`, `Vulnerable`, `Block`, `Buff`, and action names.
- Damage, hit count, block amount, and other necessary quantities remain visible as numerals.
- The existing global tooltip remains the sole detailed explanation surface.
- Hovering any cell in the same action group opens the full action description, including concrete status name, stack amount, damage, hit count, and timing.
- Outside hover, the player sees category icons and required numerals only.

### Compatibility

- Do not change enemy JSON, action selection, damage calculation, status application, or intent timing.
- Existing enemies using `attack_status` continue to behave identically; only their presentation becomes a two-cell attack-plus-debuff intent.
- Reuse the existing attack, block, buff, and charge art where it remains legible. Add one project-style generic debuff icon only if no suitable asset exists.

## 3. HP bar hierarchy

### Runtime sizes

- Player: `184x28`.
- Normal enemy: `160x26`.
- Elite enemy: `184x28`.
- Boss: `216x30`.

These tiers keep the existing relative hierarchy while making the generated track and fill visibly substantial at 1080p.

### Numerals and layers

- Use 14–15 px HP numerals, centered over the bar.
- Compute the font size from bar height with a narrow clamp, approximately `bar_height * 0.52`, clamped to 13–15 px.
- Preserve Kreon Bold, a restrained two-pixel outline, the generated track/fill textures, delayed-loss layer, and current HP animation timing.
- The red fill should remain visually taller and heavier than the digits; digits must not extend beyond the illustrated track silhouette.
- Keep block as the existing lightweight cyan badge and preserve its overlap relationship with the left edge of the HP bar.

## Interaction and layout boundaries

- No changes to top bar, cards, energy, end-turn button, draw/discard piles, character sprites, enemy placement, combat effects, or map scene.
- No new permanent labels or panels.
- No balance or content changes.

## Verification

- Update the HUD contract test first so it fails against the current background path, current HP sizes, oversized numeral formula, and single-label intent layout.
- Add coverage proving an `attack_status` action creates two visible intent cells while showing no persistent status word.
- Add coverage proving the generic debuff cell is used for Bleed, Weak, Frail, and Vulnerable actions while the hover tooltip retains the concrete status name.
- Verify basic attack, multi-hit, block, buff, heal, charge, and summon fallbacks.
- Run the complete nonvisual Godot test suite.
- Capture a real 1920x1080 Windows/OpenGL battle showing partial player HP, an enemy attack-plus-debuff intent, and the new background.
- Inspect the capture for central contrast, HP numeral-to-bar hierarchy, intent spacing, and tooltip-only status text.
- Run `git diff --check`.

## Acceptance criteria

- The combat area reads as quiet negative space rather than an illustrated focal scene.
- No intent action name or status name is visible before hover.
- An attack that applies Bleed shows attack damage plus the generic debuff intent, not a Bleed icon.
- Hover still identifies Bleed and its amount correctly.
- HP bars are visibly larger than the numerals and retain distinct player, normal, elite, and boss size tiers.
- Combat values and enemy behavior are unchanged.
