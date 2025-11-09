# passage_generator.gd
extends Node

# Ссылка на менеджер материалов
var materials_manager: GameMaterialsManager

# Размер сетки лабиринта (должен совпадать с WFC)
var grid_size: Vector3i

# Позиции входа и выхода
var entrance_position: Vector3
var exit_position: Vector3
var entrance_direction: String
var exit_direction: String

# Веса для A* алгоритма
var tile_weights = {}
var astar: AStar3D
var path_positions: Array[Vector3i] = []

func _ready():
	# Ждем инициализации сцены
	_setup_materials_manager()
	await get_tree().create_timer(2.0).timeout  # Даем время на создание всех тайлов
	generate_external_walls()
	await get_tree().create_timer(2.0).timeout
	create_entrance_and_exit()
	assign_tile_weights()
	await get_tree().create_timer(2.0).timeout
	create_path_between_entrance_exit()

func _setup_materials_manager():
	"""Находим менеджер материалов разными способами"""
	materials_manager = get_node_or_null("/root/MaterialsManager")
	
	if not materials_manager:
		materials_manager = get_node_or_null("/root/Main/MaterialsManager")
	
	if not materials_manager:
		print("Предупреждение: MaterialsManager не найден в passage_generator")
		# Создаем временный менеджер
		materials_manager = GameMaterialsManager.new()
		if materials_manager.has_method("load_textures"):
			materials_manager.load_textures()

func generate_external_walls():
	"""Генерирует внешние стены вокруг лабиринта только для проходов наружу"""
	print("=== ГЕНЕРАЦИЯ ВНЕШНИХ СТЕН ===")
	
	# Получаем родительский узел WFC
	var wfc_node = get_parent()
	if not wfc_node or not wfc_node is WaveFunctionCollapse3D:
		print("Ошибка: Не найден родительский узел WFC")
		return
	
	# Получаем размер сетки из WFC
	grid_size = wfc_node.grid_size
	print("Размер лабиринта: ", grid_size)
	
	var external_walls_container = Node3D.new()
	external_walls_container.name = "ExternalWalls"
	wfc_node.add_child(external_walls_container)
	
	var walls_created = 0
	
	# Проходим по всем граничным позициям
	for x in range(grid_size.x):
		for z in range(grid_size.z):
			var grid_pos = Vector3i(x, 0, z)
			
			# Проверяем, нужны ли внешние стены для этой позиции
			var needed_walls = _check_needed_external_walls(grid_pos)
			
			# Создаем только необходимые стены
			if needed_walls["north"]:
				_create_external_wall(Vector3(x * 4, 0, z * 4 - 2), 0, "north", external_walls_container)
				walls_created += 1
			
			if needed_walls["south"]:
				_create_external_wall(Vector3(x * 4, 0, z * 4 + 2), 0, "south", external_walls_container)
				walls_created += 1
			
			if needed_walls["west"]:
				_create_external_wall(Vector3(x * 4 - 2, 0, z * 4), 90, "west", external_walls_container)
				walls_created += 1
			
			if needed_walls["east"]:
				_create_external_wall(Vector3(x * 4 + 2, 0, z * 4), 90, "east", external_walls_container)
				walls_created += 1
	
	print("Создано внешних стен: ", walls_created)
	
	# Добавляем коллизии для всех созданных стен
	_setup_external_collisions(external_walls_container)

