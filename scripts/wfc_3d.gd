# wfc_3d.gd
extends Node3D
class_name WaveFunctionCollapse3D

# Размер лабиринта
@export var grid_size: Vector3i = Vector3i(16 , 1, 16)

# Ссылки на сцены тайлов
var tile_scenes = {
	"straight_ns": preload("res://scenes/tiles/Straight_ns.tscn"),
	"straight_ew": preload("res://scenes/tiles/Straight_ew.tscn"),
	"corner_ne": preload("res://scenes/tiles/Corner_ne.tscn"),
	"corner_nw": preload("res://scenes/tiles/Corner_nw.tscn"),
	"corner_se": preload("res://scenes/tiles/Corner_se.tscn"),
	"corner_sw": preload("res://scenes/tiles/Corner_sw.tscn"),
	"t_junction_n": preload("res://scenes/tiles/T_junction_n.tscn"),
	"t_junction_s": preload("res://scenes/tiles/T_junction_s.tscn"),
	"t_junction_e": preload("res://scenes/tiles/T_junction_e.tscn"),
	"t_junction_w": preload("res://scenes/tiles/T_junction_w.tscn"),
	"cross": preload("res://scenes/tiles/Cross.tscn"),
	"dead_end_n": preload("res://scenes/tiles/DeadEnd_n.tscn"),
	"dead_end_s": preload("res://scenes/tiles/DeadEnd_s.tscn"),
	"dead_end_e": preload("res://scenes/tiles/DeadEnd_e.tscn"),
	"dead_end_w": preload("res://scenes/tiles/DeadEnd_w.tscn"),
}

# Все возможные состояния тайлов (тип + ориентация)
var all_possible_states = []

var directions = ["north", "south", "east", "west"]
var direction_vectors = {
	"north": Vector3i(0, 0, -1),
	"south": Vector3i(0, 0, 1),
	"east": Vector3i(1, 0, 0),
	"west": Vector3i(-1, 0, 0)
}
var opposite_dirs = {
	"north": "south", "south": "north", 
	"east": "west", "west": "east"
}

# Матрица совместимости: compatible[state1][direction][state2] = true/false
var compatibility_matrix = []

var wave_function = []  # 3D массив массивов возможных состояний

# Добавляем флаг для отслеживания инициализации
var is_initialized = false

func _ready():
	# Откладываем инициализацию на следующий кадр
	call_deferred("initialize_wfc")

func initialize_wfc():
	"""Отложенная инициализация WFC"""
	print("Начинаем инициализацию WFC...")
	initialize_tile_states_from_scenes()

func initialize_tile_states_from_scenes():
	"""Создаем все возможные комбинации тайл+ориентация на основе сцен"""
	all_possible_states = []
	
	# Создаем временный узел для инстанциирования тайлов
	var temp_node = Node3D.new()
	call_deferred("add_child", temp_node)
	
	# Ждем пока узел добавится в сцену
	await get_tree().process_frame
	
	print("Начинаем анализ тайлов из сцен...")
	
	for tile_key in tile_scenes:
		var tile_scene = tile_scenes[tile_key]
		var tile_instance = tile_scene.instantiate()
		temp_node.add_child(tile_instance)
		
		# Ждем пока тайл полностью инициализируется
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Получаем компонент MazeTile
		var maze_tile = tile_instance
		if maze_tile and maze_tile is MazeTile:
			# Ждем пока connections установятся
			if maze_tile.connections.is_empty():
				await get_tree().create_timer(0.1).timeout
			
			var connections = maze_tile.connections
			var state_connections = [
				connections.get("north", false),
				connections.get("south", false), 
				connections.get("east", false),
				connections.get("west", false)
			]
			
			all_possible_states.append({
				"type": tile_key,
				"orientation": 0,  # Базовая ориентация
				"connections": state_connections
			})
			
			print("Добавлен тайл: ", tile_key, " - соединения: ", state_connections)
		
		# Удаляем инстанс
		tile_instance.queue_free()
		await get_tree().process_frame
	
	# Удаляем временный узел
	temp_node.queue_free()
	
	print("Создано состояний из сцен: ", all_possible_states.size())
	
	# Продолжаем инициализацию WFC
	initialize_compatibility_matrix()
	initialize_wave_function()
	collapse_wave_function()
	
	is_initialized = true

