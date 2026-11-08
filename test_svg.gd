extends SceneTree

func _init():
	var f = FileAccess.open("res://test_output.txt", FileAccess.WRITE)
	f.store_line("Checking crystal.svg: " + str(ResourceLoader.exists("res://assets/crystal.svg")))
	var img = Image.load_from_file("res://assets/crystal.svg")
	f.store_line("Loaded as image: " + str(img))
	if img:
		f.store_line("Image size: " + str(img.get_size()))
		var itex = ImageTexture.create_from_image(img)
		f.store_line("Created ImageTexture: " + str(itex))
	var tex = load("res://assets/crystal.svg")
	f.store_line("load() result: " + str(tex))
	f.close()
	quit()
