extends RefCounted

## Where the hero and the enemies stand, by STS2's rules (NCombatRoom
## .PositionEnemies, the single-player branch of .PositionPlayersAndPets, and
## .AdjustCreatureScaleForAspectRatio). Each side lays out in its own half of
## the 1920x1080 scene, measured from the centre: creatures are centred in that
## half but kept at least 150 px from the middle, enemies 70 px apart (closer,
## and every other one raised, when crowded), feet 200 px below the centre. When
## the rightmost enemy would cross the screen edge, both sides shrink.

const SCENE_SIZE := Vector2(1920, 1080)
const CENTER := SCENE_SIZE * 0.5
const HALF_WIDTH := 960.0
const FEET_Y := 200.0
const MIN_FROM_CENTER := 150.0
const ENEMY_GAP := 70.0
const EDGE_PAD := 15.0


## The hero's feet, relative to the scene centre.
static func player_position(width: float) -> Vector2:
	var start := maxf((HALF_WIDTH - width) * 0.5, MIN_FROM_CENTER)
	return Vector2(-start - width * 0.5, FEET_Y)


## Each enemy's feet, relative to the scene centre, left to right.
static func enemy_positions(widths: Array) -> Array:
	var out: Array = []
	if widths.is_empty():
		return out
	var gap := ENEMY_GAP
	var total := 0.0
	for w in widths:
		total += float(w)
	var span := total + (widths.size() - 1) * gap
	var x := maxf((HALF_WIDTH - span) * 0.5, MIN_FROM_CENTER)
	var raise := 0.0
	if x + span > HALF_WIDTH and widths.size() > 1:
		gap = maxf((HALF_WIDTH - MIN_FROM_CENTER - total) / float(widths.size() - 1), 5.0)
		span = total + (widths.size() - 1) * gap
		x = (HALF_WIDTH - span) * 0.5
		if gap < 30.0:
			raise = lerpf(60.0, 40.0, (gap - 5.0) / 25.0)
	for i in widths.size():
		var w := float(widths[i])
		out.append(Vector2(x + w * 0.5, FEET_Y - (raise if i % 2 == 1 else 0.0)))
		x += w + gap
	return out


## Global feet positions and the shared creature scale:
## {player: Vector2, enemies: Array[Vector2], scale: float, enemy_origin: Vector2}.
## enemy_origin is where the enemy container goes (its children sit at their
## enemy_positions offsets, scaled by `scale`).
static func arrange(player_width: float, enemy_widths: Array) -> Dictionary:
	var hero := player_position(player_width)
	var foes := enemy_positions(enemy_widths)
	var right := CENTER.x + hero.x + player_width * 0.5
	for i in foes.size():
		right = maxf(right, CENTER.x + foes[i].x + float(enemy_widths[i]) * 0.5)
	right += EDGE_PAD
	var s := 1.0
	var origin := CENTER
	if right > SCENE_SIZE.x:
		s = SCENE_SIZE.x / right
		origin += Vector2.LEFT * (right - SCENE_SIZE.x) * s
	var globals: Array = []
	for p in foes:
		globals.append(origin + p * s)
	return {"player": CENTER + hero * s, "enemies": globals, "scale": s, "enemy_origin": origin}
