# material_manager.gd
extends Node
class_name GameMaterialsManager

var ground_textures = []
var wall_textures = []

var material_cache = {}

func _ready():
	load_textures()

func load_textures():
	ground_textures = _load_textures_from_folder("res://textures/ground")
	wall_textures = _load_textures_from_folder("res://textures/wall")
	
	if ground_textures.is_empty() or wall_textures.is_empty():
		_create_fallback_textures()

func _load_textures_from_folder(folder_path: String) -> Array:
	var textures = []
	
	if not DirAccess.dir_exists_absolute(folder_path):
		return textures
	
	var dir = DirAccess.open(folder_path)
	if not dir:
		return textures
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.to_lower().ends_with(".png") or file_name.to_lower().ends_with(".jpg"):
				var texture_path = folder_path + "/" + file_name
				var texture = load(texture_path)
				if texture and texture is Texture2D:
					textures.append(texture)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return textures

func _create_fallback_textures():
	var ground_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	ground_image.fill(Color(0.2, 0.4, 0.2))
	var ground_texture = ImageTexture.create_from_image(ground_image)
	ground_textures.append(ground_texture)
	
	var wall_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	wall_image.fill(Color(0.3, 0.3, 0.3))
	var wall_texture = ImageTexture.create_from_image(wall_image)
	wall_textures.append(wall_texture)

func get_random_ground_material() -> StandardMaterial3D:
	var texture = _get_random_texture(ground_textures)
	return create_material_with_texture(texture)

func get_random_wall_material() -> StandardMaterial3D:
	var texture = _get_random_texture(wall_textures)
	return create_material_with_texture(texture)

func create_material_with_texture(texture: Texture2D) -> StandardMaterial3D:
	if texture == null:
		var fallback = StandardMaterial3D.new()
		fallback.albedo_color = Color(0.5, 0.5, 0.5)
		return fallback
	
	var key = str(texture.get_rid())
	if material_cache.has(key):
		return material_cache[key].duplicate()
	
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	material_cache[key] = material
	return material.duplicate()

func _get_random_texture(texture_array: Array) -> Texture2D:
	if texture_array.is_empty():
		return null
	return texture_array[randi() % texture_array.size()]