func create_entrance_and_exit():
	"""Создает вход и выход в лабиринте"""
	print("=== СОЗДАНИЕ ВХОДА И ВЫХОДА ===")
	
	var directions = ["north", "south", "east", "west"]
	
	# 1. Выбираем случайное направление для входа
	entrance_direction = directions[randi() % directions.size()]
	print("Направление входа: ", entrance_direction)
	
	# 2. Определяем противоположное направление для выхода
	exit_direction = _get_opposite_direction(entrance_direction)
	print("Направление выхода: ", exit_direction)
	
	# 3. Выбираем позиции для входа и выхода
	var entrance_pos = _select_entrance_position(entrance_direction)
	var exit_pos = _select_exit_position(exit_direction)
	
	if entrance_pos == null or exit_pos == null:
		print("Ошибка: Не удалось выбрать позиции для входа/выхода")
		return
	
	entrance_position = Vector3(entrance_pos.x * 4, 0, entrance_pos.z * 4)
	exit_position = Vector3(exit_pos.x * 4, 0, exit_pos.z * 4)
	
	# 4. Удаляем стены на месте входа и выхода
	_remove_wall_at_entrance(entrance_pos, entrance_direction)
	_remove_wall_at_exit(exit_pos, exit_direction)
	
	# 5. Создаем маркеры
	_create_entrance_marker(entrance_pos, entrance_direction)
	_create_exit_marker(exit_pos, exit_direction)
	
	print("Вход создан: ", entrance_pos, " (", entrance_direction, ")")
	print("Выход создан: ", exit_pos, " (", exit_direction, ")")

func _get_opposite_direction(direction: String) -> String:
	"""Возвращает противоположное направление"""
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
	return "north"

func _select_entrance_position(direction: String) -> Vector3i:
	"""Выбирает позицию для входа на указанной стороне"""
	match direction:
		"north":
			var x = randi() % grid_size.x
			return Vector3i(x, 0, 0)
		"south":
			var x = randi() % grid_size.x
			return Vector3i(x, 0, grid_size.z - 1)
		"east":
			var z = randi() % grid_size.z
			return Vector3i(grid_size.x - 1, 0, z)
		"west":
			var z = randi() % grid_size.z
			return Vector3i(0, 0, z)
	return Vector3i(0, 0, 0)

func _select_exit_position(direction: String) -> Vector3i:
	"""Выбирает позицию для выхода на противоположной стороне"""
	return _select_entrance_position(direction)

func _remove_wall_at_entrance(grid_pos: Vector3i, direction: String):
	"""Удаляет внешнюю стену на месте входа"""
	_remove_external_wall(grid_pos, direction, "entrance")

func _remove_wall_at_exit(grid_pos: Vector3i, direction: String):
	"""Удаляет внешнюю стену на месте выхода"""
	_remove_external_wall(grid_pos, direction, "exit")

func _remove_external_wall(grid_pos: Vector3i, direction: String, type: String):
	"""Удаляет стену на месте входа/выхода (как внешнюю, так и у тайла)"""
	var wfc_node = get_parent()
	if not wfc_node:
		return
	
	# 1. Сначала пытаемся удалить внешнюю стену (из нашего контейнера)
	var walls_container = wfc_node.get_node_or_null("ExternalWalls")
	if walls_container:
		var search_center = Vector3()
		
		match direction:
			"north":
				search_center = Vector3(grid_pos.x * 4, 0, grid_pos.z * 4 - 2)
			"south":
				search_center = Vector3(grid_pos.x * 4, 0, grid_pos.z * 4 + 2)
			"east":
				search_center = Vector3(grid_pos.x * 4 + 2, 0, grid_pos.z * 4)
			"west":
				search_center = Vector3(grid_pos.x * 4 - 2, 0, grid_pos.z * 4)
		
		# Ищем и удаляем внешнюю стену
		for wall in walls_container.get_children():
			if wall is MeshInstance3D and wall.position.distance_to(search_center) < 1.0:
				print("Удалена внешняя стена для ", type)
				wall.queue_free()
				break
	
	# 2. Удаляем стену у самого тайла (это главное!)
	var tile = _get_tile_at_position(grid_pos)
	if tile:
		_remove_tile_wall(tile, direction, type)