func initialize_compatibility_matrix():
	"""Создаем матрицу совместимости между всеми состояниями"""
	print("Инициализируем матрицу совместимости...")
	compatibility_matrix = []
	
	# Инициализируем матрицу
	for i in range(all_possible_states.size()):
		compatibility_matrix.append([])
		for direction in range(directions.size()):
			compatibility_matrix[i].append([])
			for j in range(all_possible_states.size()):
				compatibility_matrix[i][direction].append(false)
	
	# Заполняем совместимости - ИСПРАВЛЕННАЯ ЛОГИКА
	for i in range(all_possible_states.size()):
		var state1 = all_possible_states[i]
		for j in range(all_possible_states.size()):
			var state2 = all_possible_states[j]
			for dir_idx in range(directions.size()):
				var direction = directions[dir_idx]
				var opposite_dir = opposite_dirs[direction]
				var opposite_dir_idx = directions.find(opposite_dir)
				
				var state1_has_connection = state1["connections"][dir_idx]
				var state2_has_connection = state2["connections"][opposite_dir_idx]
				
				# ИСПРАВЛЕННАЯ ЛОГИКА:
				if state1_has_connection and state2_has_connection:
					# ОБА имеют соединения - ПРОХОДЫ совместимы 
					compatibility_matrix[i][dir_idx][j] = true
				elif not state1_has_connection and not state2_has_connection:
					# ОБА не имеют соединений - СТЕНЫ совместимы 
					compatibility_matrix[i][dir_idx][j] = true
				else:
					# Один имеет соединение, другой нет - НЕ совместимы 
					compatibility_matrix[i][dir_idx][j] = false
	
	print("Матрица совместимости создана")    

func initialize_wave_function():
	"""Инициализируем wave function - все состояния возможны везде"""
	print("Инициализируем wave function...")
	wave_function = []
	for x in range(grid_size.x):
		wave_function.append([])
		for y in range(grid_size.y):
			wave_function[x].append([])
			for z in range(grid_size.z):
				# Начинаем со всех возможных состояний
				wave_function[x][y].append(range(all_possible_states.size()).duplicate())
	
	print("Инициализировано ячеек: ", grid_size.x * grid_size.y * grid_size.z)

func collapse_wave_function():
	"""Основная функция коллапсирования волновой функции"""
	print("Начинаем коллапсирование волновой функции...")
	
	var iteration = 0
	var max_iterations = grid_size.x * grid_size.y * grid_size.z * 10
	
	# Пока есть неколлапсированные ячейки
	while not is_fully_collapsed() and iteration < max_iterations:
		iteration += 1
		
		# Находим ячейку с минимальной энтропией
		var target_cell = find_min_entropy_cell()

		# Коллапсируем ячейку
		if not collapse_cell(target_cell):
			print("Ошибка при коллапсе ячейки ", target_cell, " на итерации ", iteration)
			break
		
		# Распространяем изменения
		propagate_from(target_cell)
		
		# Вывод прогресса каждые 10 итераций
		if iteration % 10 == 0:
			print("Итерация ", iteration, " - коллапсирована ячейка ", target_cell)
	
	# Финальная диагностика
	print("Коллапсирование завершено за ", iteration, " итераций")
	
	# Создаем визуальное представление
	instantiate_maze()

func is_fully_collapsed():
	"""Проверяем, все ли ячейки коллапсировали (имеют ровно 1 состояние)"""
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			for z in range(grid_size.z):
				if wave_function[x][y][z].size() > 1:
					return false
	return true

func find_min_entropy_cell():
	"""
	Находим ячейку с минимальной энтропией (наименьшим количеством вариантов)
	Возвращает null если все ячейки коллапсированы
	"""
	var min_entropy = INF
	var candidates = []
	
	# Сначала ищем ячейки с минимальной ненулевой энтропией > 1
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			for z in range(grid_size.z):
				var entropy = wave_function[x][y][z].size()
				
				# Игнорируем уже коллапсированные ячейки (entropy == 1)
				# и ячейки без вариантов (entropy == 0)
				if entropy > 1:
					if entropy < min_entropy:
						min_entropy = entropy
						candidates = [Vector3i(x, y, z)]
					elif entropy == min_entropy:
						candidates.append(Vector3i(x, y, z))
	
	if candidates.is_empty():
		return null
	
	# Если есть несколько кандидатов с одинаковой энтропией - выбираем случайный
	return candidates[randi() % candidates.size()]

func collapse_cell(cell_pos: Vector3i):
	"""Коллапсируем ячейку - выбираем случайное состояние из возможных"""
	var possibilities = wave_function[cell_pos.x][cell_pos.y][cell_pos.z]
	
	if possibilities.size() == 1:
		# Ячейка уже коллапсирована
		return true
	
	# Взвешенный случайный выбор (можно добавить разные веса для разных типов тайлов)
	var random_index = randi() % possibilities.size()
	var chosen_state = possibilities[random_index]
	
	# Фиксируем выбранное состояние
	wave_function[cell_pos.x][cell_pos.y][cell_pos.z] = [chosen_state]
	
	print("Коллапс: ", cell_pos, " -> состояние ", chosen_state, " (", all_possible_states[chosen_state]["type"], ")")
	return true

