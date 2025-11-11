extends Camera3D

@export var rotation_speed: float = 0.5
@export var maze_size: Vector3 = Vector3(16, 1, 16)  # Размер лабиринта в тайлах
@export var camera_radius: float = 30.0
@export var camera_height: float = 35.0

var angle: float = 0.0
var maze_center: Vector3 = Vector3.ZERO

func _ready():
	print("Камера: инициализация с maze_size = ", maze_size)
	calculate_center()
	update_camera_position()

func calculate_center():
	# ВЫЧИСЛЯЕМ ЦЕНТР ЛАБИРИНТА
	# Размер тайла = 4 единицы, поэтому: (количество_тайлов * размер_тайла) / 2
	maze_center = Vector3(
		(maze_size.x * 4) / 2.0,  # 8 тайлов * 4 / 2 = 16
		1,
		(maze_size.z * 4) / 2.0   # 8 тайлов * 4 / 2 = 16
	)
	var max_dimension = max(maze_size.x, maze_size.z)
	camera_height = max_dimension * 3  # 16 × 2.5 = 40

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_LEFT and event.pressed:
			angle -= PI / 8
			update_camera_position()
		if event.keycode == KEY_RIGHT and event.pressed:
			angle += PI / 8
			update_camera_position()
	
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_radius = max(camera_radius - 2.0, 10.0)
				update_camera_position()
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_radius = min(camera_radius + 2.0, 100.0)
				update_camera_position()

func update_camera_position():
	position = Vector3(
		cos(angle) * camera_radius + maze_center.x,
		camera_height,
		sin(angle) * camera_radius + maze_center.z
	)
	look_at(maze_center)
	print("Камера: pos=", position, " look_at=", maze_center)