func _remove_tile_wall(tile: MazeTile, direction: String, type: String):
	"""Удаляет стену у конкретного тайла"""
	print("Удаляем стену у тайла для ", type, " направление ", direction)
	
	var wall_found = false
	
	# Ищем все MeshInstance3D у этого тайла
	for child in tile.get_children():
		if child is MeshInstance3D:
			var wall_position = child.position
			var is_wall_in_direction = false
			
			# Проверяем, находится ли эта стена в нужном направлении
			match direction:
				"north":
					is_wall_in_direction = (abs(wall_position.z - (-2)) < 0.1 and abs(wall_position.x) < 0.1)
				"south":
					is_wall_in_direction = (abs(wall_position.z - 2) < 0.1 and abs(wall_position.x) < 0.1)
				"east":
					is_wall_in_direction = (abs(wall_position.x - 2) < 0.1 and abs(wall_position.z) < 0.1)
				"west":
					is_wall_in_direction = (abs(wall_position.x - (-2)) < 0.1 and abs(wall_position.z) < 0.1)
			
			if is_wall_in_direction:
				print("Найдена и удалена стена тайла: ", child.name, " позиция: ", child.position)
				child.queue_free()
				wall_found = true
				
				# Также удаляем коллизию если есть
				_remove_tile_collision(tile, direction)
				break
	
	if not wall_found:
		print("Стена не найдена в направлении ", direction, " - возможно уже удалена")

func _remove_tile_collision(tile: MazeTile, direction: String):
	"""Удаляет коллизию у тайла в указанном направлении"""
	# Ищем StaticBody3D у тайла
	for child in tile.get_children():
		if child is StaticBody3D:
			# Ищем CollisionShape3D в этом направлении
			for collision in child.get_children():
				if collision is CollisionShape3D:
					var collision_position = collision.position
					var is_collision_in_direction = false
					
					match direction:
						"north":
							is_collision_in_direction = (abs(collision_position.z - (-2)) < 0.1)
						"south":
							is_collision_in_direction = (abs(collision_position.z - 2) < 0.1)
						"east":
							is_collision_in_direction = (abs(collision_position.x - 2) < 0.1)
						"west":
							is_collision_in_direction = (abs(collision_position.x - (-2)) < 0.1)
					
					if is_collision_in_direction:
						print("Удалена коллизия тайла в направлении ", direction)
						collision.queue_free()
						break

func _create_entrance_marker(grid_pos: Vector3i, direction: String):
	"""Создает маркер входа"""
	var marker_position = Vector3(grid_pos.x * 4, 0.5, grid_pos.z * 4)
	_create_marker(marker_position, Color.GREEN, "Entrance", direction)

func _create_exit_marker(grid_pos: Vector3i, direction: String):
	"""Создает маркер выхода"""
	var marker_position = Vector3(grid_pos.x * 4, 0.5, grid_pos.z * 4)
	_create_marker(marker_position, Color.RED, "Exit", direction)

func _create_marker(position: Vector3, color: Color, type: String, direction: String):
	"""Создает визуальный маркер"""
	var wfc_node = get_parent()
	if not wfc_node:
		return
	
	# Создаем цилиндр как маркер
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.3
	cylinder_mesh.bottom_radius = 0.3
	cylinder_mesh.height = 0.2
	
	var marker = MeshInstance3D.new()
	marker.name = type + "_Marker_" + direction
	marker.mesh = cylinder_mesh
	marker.position = position
	
	# Создаем материал с цветом
	var marker_material = StandardMaterial3D.new()
	marker_material.albedo_color = color
	marker_material.emission = color * 0.5
	marker_material.emission_enabled = true
	marker.material_override = marker_material
	
	wfc_node.add_child(marker)
	
	# Добавляем источник света для лучшей видимости
	var light = OmniLight3D.new()
	light.name = type + "_Light_" + direction
	light.position = position + Vector3(0, 1, 0)
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 3.0
	wfc_node.add_child(light)
	
	print("Создан маркер ", type, " в позиции ", position)

