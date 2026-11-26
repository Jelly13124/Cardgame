extends SceneTree

## Renders tools/svg_icons/svg/*.svg into the PNG targets in manifest.json, using
## Godot's own SVG renderer (ThorVG, the same one the importer uses). Each icon is
## scaled to fit the target size and centred, so layouts keep their dimensions.
## Usage: godot --headless --path . --script res://tools/svg_icons/rasterize.gd [-- --preview <dir>]
## With --preview, PNGs go to <dir>/<target file name> instead of the game paths.

const SVG_DIR := "res://tools/svg_icons/svg/"
const MANIFEST := "res://tools/svg_icons/manifest.json"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var preview_dir := ""
	var i := args.find("--preview")
	if i >= 0 and i + 1 < args.size():
		preview_dir = args[i + 1]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var count := 0
	for icon_name in manifest:
		var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(SVG_DIR + icon_name + ".svg"))
		if text.is_empty():
			push_error("missing svg: %s" % icon_name)
			continue
		for target in manifest[icon_name]:
			var w := int(target[1])
			var h := int(target[2])
			var trim: bool = target.size() > 3 and str(target[3]) == "trim"
			var side := mini(w, h)
			var img := Image.new()
			if img.load_svg_from_string(text, side / 64.0 * (3.0 if trim else 1.0)) != OK:
				push_error("svg failed: %s" % icon_name)
				continue
			if trim:  # crop the empty margin, then fit inside the target (2 px pad)
				img = img.get_region(img.get_used_rect())
				var k := minf((w - 4.0) / img.get_width(), (h - 4.0) / img.get_height())
				img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
			var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
			out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((w - img.get_width()) / 2, (h - img.get_height()) / 2))
			var path := ProjectSettings.globalize_path(str(target[0]))
			if preview_dir != "":
				path = preview_dir.path_join("%s__%s" % [icon_name, str(target[0]).get_file()])
			out.save_png(path)
			count += 1
	print("rasterized %d" % count)
	quit()
