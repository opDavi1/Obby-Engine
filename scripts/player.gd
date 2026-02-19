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

# Player nodes
@onready var camera_mount = $camera_mount;
@onready var visuals = $visuals;
@onready var animation_player = $AnimationPlayer;
@onready var camera_spring_arm = $camera_mount/SpringArm3D;
@onready var camera = $camera_mount/SpringArm3D/Camera3D;
@onready var torso_collision = $torso_collision;
@onready var head_collision = $head_collision;
@onready var climb_detection = $climb_detection;
@onready var climb_detection_ray_node: Node3D = $climb_detection/rays
@onready var part_detector = $climb_detection/part_detector;
@onready var player_model = [visuals, torso_collision, head_collision, climb_detection];
var climb_detection_rays = [];

# Private vars
var _current_state:= PLAYER_STATE_TYPE.IDLE;
var _previous_state := PLAYER_STATE_TYPE.NONE;

# Public vars
@export var jump_velocity := 14.0;
@export var sensitivity := 0.2;
@export var speed := 4.48;
@export var max_camera_zoom := 10.0;
@export var min_camera_zoom := 1.0;
var jump_grace_timer := 0.0; # seconds
var shiftlock_enabled := false;
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity"); # 54.936 m/s/s
var gravity_enabled := true;
var movement_enabled := true;


func get_state() -> PLAYER_STATE_TYPE:
	return _current_state;


# If code needs to run when a certain state changes, add it here
func set_state(new_state: PLAYER_STATE_TYPE) -> void:
	_previous_state = _current_state;
	_current_state = new_state;
	if new_state == PLAYER_STATE_TYPE.PLATFORM_STANDING:
		gravity_enabled = false;
		movement_enabled = false;
		velocity = Vector3.ZERO;

	if _previous_state == PLAYER_STATE_TYPE.PLATFORM_STANDING:
		gravity_enabled = true;
		movement_enabled = true;


func get_previous_state() -> PLAYER_STATE_TYPE:
	return _previous_state;


func jump() -> void:
	if get_state() == PLAYER_STATE_TYPE.JUMPING:
		return;
	
	if get_state() == PLAYER_STATE_TYPE.CLIMBING:
		velocity = transform.basis.z;
		velocity.y = jump_velocity / 2;
	else:
		velocity.y = jump_velocity;
		jump_grace_timer = 0;


func apply_gravity(dt) -> void:
	if is_on_floor():
		return;

	if gravity_enabled:
		velocity.y -= gravity * dt;
		jump_grace_timer -= dt;


func toggle_shift_lock() -> void:
	if shiftlock_enabled:
		shiftlock_enabled = false;
		camera_mount.position.x = 0;
		camera_mount.rotation.y = rotation.y;
		for part in player_model:
			part.rotation.y = rotation.y;
		rotation.y = 0;
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
	else:
		shiftlock_enabled = true;
		camera_mount.position.x = 0.43;
		rotation.y = camera_mount.rotation.y;
		camera_mount.rotation.y = 0;
		for part in player_model:
			part.rotation.y = 0;
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;


func calculate_movement_direction() -> Vector3:
	if not movement_enabled:
		return Vector3.ZERO;

	var pressingForward = Input.is_action_pressed("forward");
	var pressingBackward = Input.is_action_pressed("backward");
	var pressingLeft = Input.is_action_pressed("left");
	var pressingRight = Input.is_action_pressed("right");
	var direction = Vector3();
	
	if get_state() == PLAYER_STATE_TYPE.CLIMBING:
		if pressingForward || pressingLeft || pressingRight:
			direction += Vector3.UP;
		if pressingBackward: 
			direction += Vector3.DOWN;
	elif shiftlock_enabled:
		if pressingForward:
			direction -= transform.basis.z;
		if pressingBackward:
			direction += transform.basis.z;
		if pressingLeft:
			direction -= transform.basis.x;
		if pressingRight:
			direction += transform.basis.x;
	else: # Walking normally
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
		climb_detection_ray_node.add_child(ray);
		climb_detection_rays.append(ray);
		ray.target_position.y = 0;
		ray.target_position.z = -0.28;
		ray.position.z = -0.13;
		ray.position.y = lerp(-0.8, -0.15, i/25.0);


func update_climbing_state() -> void:
	if not part_detector.has_overlapping_bodies():
		set_state(PLAYER_STATE_TYPE.IDLE);
		for ray in climb_detection_rays:
			ray.enabled = false;
	else:
		var gap_above := false;
		var is_truss := false;
		var num_colliding_rays = 0;
		for i in range(climb_detection_rays.size() - 1):
			var ray = climb_detection_rays[i];
			ray.enabled = true;
			var obj = ray.get_collider();

			if obj && obj.get_meta("is_truss", false):
				is_truss = true;
				break;
			
			if ray.is_colliding():
				num_colliding_rays += 1;
			elif i > 0 && climb_detection_rays[i-1].is_colliding():
				gap_above = true;
				
		if num_colliding_rays <= 15 && num_colliding_rays > 0 && gap_above || is_truss:
			set_state(PLAYER_STATE_TYPE.CLIMBING);
		else:
			set_state(PLAYER_STATE_TYPE.IDLE);

	if is_on_floor() && Input.is_action_pressed("backward"):
		set_state(PLAYER_STATE_TYPE.IDLE);


func move_player() -> void:
	var player_state = get_state();
	var direction = calculate_movement_direction();
	

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
		if not shiftlock_enabled && player_state != PLAYER_STATE_TYPE.CLIMBING:
			for part in player_model:
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
	if shiftlock_enabled:
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
		camera.position.z = clamp(camera.position.z - 0.5, min_camera_zoom, max_camera_zoom);
		camera_spring_arm.spring_length = clamp(camera_spring_arm.spring_length - 0.5, min_camera_zoom, max_camera_zoom);
	if event.is_action_pressed("zoomOut"):
		camera.position.z = clamp(camera.position.z + 0.5, min_camera_zoom, max_camera_zoom);
		camera_spring_arm.spring_length = clamp(camera_spring_arm.spring_length + 0.5, min_camera_zoom, max_camera_zoom);


func _physics_process(dt):
	if Input.is_action_pressed("jump") && (jump_grace_timer > 0 || get_state() == PLAYER_STATE_TYPE.CLIMBING): 
		jump();

	if is_on_floor():
		jump_grace_timer = 0.1;
		
	apply_gravity(dt);
	move_player();
	move_and_slide();
	update_climbing_state();