func _check_needed_external_walls(grid_pos: Vector3i) -> Dictionary:
	"""
	Проверяет, какие внешние стены нужны для позиции
	Возвращает направления, где нужно создать внешние стены
	"""
	var needed_walls = {
		"north": false,
		"south": false,
		"east": false,
		"west": false
	}
	
	# Проверяем границы
	var is_north_edge = (grid_pos.z == 0)
	var is_south_edge = (grid_pos.z == grid_size.z - 1)
	var is_west_edge = (grid_pos.x == 0)
	var is_east_edge = (grid_pos.x == grid_size.x - 1)
	
	# Если не на границе - не нужны внешние стены
	if not (is_north_edge or is_south_edge or is_west_edge or is_east_edge):
		return needed_walls
	
	# Получаем тайл в этой позиции
	var tile = _get_tile_at_position(grid_pos)
	
	if not tile:
		print("Тайл не найден в позиции: ", grid_pos)
		return needed_walls
	
	# Проверяем соединения тайла
	var tile_connections = tile.connections
	
	# ВАЖНО: внешняя стена нужна там, где у тайла ЕСТЬ проход наружу (connection = true)
	# но при этом это граница лабиринта
	
	if is_north_edge and tile_connections.get("north", false):
		print("  -> Нужна северная внешняя стена (есть проход)")
		needed_walls["north"] = true
	
	if is_south_edge and tile_connections.get("south", false):
		print("  -> Нужна южная внешняя стена (есть проход)")
		needed_walls["south"] = true
	
	if is_west_edge and tile_connections.get("west", false):
		print("  -> Нужна западная внешняя стена (есть проход)")
		needed_walls["west"] = true
	
	if is_east_edge and tile_connections.get("east", false):
		print("  -> Нужна восточная внешняя стена (есть проход)")
		needed_walls["east"] = true
	
	return needed_walls

func _get_tile_at_position(grid_pos: Vector3i) -> MazeTile:
	"""Находит тайл MazeTile в заданной позиции сетки"""
	var wfc_node = get_parent()
	if not wfc_node:
		return null
	
	# Вычисляем ожидаемую позицию тайла в мировых координатах
	var expected_position = Vector3(grid_pos.x * 4, grid_pos.y * 4, grid_pos.z * 4)
	
	# Ищем среди дочерних узлов
	for child in wfc_node.get_children():
		if child is MazeTile:
			# Сравниваем позиции с допуском (из-за floating point ошибок)
			if child.position.distance_to(expected_position) < 0.1:
				return child
	
	return null

func _create_external_wall(wall_position: Vector3, wall_rotation: float, _wall_name: String, parent: Node):
	"""Создает визуальную внешнюю стену"""
	var wall_mesh = BoxMesh.new()
	wall_mesh.size = Vector3(4, 2, 0.2)
	
	var wall_instance = MeshInstance3D.new()
	wall_instance.name = "ExternalWall_" + _wall_name
	wall_instance.mesh = wall_mesh
	wall_instance.position = wall_position
	wall_instance.rotation_degrees.y = wall_rotation
	
	# Получаем материал из менеджера
	var wall_material
	if materials_manager:
		wall_material = materials_manager.get_random_wall_material()
	else:
		# Fallback материал
		wall_material = StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.3, 0.3, 0.4)  # Темно-серый для внешних стен
		wall_material.metallic = 0.1
		wall_material.roughness = 0.8
	
	wall_instance.material_override = wall_material
	parent.add_child(wall_instance)
	
func _setup_external_collisions(walls_container: Node3D):
	"""Добавляет коллизии для всех внешних стен"""
	var static_body = StaticBody3D.new()
	static_body.name = "ExternalWallsCollisions"
	walls_container.add_child(static_body)
	
	# Добавляем коллизии для каждой стены
	for wall in walls_container.get_children():
		if wall is MeshInstance3D and wall != static_body:
			var collision = CollisionShape3D.new()
			collision.shape = wall.mesh
			collision.position = wall.position
			collision.rotation = wall.rotation
			static_body.add_child(collision)
	
	print("Добавлены коллизии для внешних стен")

