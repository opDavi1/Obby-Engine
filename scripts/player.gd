extends CharacterBody3D;

@onready var camera_mount = $camera_mount
@onready var visuals = $visuals
@onready var animation_player = $visuals/model/AnimationPlayer


@export var sensitivity = 0.2;


var jumpGraceTimer = 0;
const JUMP_GRACE_TIME = 0.1; #seconds
var JUMP_VELOCITY = 14;
var SPEED = 4.48;
var shift_lock = true;
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity");


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sensitivity));
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sensitivity));
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-90), deg_to_rad(45));
		
func jump():
	velocity.y = JUMP_VELOCITY;
	jumpGraceTimer = 0;
	
func _physics_process(delta):

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta; 
		jumpGraceTimer -= delta;
		
	if is_on_floor():
		jumpGraceTimer = JUMP_GRACE_TIME;

	# Handle jump.
	if Input.is_action_pressed("ui_accept") and jumpGraceTimer > 0:
		jump();
	

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "backward");
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized();
	if direction:
		if animation_player.current_animation != "walk":
			animation_player.play("walk");
		velocity.x = direction.x * SPEED;
		velocity.z = direction.z * SPEED;
		if !shift_lock:
			visuals.look_at(position + direction);
	else:
		if animation_player.current_animation != "idle":
			animation_player.play("idle");
		velocity.x = move_toward(velocity.x, 0, SPEED);
		velocity.z = move_toward(velocity.z, 0, SPEED);

	move_and_slide();
