# main.gd
extends Node3D

func _ready():
	# Создаем менеджер материалов, если его еще нет
	#if not has_node("/root/GameMaterialsManager"):
		#var materials_manager = preload("res://scripts/material_manager.gd").new()
		#get_tree().root.add_child(materials_manager)
		#materials_manager.name = "MaterialsManager"
		#print("MaterialsManager создан и добавлен в сцену")

	# Настраиваем освещение
	setup_lighting()
	
	# Даем время на инициализацию
	await get_tree().create_timer(1.0).timeout
	print("Сцена готова")

func setup_lighting():
	# Создаем направленный свет (основное освещение)
	var directional_light = DirectionalLight3D.new()
	directional_light.name = "DirectionalLight3D"
	directional_light.light_color = Color(1, 1, 1)
	directional_light.light_energy = 1.5
	directional_light.shadow_enabled = false
	directional_light.rotation_degrees = Vector3(60, 45, 0)
	add_child(directional_light)
	
	# Создаем окружающую среду с ярким ambient light
	var environment = WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.8, 0.8, 0.9)  # Светлый фон
	
	# Яркое окружающее освещение
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	
	environment.environment = env
	add_child(environment)

func _input(event):
	if event.is_action_pressed("ui_accept"): # Пробел
		# Перезапускаем генерацию
		get_tree().reload_current_scene()
