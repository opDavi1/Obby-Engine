extends CharacterBody3D

@onready var camera_mount = $camera_mount
@onready var visuals = $visuals
@onready var animation_player = $AnimationPlayer
@onready var camera_spring_arm = $camera_mount/SpringArm3D
@onready var camera = $camera_mount/SpringArm3D/Camera3D
@onready var torso_collision = $torso_collision
@onready var head_collision = $head_collision
@onready var wall_check = $visuals/player_model/torso/wall_check
@onready var still_wall = $visuals/player_model/torso/still_wall
@onready var playerModel = [visuals, torso_collision, head_collision]

@export var jumpVelocity: float = 14
@export var sensitivity: float = 0.2
@export var speed: float = 4.48
@export var maxCameraZoom: float = 10
@export var minCameraZoom: float = 1

var jumpGraceTimer: float = 0
var shiftLockEnabled = false
var isClimbing = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravityEnabled = true

const JUMP_GRACE_TIME = 0.1 #seconds

func jump() -> void:
	if isClimbing:
		velocity = transform.basis.z
		velocity.y = jumpVelocity
	else:
		velocity.y = jumpVelocity
		jumpGraceTimer = 0
	
func toggleShiftLock() -> void:
	if shiftLockEnabled:
		shiftLockEnabled = false
		camera_mount.position.x = 0
		camera_mount.rotation.y = rotation.y
		for part in playerModel:
			part.rotation.y = rotation.y
		rotation.y = 0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		shiftLockEnabled = true
		camera_mount.position.x = 0.43
		rotation.y = camera_mount.rotation.y
		camera_mount.rotation.y = 0
		for part in playerModel:
			part.rotation.y = 0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
func calculateMovementDirection() -> Vector3:
	var pressingForward = Input.is_action_pressed("forward")
	var pressingBackward = Input.is_action_pressed("backward")
	var pressingLeft = Input.is_action_pressed("left")
	var pressingRight = Input.is_action_pressed("right")
	var direction = Vector3()
	
	if isClimbing:
		if pressingForward:
			direction += Vector3.UP
		if pressingBackward: 
			direction += Vector3.DOWN
		if pressingLeft:
			direction += Vector3.UP
		if pressingRight:
			direction += Vector3.UP
	elif shiftLockEnabled:
		if pressingForward:
			direction -= transform.basis.z
		if pressingBackward:
			direction += transform.basis.z
		if pressingLeft:
			direction -= transform.basis.x
		if pressingRight:
			direction += transform.basis.x
	else:
		if pressingForward:
			direction -= camera_mount.transform.basis.z
		if pressingBackward:
			direction += camera_mount.transform.basis.z
		if pressingLeft:
			direction -= camera_mount.transform.basis.x
		if pressingRight:
			direction += camera_mount.transform.basis.x
		direction.y = 0
	return direction.normalized()
	
func setPlayerAnimation(animation: String) -> void:
	if animation_player.current_animation != animation:
		animation_player.play(animation)
		
func updateClimbingState() -> void:
	if wall_check.is_colliding() && still_wall.is_colliding():
		isClimbing = true
	else:
		isClimbing = false
	if is_on_floor() && Input.is_action_pressed("backward"):
		isClimbing = false
	
func movePlayer() -> void:
	var direction = calculateMovementDirection()
	if direction != Vector3.ZERO:
		if isClimbing:
			velocity.x = 0
			velocity.z = 0
			velocity.y = direction.y * speed
			setPlayerAnimation("climb")
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			setPlayerAnimation("walk")
		if not shiftLockEnabled:
			for part in playerModel:
				part.rotation.y = lerp_angle(part.rotation.y, atan2(-direction.x, -direction.z), 0.15)
	elif isClimbing:
		animation_player.pause()
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	else:
		setPlayerAnimation("idle")
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	

func _input(event):
	if event.is_action_pressed("shiftLock"): 
		toggleShiftLock()
		
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
			
	if event.is_action_pressed("zoomIn"):
		camera.position.z = clamp(camera.position.z - 0.5, minCameraZoom, maxCameraZoom)
		camera_spring_arm.spring_length = clamp(camera_spring_arm.spring_length - 0.5, minCameraZoom, maxCameraZoom)
	if event.is_action_pressed("zoomOut"):
		camera.position.z = clamp(camera.position.z + 0.5, minCameraZoom, maxCameraZoom)
		camera_spring_arm.spring_length = clamp(camera_spring_arm.spring_length + 0.5, minCameraZoom, maxCameraZoom)

func _physics_process(delta):
	if is_on_floor():
		jumpGraceTimer = JUMP_GRACE_TIME
	elif gravityEnabled:
		velocity.y -= gravity * delta
		jumpGraceTimer -= delta
		
	if Input.is_action_pressed("jump") && (jumpGraceTimer > 0 || isClimbing): 
		jump()
	
	updateClimbingState()
	movePlayer()
	

