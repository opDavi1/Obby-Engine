extends CharacterBody3D

@onready var camera_mount = $camera_mount
@onready var visuals = $visuals
@onready var animation_player = $AnimationPlayer
@onready var camera_spring_arm = $camera_mount/SpringArm3D
@onready var camera = $camera_mount/SpringArm3D/Camera3D
@onready var torso_collision = $torso_collision
@onready var head_collision = $head_collision

const JUMP_GRACE_TIME = 0.1 #seconds

@export var jumpVelocity = 14
@export var sensitivity = 0.2
@export var speed = 4.48
@export var maxCameraZoom = 10
@export var minCameraZoom = 1

var jumpGraceTimer = 0
var shiftLockEnabled = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func jump():
	velocity.y = jumpVelocity
	jumpGraceTimer = 0
	
func toggleShiftLock():
	if shiftLockEnabled:
		shiftLockEnabled = false
		camera_mount.position.x = 0
		camera_mount.rotation.y = rotation.y
		visuals.rotation.y = rotation.y
		torso_collision.rotation.y = rotation.y
		head_collision.rotation.y = rotation.y
		rotation.y = 0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		shiftLockEnabled = true
		camera_mount.position.x = 0.43
		rotation.y = camera_mount.rotation.y
		camera_mount.rotation.y = 0
		visuals.rotation.y = 0
		torso_collision.rotation.y = 0
		head_collision.rotation.y = 0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion:
		if shiftLockEnabled:
			rotation.y -= deg_to_rad(event.relative.x * sensitivity)
			rotation.y = wrapf(rotation.y, 0.0, TAU)
			
			camera_mount.rotation.x -= deg_to_rad(event.relative.y * sensitivity)
			camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-89), deg_to_rad(80))
			
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			camera_mount.rotation.y -= deg_to_rad(event.relative.x * sensitivity)
			camera_mount.rotation.y = wrapf(camera_mount.rotation.y, 0.0, TAU)
			
			camera_mount.rotation.x -= deg_to_rad(event.relative.y * sensitivity)
			camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-89), deg_to_rad(80))
			
	if event is InputEventMouseButton:
		if event.button_index == 4:
			camera.position.z = clamp(camera.position.z - 0.5, minCameraZoom, maxCameraZoom)
			camera_spring_arm.spring_length = clamp(camera_spring_arm.spring_length - 0.5, minCameraZoom, maxCameraZoom)
		elif event.button_index == 5:
			camera.position.z = clamp(camera.position.z + 0.5, minCameraZoom, maxCameraZoom)
			camera_spring_arm.spring_length = clamp(camera_spring_arm.spring_length + 0.5, minCameraZoom, maxCameraZoom)

func _process(_delta):
	if Input.is_action_just_pressed("shiftLock"):
		toggleShiftLock()

func _physics_process(delta):
	if is_on_floor():
		jumpGraceTimer = JUMP_GRACE_TIME
	else:
		velocity.y -= gravity * delta
		jumpGraceTimer -= delta

	if Input.is_action_pressed("jump") and jumpGraceTimer > 0:
		jump();

	# calculate direction to move
	var direction = Vector3()
	if shiftLockEnabled:
		if Input.is_action_pressed("forward"):
			direction -= transform.basis.z
		elif Input.is_action_pressed("backward"):
			direction += transform.basis.z
		if Input.is_action_pressed("left"):
			direction -= transform.basis.x
		if Input.is_action_pressed("right"):
			direction += transform.basis.x
	else:
		if Input.is_action_pressed("forward"):
			direction -= camera_mount.transform.basis.z
		elif Input.is_action_pressed("backward"):
			direction += camera_mount.transform.basis.z
		if Input.is_action_pressed("left"):
			direction -= camera_mount.transform.basis.x
		if Input.is_action_pressed("right"):
			direction += camera_mount.transform.basis.x
		direction.y = 0
	direction = direction.normalized()
		
	if direction != Vector3.ZERO:
		if animation_player.current_animation != "walk":
			animation_player.play("walk")
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not shiftLockEnabled:
			visuals.look_at(position + direction)
	else:
		if animation_player.current_animation != "idle":
			animation_player.play("idle")
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
