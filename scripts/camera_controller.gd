extends Camera3D

@export var rotation_speed: float = 0.5
var angle: float = 0.0

func _ready():
	update_camera_position()

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_LEFT and event.pressed:
			angle -= PI / 8
			update_camera_position()
		if event.keycode == KEY_RIGHT and event.pressed:
			angle += PI / 8
			update_camera_position()

func update_camera_position():
	var radius = 25.0
	var height = 30.0
	position = Vector3(
		cos(angle) * radius + 10,
		height,
		sin(angle) * radius + 10
	)
	look_at(Vector3(10, 0, 10))
