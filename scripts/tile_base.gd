# tile_base.gd
extends Node3D
class_name MazeTile

var materials_manager: GameMaterialsManager
var connections = {
	"north": false,
	"south": false, 
	"east": false,
	"west": false,
	"up": false,
	"down": false
}

func _ready():
	# Ждем немного чтобы MaterialsManager успел инициализироваться
	await get_tree().create_timer(0.1).timeout
	_setup_materials_manager()

func _setup_materials_manager():
	# Пытаемся найти MaterialsManager разными способами
	materials_manager = get_node_or_null("/root/MaterialsManager")
	
	if not materials_manager:
		# Пробуем через автозагрузку
		materials_manager = get_node_or_null("/root/Main/MaterialsManager")
	
	if not materials_manager:
		print("ОШИБКА: MaterialsManager не найден! Создаем временный.")
		# Создаем временный менеджер
		materials_manager = GameMaterialsManager.new()
		# Принудительно загружаем текстуры
		if materials_manager.has_method("load_textures"):
			materials_manager.load_textures()

func setup_tile(north: bool, south: bool, east: bool, west: bool, up: bool, down: bool):
	connections["north"] = north
	connections["south"] = south
	connections["east"] = east
	connections["west"] = west
	connections["up"] = up
	connections["down"] = down
	
	# Ждем инициализации менеджера материалов
	if not materials_manager:
		await _setup_materials_manager()
	
	create_visuals()
	setup_collision()

func create_visuals():
	# Очищаем старые меши
	for child in get_children():
		if child is MeshInstance3D or child is StaticBody3D:
			child.queue_free()
	
	# Создаем пол
	_create_floor()
	
	# Создаем стены
	_create_walls()

func _create_floor():
	var floor_mesh = BoxMesh.new()
	floor_mesh.size = Vector3(4, 0.2, 4)
	var floor_instance = MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.position = Vector3(0, -1, 0)
	
	var floor_material
	if materials_manager:
		floor_material = materials_manager.get_random_ground_material()
	else:
		floor_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color.DARK_GRAY
	
	floor_instance.material_override = floor_material
	add_child(floor_instance)

func _create_walls():
	if not connections["north"]:
		_create_wall(Vector3(0, 0, -2), 0, "north")
	if not connections["south"]:
		_create_wall(Vector3(0, 0, 2), 0, "south")
	if not connections["east"]:
		_create_wall(Vector3(2, 0, 0), 90, "east")
	if not connections["west"]:
		_create_wall(Vector3(-2, 0, 0), 90, "west")

func _create_wall(wall_position: Vector3, wall_rotation: float, _wall_name: String):
	var wall_mesh = BoxMesh.new()
	wall_mesh.size = Vector3(4, 2, 0.2)
	var wall_instance = MeshInstance3D.new()
	wall_instance.mesh = wall_mesh
	wall_instance.position = wall_position
	wall_instance.rotation_degrees.y = wall_rotation
	
	var wall_material
	if materials_manager:
		wall_material = materials_manager.get_random_wall_material()
	else:
		wall_material = StandardMaterial3D.new()
		wall_material.albedo_color = Color.LIGHT_GRAY
	
	wall_instance.material_override = wall_material
	add_child(wall_instance)

func setup_collision():
	var static_body = StaticBody3D.new()
	add_child(static_body)
	
	# Добавляем коллизии для всех MeshInstance3D
	for child in get_children():
		if child is MeshInstance3D:
			var collision = CollisionShape3D.new()
			collision.shape = child.mesh
			collision.position = child.position
			collision.rotation = child.rotation
			static_body.add_child(collision)
