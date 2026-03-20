extends Node3D

const PLAYER_SPEED = 0.03
const PLAYER_RADIUS = 0.5
const PLAYER_SIZE = 1.0
const PLAYER_ATTACK_ROOT_MOTION = 1.0

const PLAYER_SWORD_FRAMES = 17
const PLAYER_SWORD_ATTACK_START_ANGLE = -PI/2.0 - 0.5
const PLAYER_SWORD_ATTACK_ANGLE_INCREMENT = 2*PI / PLAYER_SWORD_FRAMES
const PLAYER_SWORD_LENGTH = 1.2
const PLAYER_SWORD_DEBUG_SPHERE_SIZE = 0.15
const PLAYER_HP = 4

const BADDIE_COUNT = 10
const BADDIE_SPEED = 0.02
const BADDIE_RADIUS = 0.7
const BADDIE_HURT_FRAMES = 12
const BADDIE_HP = 3

const CAMERA_SHAKE_FRAMES = BADDIE_HURT_FRAMES + 3
const CAMERA_SHAKE_AMOUNT = 0.25

const WRAP_X = 17
const WRAP_Z = 9

var was_attacking: bool
var is_attacking: bool
var is_moving_left: bool
var is_moving_right: bool
var is_moving_up: bool
var is_moving_down: bool

var frame: int
var sword_frame: int
var camera_shake_frame: int
# hurt_frame in baddie struct

var player: Character
var baddie: Character
var baddie_list: Array[Character]
var sword_pivot: Node3D
var sword: MeshInstance3D
var sword_debug: MeshInstance3D
var camera: Camera3D	

class Character:
	
	var pos: Vector3
	var theta: float
	var radius: float
	var color: Color
	var mesh_instance: MeshInstance3D
	var hurt_frame: int
	var hp: int
	var seed: float
	var knockback_dir: Vector3
	var speed: float
	
	func _init(p_pos: Vector3, p_radius: float, p_color: Color, p_hp: int):
		self.pos = p_pos
		self.theta = 0
		self.radius = p_radius
		self.color = p_color
		self.mesh_instance = MeshInstance3D.new()
		self.mesh_instance.mesh = SphereMesh.new()
		self.mesh_instance.mesh.radius = p_radius
		self.mesh_instance.mesh.height = 2.0 * p_radius
		var material = StandardMaterial3D.new()
		material.albedo_color = p_color
		material.flags_unshaded = true
		self.mesh_instance.mesh.surface_set_material(0, material)
		self.hurt_frame = BADDIE_HURT_FRAMES + 1
		self.hp = p_hp
		self.seed = randf_range(0.0, 1.0)
		self.speed = BADDIE_SPEED

func is_overlapping(p1, r1, p2, r2):
	return(p2.x - p1.x) * (p2.x - p1.x) + (p2.z - p1.z) * (p2.z - p1.z) < (r1 + r2) * (r1 + r2)

func _ready() -> void:
	player = Character.new(Vector3.ZERO, PLAYER_RADIUS, Color.DARK_OLIVE_GREEN, PLAYER_HP)

	sword_frame = PLAYER_SWORD_FRAMES + 1
	sword = MeshInstance3D.new()
	sword.mesh = BoxMesh.new()
	sword.mesh.size = Vector3(PLAYER_SWORD_LENGTH, 0.1, 0.25)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.flags_unshaded = true
	sword.mesh.surface_set_material(0, material)
	sword_pivot = Node3D.new()
	sword_pivot.add_child(sword)
	player.mesh_instance.add_child(sword_pivot)

	sword_debug = MeshInstance3D.new()
	sword_debug.mesh = SphereMesh.new()
	sword_debug.mesh.height = PLAYER_SWORD_DEBUG_SPHERE_SIZE
	sword_debug.mesh.radius = PLAYER_SWORD_DEBUG_SPHERE_SIZE * 2
	material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.flags_unshaded = true
	sword_debug.mesh.surface_set_material(0, material)
	player.mesh_instance.add_child(sword_debug)
	sword_debug.visible = false

	for i in BADDIE_COUNT:
			var random_position = Vector3.ZERO
			random_position.x = randi_range(-WRAP_X, WRAP_X)
			random_position.z = randi_range(-WRAP_Z, WRAP_Z)
			baddie_list.append(Character.new(random_position, BADDIE_RADIUS, Color.DIM_GRAY, BADDIE_HP))
	
	camera = Camera3D.new()
	camera.set_orthogonal(20.0, 1.0, 40.0)
	camera.look_at_from_position(Vector3(0, 20, 0), Vector3(0, 0, 0), Vector3(0, 0, -1))
	camera.make_current()
	camera_shake_frame = CAMERA_SHAKE_FRAMES + 1
	
	var root = get_tree().root.get_children()[0] # Switch to Engine.get_main_loop() (as SceneTree)... or actually call get_node("Root") and pass it for the Character to attach
	root.add_child(player.mesh_instance)
	for i in BADDIE_COUNT:
		root.add_child(baddie_list[i].mesh_instance)
	root.add_child(camera)
	