func assign_tile_weights():
	"""Назначает случайные веса всем тайлам для A* алгоритма"""
	print("=== НАЗНАЧЕНИЕ ВЕСОВ ТАЙЛАМ ===")
	
	var wfc_node = get_parent()
	if not wfc_node:
		return
	
	tile_weights.clear()
	
	# Проходим по всем тайлам
	for child in wfc_node.get_children():
		if child is MazeTile:
			var grid_pos = _world_to_grid_position(child.position)
			var weight = _calculate_tile_weight(child)
			# Сохраняем вес
			tile_weights[_grid_pos_to_key(grid_pos)] = weight
			# Выводим в консоль
			print("Тайл ", grid_pos, " - вес: ", str(round(weight * 10) / 10.0))
	print("Назначены веса для ", tile_weights.size(), " тайлов")

func _calculate_tile_weight(tile: MazeTile) -> float:
	var grid_pos = _world_to_grid_position(tile.position)
	
	var entrance_pos = _world_to_grid_position(entrance_position)
	var exit_pos = _world_to_grid_position(exit_position)
	
	# Прямая линия между входом и выходом
	var direct_path_center = (entrance_pos + exit_pos) / 2.0
	var direct_path_radius = entrance_pos.distance_to(exit_pos) / 2.0
	
	# Расстояние до прямой линии между входом и выходом
	var dist_to_direct = _distance_to_line_segment(
		Vector2(grid_pos.x, grid_pos.z),
		Vector2(entrance_pos.x, entrance_pos.z),
		Vector2(exit_pos.x, exit_pos.z)
	)
	
	# ШИРОКИЙ барьер вокруг прямой линии
	if dist_to_direct < direct_path_radius * 0.8:  # 80% ширины - барьер
		return 800.0 + randf_range(1, 100)
	
	# За пределами барьера - обычные веса, но с градиентом
	var center_x = grid_size.x / 2.0
	var center_z = grid_size.z / 2.0
	var dist_to_center = Vector2(grid_pos.x - center_x, grid_pos.z - center_z).length()
	
	return dist_to_center * 1.5 + randf_range(1, 15)

func _distance_to_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_length_squared = line_vec.length_squared()
	
	if line_length_squared == 0:
		return point_vec.length()
	
	var t = point_vec.dot(line_vec) / line_length_squared
	t = clamp(t, 0.0, 1.0)
	
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

func get_tile_weight(grid_pos: Vector3i) -> float:
	"""Возвращает вес тайла в указанной позиции"""
	var key = _grid_pos_to_key(grid_pos)
	return tile_weights.get(key, 1.0)  # По умолчанию вес 1.0

func get_all_tile_weights() -> Dictionary:
	"""Возвращает все веса тайлов"""
	return tile_weights.duplicate()

func _world_to_grid_position(world_pos: Vector3) -> Vector3i:
	"""Конвертирует мировые координаты в сеточные"""
	return Vector3i(
		int(round(world_pos.x / 4.0)),
		int(round(world_pos.y / 4.0)),
		int(round(world_pos.z / 4.0))
	)

func _grid_pos_to_key(grid_pos: Vector3i) -> String:
	"""Конвертирует Vector3i в строковый ключ"""
	return str(grid_pos.x) + "," + str(grid_pos.y) + "," + str(grid_pos.z)

func create_path_between_entrance_exit():
	"""Создает путь между входом и выходом используя A*"""
	print("=== СОЗДАНИЕ ПУТИ МЕЖДУ ВХОДОМ И ВЫХОДОМ ===")
	
	# Получаем позиции входа и выхода в координатах сетки
	var entrance_grid_pos = _world_to_grid_position(entrance_position)
	var exit_grid_pos = _world_to_grid_position(exit_position)
	
	print("Поиск пути от: ", entrance_grid_pos, " до: ", exit_grid_pos)
	
	# Строим граф A*
	build_astar_graph()
	
	# Ищем путь
	var path = find_astar_path(entrance_grid_pos, exit_grid_pos)
	
	if path.is_empty():
		print("Ошибка: путь не найден!")
		return
	
	print("Найден путь длиной: ", path.size())
	path_positions = path
	
	# Создаем проход вдоль пути
	create_passage_along_path(path)

