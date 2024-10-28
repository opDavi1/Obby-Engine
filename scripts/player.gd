# This script is a part of opDavi1's Definitive Obby Engine (ODOE) which is licensed under the GNU GPL-3.0-or-later license

extends CharacterBody3D;

enum PLAYER_STATE_TYPE {
	IDLE,
	RUNNING,
	JUMPING,
	CLIMBING,
	FREEFALL,
	LANDED,
	FALLING_DOWN,
	GETTING_UP,
	SEATED,
	PLATFORM_STANDING,
	DEAD,
	NONE,
}

@onready var camera_mount = $camera_mount;
@onready var visuals = $visuals;
@onready var animation_player = $AnimationPlayer;
@onready var camera_spring_arm = $camera_mount/SpringArm3D;
@onready var camera = $camera_mount/SpringArm3D/Camera3D;
@onready var torso_collision = $torso_collision;
@onready var head_collision = $head_collision;
@onready var climb_detection = $climb_detection;
@onready var part_detector = $climb_detection/part_detector;
@onready var playerModel = [visuals, torso_collision, head_collision, climb_detection];

@export var jumpVelocity := 14.0;
@export var sensitivity := 0.2;
@export var speed := 4.48;
@export var maxCameraZoom := 10.0;
@export var minCameraZoom := 1.0;
var jumpGraceTimer := 0.0;
var shiftLockEnabled := false;
var isClimbing := false;
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity"); # 54.936 m/s/s
var gravityEnabled := true;
var player_state := PLAYER_STATE_TYPE.IDLE;

func jump() -> void:
	if player_state == PLAYER_STATE_TYPE.JUMPING:
		return;
	
	if player_state == PLAYER_STATE_TYPE.CLIMBING:
		velocity = transform.basis.z;
		velocity.y = jumpVelocity / 2;
	else:
		velocity.y = jumpVelocity;
		jumpGraceTimer = 0;


func apply_gravity(dt) -> void:
	if is_on_floor():
		jumpGraceTimer = 0.1; # seconds
	elif gravityEnabled:
		velocity.y -= gravity * dt;
		jumpGraceTimer -= dt;


func toggle_shift_lock() -> void:
	if shiftLockEnabled:
		shiftLockEnabled = false;
		camera_mount.position.x = 0;
		camera_mount.rotation.y = rotation.y;
		for part in playerModel:
			part.rotation.y = rotation.y;
		rotation.y = 0;
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
	else:
		shiftLockEnabled = true;
		camera_mount.position.x = 0.43;
		rotation.y = camera_mount.rotation.y;
		camera_mount.rotation.y = 0;
		for part in playerModel:
			part.rotation.y = 0;
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;


func calculate_movement_direction() -> Vector3:
	var pressingForward = Input.is_action_pressed("forward");
	var pressingBackward = Input.is_action_pressed("backward");
	var pressingLeft = Input.is_action_pressed("left");
	var pressingRight = Input.is_action_pressed("right");
	var direction = Vector3();
	
	if player_state == PLAYER_STATE_TYPE.CLIMBING:
		if pressingForward:
			direction += Vector3.UP;
		if pressingBackward: 
			direction += Vector3.DOWN;
		if pressingLeft:
			direction += Vector3.UP;
		if pressingRight:
			direction += Vector3.UP;
	elif shiftLockEnabled:
		if pressingForward:
			direction -= transform.basis.z;
		if pressingBackward:
			direction += transform.basis.z;
		if pressingLeft:
			direction -= transform.basis.x;
		if pressingRight:
			direction += transform.basis.x;
	else:
		if pressingForward:
			direction -= camera_mount.transform.basis.z;
		if pressingBackward:
			direction += camera_mount.transform.basis.z;
		if pressingLeft:
			direction -= camera_mount.transform.basis.x;
		if pressingRight:
			direction += camera_mount.transform.basis.x;
		direction.y = 0;
	return direction.normalized();


func set_player_animation(animation: String) -> void:
	if animation_player.current_animation != animation:
		animation_player.play(animation);


