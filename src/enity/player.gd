class_name Player
extends CharacterBody3D

const SPEED = 6.0
const JUMP_VELOCITY = 8.0
const MOUSE_SENS = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D


func _ready() -> void:
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.height = 1.8
	shape.radius = 0.3
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)

	camera = Camera3D.new()
	camera.position = Vector3(0, 1.7, 0)
	camera.far = 1000.0
	add_child(camera)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

	if not direction:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