func propagate_from(cell_pos: Vector3i):
	"""Распространяем ограничения от ячейки ко всем соседям"""
	var queue = [cell_pos]
	var processed = {}
	
	while not queue.is_empty():
		var current_cell = queue.pop_front()
		var cell_key = _pos_to_key(current_cell)
		
		if processed.get(cell_key):
			continue
		
		processed[cell_key] = true
		
		# Проверяем всех соседей в 4 направлениях
		for dir_idx in range(directions.size()):
			var neighbor_pos = current_cell + direction_vectors[directions[dir_idx]]
			
			if not is_valid_position(neighbor_pos):
				continue
			
			# Обновляем возможности соседа и добавляем в очередь если изменились
			if update_neighbor_constraints(current_cell, neighbor_pos, dir_idx):
				queue.append(neighbor_pos)

func update_neighbor_constraints(cell_pos: Vector3i, neighbor_pos: Vector3i, direction_idx: int):
	"""
	Обновляем ограничения для соседней ячейки
	Возвращает true если возможности соседа изменились
	"""
	var cell_possibilities = wave_function[cell_pos.x][cell_pos.y][cell_pos.z]
	var neighbor_possibilities = wave_function[neighbor_pos.x][neighbor_pos.y][neighbor_pos.z]
	
	var new_possibilities = []
	
	# Для каждого возможного состояния соседа
	for neighbor_state in neighbor_possibilities:
		var is_compatible = false
		
		# Проверяем совместимость с ВСЕМИ возможными состояниями текущей ячейки
		for cell_state in cell_possibilities:
			if compatibility_matrix[cell_state][direction_idx][neighbor_state]:
				is_compatible = true
				break
		
		# Сохраняем состояние только если оно совместимо
		if is_compatible:
			new_possibilities.append(neighbor_state)
	
	# Если список возможностей изменился
	if new_possibilities.size() != neighbor_possibilities.size():
		wave_function[neighbor_pos.x][neighbor_pos.y][neighbor_pos.z] = new_possibilities
		
		# Проверяем на противоречие
		if new_possibilities.is_empty():
			print("ПРОТИВОРЕЧИЕ: У соседа ", neighbor_pos, " не осталось возможных состояний!")
			return false
		
		return true
	
	return false

func instantiate_maze():
	"""Создаем визуальное представление лабиринта"""
	print("=== СОЗДАЕМ ВИЗУАЛЬНОЕ ПРЕДСТАВЛЕНИЕ ===")
	
	# Очищаем предыдущий лабиринт
	for child in get_children():
		if child is MazeTile or child.has_method("is_maze_tile"):
			child.queue_free()
	
	var created_tiles = 0
	var forced_collapses = 0
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			for z in range(grid_size.z):
				var possibilities = wave_function[x][y][z]
				
				if possibilities.is_empty():
					print("ПРОПУСК: Ячейка ", Vector3i(x, y, z), " не имеет возможных состояний")
					continue
				
				var state_index = -1
				
				if possibilities.size() == 1:
					# Нормальный случай - ячейка коллапсирована
					state_index = possibilities[0]
				elif possibilities.size() > 1:
					# Ячейка не коллапсирована - принудительно выбираем случайное состояние
					state_index = possibilities[randi() % possibilities.size()]
					forced_collapses += 1
					print("ПРИНУДИТЕЛЬНЫЙ КОЛЛАПС: ", Vector3i(x, y, z), " -> ", state_index)
				else:
					# Противоречие - выбираем дефолтное состояние
					state_index = 0
					print("КОНФЛИКТ: ", Vector3i(x, y, z), " -> принудительно состояние 0")
				
				# Создаем тайл
				if state_index >= 0 and state_index < all_possible_states.size():
					var state = all_possible_states[state_index]
					if tile_scenes.has(state["type"]):
						var tile = tile_scenes[state["type"]].instantiate()
						tile.position = Vector3(x * 4, y * 4, z * 4)
						# Ориентация уже заложена в самом тайле, поэтому не поворачиваем
						add_child(tile)
						created_tiles += 1
	
	print("Создано тайлов: ", created_tiles)
	if forced_collapses > 0:
		print("Предупреждение: ", forced_collapses, " ячеек были принудительно коллапсированы")
	
	# Добавляем генератор проходов
	_add_passage_generator()
	
func _add_passage_generator():
	"""Добавляет генератор проходов к лабиринту"""
	var passage_generator = Node.new()
	passage_generator.set_script(preload("res://scripts/passage_generator.gd"))
	add_child(passage_generator)
	
func is_valid_position(pos: Vector3i):
	"""Проверяем валидность позиции в сетке"""
	return (pos.x >= 0 and pos.x < grid_size.x and
			pos.y >= 0 and pos.y < grid_size.y and
			pos.z >= 0 and pos.z < grid_size.z)

func _pos_to_key(pos: Vector3i):
	"""Конвертируем Vector3i в строковый ключ"""
	return str(pos.x) + "," + str(pos.y) + "," + str(pos.z)