func create_rays_for_climbing_detection() -> void:
	for i in range(25):
		var ray = RayCast3D.new();
		climb_detection.get_child(1).add_child(ray);
		ray.target_position.y = 0;
		ray.target_position.z = -0.28;
		ray.position.z = -0.13;
		ray.position.y = lerp(-0.75, -0.1, i/25.0);


func update_climbing_state() -> void:
	if not part_detector.has_overlapping_bodies():
		player_state = PLAYER_STATE_TYPE.IDLE;
	else:
		var rays = climb_detection.get_child(1).get_children();
		var num_colliding_rays = 0;
		var is_truss = false;
		for ray in rays:
			var obj = ray.get_collider()
			if obj && obj.metadata.is_truss:
				is_truss = true;
				break;
			if ray.is_colliding():
				num_colliding_rays += 1;
				
		if num_colliding_rays <= 15 && num_colliding_rays > 0 || is_truss:
			player_state = PLAYER_STATE_TYPE.CLIMBING;
		else:
			player_state = PLAYER_STATE_TYPE.IDLE;

	if is_on_floor() && Input.is_action_pressed("backward"):
		isClimbing = false;


func move_player(direction: Vector3) -> void:
	if direction == Vector3.ZERO:
		match player_state:
			PLAYER_STATE_TYPE.IDLE, PLAYER_STATE_TYPE.RUNNING:
				set_player_animation("idle");
				velocity.x = move_toward(velocity.x, 0, speed);
				velocity.z = move_toward(velocity.z, 0, speed);
			PLAYER_STATE_TYPE.CLIMBING:
				velocity.x = 0;
				velocity.z = 0;
				velocity.y = direction.y * speed;
				set_player_animation("climb");
	else:
		if not shiftLockEnabled && player_state != PLAYER_STATE_TYPE.CLIMBING:
			for part in playerModel:
				part.rotation.y = lerp_angle(part.rotation.y, atan2(-direction.x, -direction.z), 0.15);
		match player_state:
			PLAYER_STATE_TYPE.IDLE, PLAYER_STATE_TYPE.RUNNING:
				velocity.x = direction.x * speed;
				velocity.z = direction.z * speed;
				set_player_animation("walk");
			PLAYER_STATE_TYPE.CLIMBING:
				velocity.x = 0;
				velocity.z = 0;
				velocity.y = direction.y * speed;
				set_player_animation("climb");


func move_camera(event: InputEventMouseMotion) -> void:
	if shiftLockEnabled:
		rotation.y -= deg_to_rad(event.relative.x * sensitivity);
		rotation.y = wrapf(rotation.y, 0.0, TAU);
		camera_mount.rotation.x -= deg_to_rad(event.relative.y * sensitivity);
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-89), deg_to_rad(80));
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_mount.rotation.y -= deg_to_rad(event.relative.x * sensitivity);
		camera_mount.rotation.y = wrapf(camera_mount.rotation.y, 0.0, TAU);
		camera_mount.rotation.x -= deg_to_rad(event.relative.y * sensitivity);
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-89), deg_to_rad(80));


func _ready():
	create_rays_for_climbing_detection();


func _input(event):
	if event.is_action_pressed("shiftLock"): 
		toggle_shift_lock();
	
	if event is InputEventMouseMotion:
		move_camera(event);
		
	if event.is_action_pressed("zoomIn"):
		camera.position.z = clamp(camera.position.z - 0.5, minCameraZoom, maxCameraZoom);
		camera_spring_arm.spring_length = clamp(camera_spring_arm.spring_length - 0.5, minCameraZoom, maxCameraZoom);
	if event.is_action_pressed("zoomOut"):
		camera.position.z = clamp(camera.position.z + 0.5, minCameraZoom, maxCameraZoom);
		camera_spring_arm.spring_length = clamp(camera_spring_arm.spring_length + 0.5, minCameraZoom, maxCameraZoom);


func _physics_process(dt):
	if Input.is_action_pressed("jump") && (jumpGraceTimer > 0 || isClimbing): 
		jump();
		
	apply_gravity(dt);
	update_climbing_state();
	var movement_direction = calculate_movement_direction();
	move_player(movement_direction);
	move_and_slide();
	
