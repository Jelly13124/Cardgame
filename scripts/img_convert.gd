extends SceneTree

func _init():
	var args = OS.get_cmdline_args()
	# Godot adds its own args, we look for our marker "--"
	var custom_args = []
	var start = false
	for arg in args:
		if arg == "--":
			start = true
			continue
		if start:
			custom_args.append(arg)
	
	if custom_args.size() < 2:
		print("Usage: godot --headless -s img_convert.gd -- <src> <dest>")
		quit(1)
		return
		
	var src = custom_args[0]
	var dest = custom_args[1]
	
	var image = Image.load_from_file(src)
	if image == null:
		print("Error: Could not load image from ", src)
		quit(1)
		return
		
	var err = image.save_png(dest)
	if err != OK:
		print("Error saving PNG: ", err)
		quit(1)
		return
		
	print("Successfully converted ", src, " to ", dest)
	quit(0)