func _process(_delta: float) -> void:
	frame = frame + 1
	sword_frame = min(sword_frame + 1, PLAYER_SWORD_FRAMES)
	camera_shake_frame += 1

	is_attacking = Input.is_key_pressed(KEY_J)
	if is_attacking && !was_attacking && sword_frame >= PLAYER_SWORD_FRAMES:
		sword_frame = 0
		sword_pivot.transform = Transform3D.IDENTITY
		sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, PLAYER_SWORD_ATTACK_START_ANGLE)
		player.pos.x += cos(player.theta) * PLAYER_ATTACK_ROOT_MOTION * -0.05
		player.pos.z -= sin(player.theta) * PLAYER_ATTACK_ROOT_MOTION * -0.05
		sword.get_active_material(0).albedo_color = Color.WHITE

	was_attacking = is_attacking

	sword.transform.origin = Vector3(PLAYER_SWORD_LENGTH/1.5, 0.0, 0.0) # can i do this up top? or not until it is added to the scene?

	if sword_frame < PLAYER_SWORD_FRAMES:
		sword.show()

		match sword_frame:
			0:
				pass # set up above, on impact
			_ when sword_frame < 5:
				sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, 0.2 * PLAYER_SWORD_ATTACK_ANGLE_INCREMENT)
				sword.get_active_material(0).albedo_color = Color.YELLOW
				player.pos.x += cos(player.theta) * (PLAYER_ATTACK_ROOT_MOTION / PLAYER_SWORD_FRAMES) * 0.1
				player.pos.z -= sin(player.theta) * (PLAYER_ATTACK_ROOT_MOTION / PLAYER_SWORD_FRAMES) * 0.1
			_ when sword_frame < 9:
				sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, 1.7 * PLAYER_SWORD_ATTACK_ANGLE_INCREMENT)
				player.pos.x += cos(player.theta) * (PLAYER_ATTACK_ROOT_MOTION / PLAYER_SWORD_FRAMES)
				player.pos.z -= sin(player.theta) * (PLAYER_ATTACK_ROOT_MOTION / PLAYER_SWORD_FRAMES)
				#sword.get_active_material(0).albedo_color = Color.WHITE
			_ when sword_frame < PLAYER_SWORD_FRAMES:
				sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, 0.45 * PLAYER_SWORD_ATTACK_ANGLE_INCREMENT)
				player.pos.x += cos(player.theta) * (PLAYER_ATTACK_ROOT_MOTION / PLAYER_SWORD_FRAMES) * 0.3
				player.pos.z -= sin(player.theta) * (PLAYER_ATTACK_ROOT_MOTION / PLAYER_SWORD_FRAMES) * 0.3
				#sword.get_active_material(0).albedo_color = Color.YELLOW
				
	else:
		sword_pivot.transform = Transform3D.IDENTITY
		#figure out how to tilt sword
		#sword_pivot.transform = sword_pivot.transform.rotated(Vector3(0.2, 0.1, 0.2), 0.5*PI)
		sword.hide()

	if sword_frame >= PLAYER_SWORD_FRAMES:
		is_moving_left = Input.is_key_pressed(KEY_A)
		if is_moving_left:
			player.pos.x -= PLAYER_SPEED
			player.theta = PI
			
		is_moving_right = Input.is_key_pressed(KEY_D)
		if is_moving_right:
			player.pos.x += PLAYER_SPEED
			player.theta = 0
			
		is_moving_up = Input.is_key_pressed(KEY_W)
		if is_moving_up:
			player.pos.z -= PLAYER_SPEED
			player.theta = PI/2.0
			
		is_moving_down = Input.is_key_pressed(KEY_S)
		if is_moving_down:
			player.pos.z += PLAYER_SPEED
			player.theta = -PI/2.0

	player.pos.x = clamp(player.pos.x, -WRAP_X, WRAP_X)
	player.pos.z = clamp(player.pos.z, -WRAP_Z, WRAP_Z)
			
	player.mesh_instance.transform.origin = player.pos
	var m1 = Basis.IDENTITY
	player.mesh_instance.transform.basis = m1.rotated(Vector3.UP, player.theta)

	var breathing_scale = 0.9 + 0.1 * abs(pow(sin(0.02 * frame), 3))
	player.mesh_instance.scale = Vector3(breathing_scale, 1.0, breathing_scale)

	if Input.is_key_pressed(KEY_H):
		sword_debug.visible = !sword_debug.visible

	sword_debug.transform.origin = Vector3.ZERO
	sword_debug.transform.origin += sword_pivot.basis.x.normalized() * 0.8 * PLAYER_SWORD_LENGTH
	sword.scale = Vector3(1, 1, 1)
	
	for i in BADDIE_COUNT:
		var b = baddie_list[i]
		b.hurt_frame += 1

		if b.hurt_frame > BADDIE_HURT_FRAMES && is_overlapping(b.pos, b.radius, sword_debug.global_transform.origin, PLAYER_SWORD_DEBUG_SPHERE_SIZE) && sword_frame < PLAYER_SWORD_FRAMES:
			b.hurt_frame = 1
			b.knockback_dir.x = b.pos.x - player.pos.x
			b.knockback_dir.z = b.pos.z - player.pos.z
			b.knockback_dir = b.knockback_dir.normalized()
			b.hp -= 1
			if b.hp == 0:
				camera_shake_frame = 1
			b.speed *= -1

		if b.hurt_frame <= BADDIE_HURT_FRAMES:

			match b.hurt_frame:
				1:
					b.mesh_instance.get_active_material(0).albedo_color = Color.DIM_GRAY
					b.mesh_instance.scale = Vector3(0.7, 0.7, 0.7)
					b.pos += b.knockback_dir * -0.20
					b.pos.x += randf_range(-1.0, 1.0) * 0.1
					b.pos.z += randf_range(-1.0, 1.0) * 0.1

				2:
					b.mesh_instance.get_active_material(0).albedo_color = Color.WHITE
					b.mesh_instance.scale = Vector3(0.9, 0.9, 0.9)
					b.pos += b.knockback_dir * 0.50
					b.pos.x += randf_range(-1.0, 1.0) * 0.09
					b.pos.z += randf_range(-1.0, 1.0) * 0.09
				3:
					b.mesh_instance.get_active_material(0).albedo_color = Color.WHITE
					b.mesh_instance.scale = Vector3(1.35, 1.35, 1.35)
					b.pos += b.knockback_dir * 0.20
					b.pos.x += randf_range(-1.0, 1.0) * 0.08
					b.pos.z += randf_range(-1.0, 1.0) * 0.08
				4:
					b.mesh_instance.get_active_material(0).albedo_color = Color.WHITE
					b.mesh_instance.scale = Vector3(1.2, 1.2, 1.2)
					b.pos += b.knockback_dir * 0.10
					b.pos.x += randf_range(-1.0, 1.0) * 0.07
					b.pos.z += randf_range(-1.0, 1.0) * 0.07
				5:
					b.mesh_instance.get_active_material(0).albedo_color = Color.DIM_GRAY
					b.mesh_instance.scale = Vector3(1.1, 1.1, 1.1)
					b.pos += b.knockback_dir * 0.07
					b.pos.x += randf_range(-1.0, 1.0) * 0.06
					b.pos.z += randf_range(-1.0, 1.0) * 0.06
				_ when b.hurt_frame < BADDIE_HURT_FRAMES:
					b.mesh_instance.get_active_material(0).albedo_color = Color.DIM_GRAY
					b.mesh_instance.scale = Vector3(1, 1, 1)
					b.pos.x += randf_range(-1.0, 1.0) * 0.01
					b.pos.z += randf_range(-1.0, 1.0) * 0.01
					b.pos += b.knockback_dir * 0.05
					if b.hp == 0:
						b.pos = Vector3(999, 999, 999)
						b.speed = 0
						b.mesh_instance.hide()

		if b.hurt_frame > BADDIE_HURT_FRAMES:
			b.pos.x += b.seed * b.speed * sin(0.01 * frame + b.seed)

		b.mesh_instance.transform.origin = b.pos

		if b.hurt_frame > BADDIE_HURT_FRAMES && is_overlapping(b.pos, b.radius, player.pos, player.radius) and sword_frame > PLAYER_SWORD_FRAMES:
			player.pos = Vector3.ZERO
			player.theta = randf_range(-PI, PI)
			player.hp -= 1
			

	if camera_shake_frame <= CAMERA_SHAKE_FRAMES:
		camera.transform.origin.x = randf_range(-1.0, 1.0) * CAMERA_SHAKE_AMOUNT * (1.0 - float(camera_shake_frame)/CAMERA_SHAKE_FRAMES)
		camera.transform.origin.z = randf_range(-1.0, 1.0) * CAMERA_SHAKE_AMOUNT * (1.0 - float(camera_shake_frame)/CAMERA_SHAKE_FRAMES)
		var theta = randf_range(-PI, PI) * 0.03
		camera.rotation_degrees.z += theta
	else:
		camera.look_at_from_position(Vector3(0, 20, 0), Vector3(0, 0, 0), Vector3(0, 0, -1))
		