func build_astar_graph():
	"""Строит граф для A* алгоритма на основе тайлов лабиринта"""
	astar = AStar3D.new()
	
	var wfc_node = get_parent()
	if not wfc_node:
		return
	
	# Добавляем все доступные точки
	for child in wfc_node.get_children():
		if child is MazeTile:
			var grid_pos = _world_to_grid_position(child.position)
			var point_id = _grid_pos_to_id(grid_pos)
			var weight = get_tile_weight(grid_pos)  # Получаем вес тайла
			astar.add_point(point_id, Vector3(grid_pos.x, grid_pos.y, grid_pos.z), weight)
	
	# Соединяем точки на основе соединений тайлов
	for child in wfc_node.get_children():
		if child is MazeTile:
			var grid_pos = _world_to_grid_position(child.position)
			var current_id = _grid_pos_to_id(grid_pos)
			
			# Проверяем все возможные направления
			var directions = [
				Vector3i(1, 0, 0),   # восток
				Vector3i(-1, 0, 0),  # запад
				Vector3i(0, 0, 1),   # юг
				Vector3i(0, 0, -1)   # север
			]
			
			for direction in directions:
				var neighbor_pos = grid_pos + direction
				var neighbor_id = _grid_pos_to_id(neighbor_pos)
				
				# Если сосед существует и соединение возможно
				if astar.has_point(neighbor_id):
					# Получаем вес для стоимости перехода
					var neighbor_weight = get_tile_weight(neighbor_pos)
					
					# Соединяем точки (двунаправленно)
					if not astar.are_points_connected(current_id, neighbor_id):
						astar.connect_points(current_id, neighbor_id, true)
	
	print("Построен A* граф с ", astar.get_point_count(), " точками")

func find_astar_path(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	"""Находит путь используя A* алгоритм с учетом весов"""
	if not astar:
		return []
	
	var start_id = _grid_pos_to_id(start)
	var end_id = _grid_pos_to_id(end)
	
	if not astar.has_point(start_id) or not astar.has_point(end_id):
		print("Ошибка: начальная или конечная точка не найдена в графе")
		return []
	
	# Ищем путь
	var path_3d = astar.get_point_path(start_id, end_id)
	var path_grid: Array[Vector3i] = []
	
	for point in path_3d:
		path_grid.append(Vector3i(int(point.x), int(point.y), int(point.z)))
	
	return path_grid

func create_passage_along_path(path: Array[Vector3i]):
	"""Создает проход вдоль найденного пути, удаляя стены"""
	print("Создание прохода вдоль пути...")
	
	for i in range(path.size() - 1):
		var current_pos = path[i]
		var next_pos = path[i + 1]
		
		# Определяем направление к следующей точке
		var direction = _get_direction_between_points(current_pos, next_pos)
		
		if direction != "":
			# Удаляем стену в направлении движения
			_remove_wall_between_tiles(current_pos, direction)
			
			# Также удаляем стену в противоположном направлении у соседа
			var opposite_dir = _get_opposite_direction(direction)
			_remove_wall_between_tiles(next_pos, opposite_dir)
	
	print("Проход создан вдоль ", path.size(), " точек")

func _remove_wall_between_tiles(grid_pos: Vector3i, direction: String):
	"""Удаляет стену между двумя тайлами в указанном направлении"""
	var tile = _get_tile_at_position(grid_pos)
	if tile:
		_remove_tile_wall(tile, direction, "path")

func _get_direction_between_points(from: Vector3i, to: Vector3i) -> String:
	"""Определяет направление между двумя точками сетки"""
	var diff = to - from
	
	if diff == Vector3i(1, 0, 0):
		return "east"
	elif diff == Vector3i(-1, 0, 0):
		return "west"
	elif diff == Vector3i(0, 0, 1):
		return "south"
	elif diff == Vector3i(0, 0, -1):
		return "north"
	
	return ""

func _grid_pos_to_id(grid_pos: Vector3i) -> int:
	"""Конвертирует позицию сетки в ID для A*"""
	# Используем хэш функцию для создания уникального ID
	return (grid_pos.x * 1000000) + (grid_pos.y * 1000) + grid_pos.z
	
