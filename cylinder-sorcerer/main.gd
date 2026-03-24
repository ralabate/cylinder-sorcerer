extends Node3D

const DUNGEON_COLOR = Color.BLACK

const PLAYER_CAMERA_SHAKE_AMOUNT = 0.70
const PLAYER_COLOR = Color.DARK_OLIVE_GREEN
const PLAYER_HP = 4
const PLAYER_NUM_HURT_FRAMES = 12
const PLAYER_RADIUS = 0.5
const PLAYER_SPEED = 0.05

const PLAYER_SWORD_ROOT_MOTION = 2.5
const PLAYER_NUM_SWORD_FRAMES = 20
const PLAYER_SWORD_ATTACK_START_ANGLE = -PI/2.0 - 0.5
const PLAYER_SWORD_ATTACK_ANGLE_INCREMENT = 2*PI / PLAYER_NUM_SWORD_FRAMES
const PLAYER_SWORD_LENGTH = 1.5
const PLAYER_SWORD_DEBUG_SPHERE_SIZE = 0.13

const SKULL_COUNT = 10

const SKULL_CAMERA_SHAKE_AMOUNT = 0.45
const SKULL_COLOR = Color.DIM_GRAY
const SKULL_HP = 3
const SKULL_NUM_HURT_FRAMES = 14
const SKULL_RADIUS = 1.0
const SKULL_SPEED = 0.02

const BAT_COUNT = 10

const BAT_CAMERA_SHAKE_AMOUNT = 0.15
const BAT_COLOR = Color.BROWN
const BAT_HP = 1
const BAT_NUM_HURT_FRAMES = 14
const BAT_RADIUS = 0.2
const BAT_SPEED = 0.01

const CAMERA_SHAKE_FRAMES = SKULL_NUM_HURT_FRAMES * 2.0

const WRAP_X = 17
const WRAP_Z = 9

enum Direction {
	LEFT   = 0b00000001,
	RIGHT  = 0b00000010,
	UP     = 0b00000100,
	DOWN   = 0b00001000,
	SWORD  = 0b00010000,
}

var input_bit_field: int
var input_bit_field_previous_frame: int
var was_attacking: bool
var is_attacking: bool

var frame: int
var sword_frame: int
var camera_shake_frame: int

var player: Actor
var baddie_list: Array[Actor]
var sword_pivot: Node3D
var sword: MeshInstance3D
var sword_debug: MeshInstance3D
var camera: Camera3D	
var camera_shake_amount: float

class Actor:
	var behavior_func
	var camera_shake_amount: float
	var color: Color
	var dir: Vector3i
	var hp: int
	var hurt_frame: int
	var is_dead: bool
	var knockback_dir: Vector3
	var mesh_instance: MeshInstance3D
	var num_hurt_frames: int
	var pos: Vector3
	var radius: float
	var seed: float
	var speed: float
	
	func _init(p_breed: Breed):
		self.behavior_func = p_breed.behavior_func
		self.camera_shake_amount = p_breed.camera_shake_amount
		self.color = p_breed.color
		self.dir = Vector3i(0, 0, 0)
		self.hp = p_breed.hp
		self.hurt_frame = p_breed.num_hurt_frames + 1
		self.is_dead = false
		self.mesh_instance = MeshInstance3D.new()
		self.mesh_instance.mesh = SphereMesh.new()
		self.mesh_instance.mesh.height = 2.0 * p_breed.radius
		self.mesh_instance.mesh.radius = p_breed.radius
		var material = StandardMaterial3D.new()
		material.albedo_color = self.color
		material.flags_unshaded = true
		self.mesh_instance.mesh.surface_set_material(0, material)
		self.num_hurt_frames = p_breed.num_hurt_frames
		var random_position = Vector3.ZERO
		random_position.x = randi_range(-WRAP_X, WRAP_X)
		random_position.z = randi_range(-WRAP_Z, WRAP_Z)
		self.pos = random_position
		self.radius = p_breed.radius
		self.seed = randf_range(0.0, 1.0)
		self.speed = p_breed.speed

class Breed:
	var behavior_func
	var camera_shake_amount: float
	var color: Color
	var hp: int
	var num_hurt_frames: int
	var radius: float
	var speed: float

	func _init(p_behavior_func, p_camera_shake_amount: float, p_color: Color, p_hp: int, p_num_hurt_frames: int, p_radius: float, p_speed: float):
		self.behavior_func = p_behavior_func
		self.camera_shake_amount = p_camera_shake_amount
		self.color = p_color
		self.hp = p_hp
		self.num_hurt_frames = p_num_hurt_frames
		self.radius = p_radius
		self.speed = p_speed

func behavior_func_seek(p_a: Actor, p_player_pos: Vector3):
	if player.is_dead:
		return
	var dir: Vector3
	dir.x = p_player_pos.x - p_a.pos.x
	dir.z = p_player_pos.z - p_a.pos.z
	p_a.pos += dir.normalized() * p_a.speed

func behavior_func_wander(p_a: Actor, p_player_pos: Vector3):
	p_a.pos.x += p_a.speed * sin(0.01 * frame + 100*p_a.seed)

func behavior_func_wander_then_seek(p_a: Actor, p_player_pos: Vector3):
	if p_a.hp <= 1:
		p_a.speed *= 2.0
		behavior_func_seek(p_a, p_player_pos)
		p_a.speed /= 2.0
	else:
		behavior_func_wander(p_a, p_player_pos)

func is_overlapping(p1, r1, p2, r2):
	return(p2.x - p1.x) * (p2.x - p1.x) + (p2.z - p1.z) * (p2.z - p1.z) < (r1 + r2) * (r1 + r2)

func _ready() -> void:
	RenderingServer.set_default_clear_color(DUNGEON_COLOR)

	var player_breed = Breed.new(behavior_func_seek, PLAYER_CAMERA_SHAKE_AMOUNT, PLAYER_COLOR, PLAYER_HP, PLAYER_NUM_HURT_FRAMES, PLAYER_RADIUS, PLAYER_SPEED)
	player = Actor.new(player_breed)
	player.pos = Vector3(0, 0, 0*WRAP_Z)

	sword_frame = PLAYER_NUM_SWORD_FRAMES + 1
	sword = MeshInstance3D.new()
	sword.mesh = BoxMesh.new()
	sword.mesh.size = Vector3(PLAYER_SWORD_LENGTH, 0.1, 0.25)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.set_transparency(1) # enum not working
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

	var skull_breed = Breed.new(behavior_func_wander_then_seek, SKULL_CAMERA_SHAKE_AMOUNT, SKULL_COLOR, SKULL_HP, SKULL_NUM_HURT_FRAMES, SKULL_RADIUS, SKULL_SPEED)
	for i in SKULL_COUNT:
			baddie_list.append(Actor.new(skull_breed))

	var bat_breed = Breed.new(behavior_func_seek, BAT_CAMERA_SHAKE_AMOUNT, BAT_COLOR, BAT_HP, BAT_NUM_HURT_FRAMES, BAT_RADIUS, BAT_SPEED)
	for i in BAT_COUNT:
			baddie_list.append(Actor.new(bat_breed))

	var root = get_tree().root.get_children()[0] # Switch to Engine.get_main_loop() (as SceneTree)... or actually call get_node("Root") and pass it for the Actor to attach

	root.add_child(player.mesh_instance)

	for i in baddie_list.size():
		root.add_child(baddie_list[i].mesh_instance)

	camera = Camera3D.new()
	camera.set_orthogonal(20.0, 1.0, 40.0)
	camera.look_at_from_position(Vector3(0, 20, 0), Vector3(0, 0, 0), Vector3(0, 0, -1))
	camera.make_current()
	camera_shake_frame = CAMERA_SHAKE_FRAMES + 1
	root.add_child(camera)
	
	
func _process(_delta: float) -> void:
	frame = frame + 1

	if sword_frame > PLAYER_NUM_SWORD_FRAMES and player.hurt_frame > player.num_hurt_frames:
		if Input.is_key_pressed(KEY_A): input_bit_field |= Direction.LEFT
		if Input.is_key_pressed(KEY_D): input_bit_field |= Direction.RIGHT
		if Input.is_key_pressed(KEY_W): input_bit_field |= Direction.UP
		if Input.is_key_pressed(KEY_S): input_bit_field |= Direction.DOWN

		var tmp_dir = Vector3i(0, 0, 0)

		if input_bit_field & Direction.LEFT:
			input_bit_field ^= Direction.LEFT
			tmp_dir.x -= 1

		if input_bit_field & Direction.RIGHT:
			input_bit_field ^= Direction.RIGHT
			tmp_dir.x += 1

		if input_bit_field & Direction.UP:
			input_bit_field ^= Direction.UP
			tmp_dir.z -= 1

		if input_bit_field & Direction.DOWN:
			input_bit_field ^= Direction.DOWN
			tmp_dir.z += 1

		var normalized_tmp_dir: Vector3 = tmp_dir
		normalized_tmp_dir = normalized_tmp_dir.normalized()
		player.pos += PLAYER_SPEED * normalized_tmp_dir

		if tmp_dir != Vector3i.ZERO:
			player.dir = tmp_dir
	
	if player.hurt_frame <= player.num_hurt_frames:
		match player.hurt_frame:
			1:
				player.pos += player.knockback_dir * 0.40
			_ when player.hurt_frame < player.num_hurt_frames:
				player.pos += player.knockback_dir * 0.05
				if player.hurt_frame % 2 == 0:
					RenderingServer.set_default_clear_color(DUNGEON_COLOR)
					player.mesh_instance.get_active_material(0).albedo_color = Color.WHITE
				else:
					RenderingServer.set_default_clear_color(Color.RED)
					player.mesh_instance.get_active_material(0).albedo_color = Color.BLACK
			_ when player.hurt_frame == player.num_hurt_frames:
				player.mesh_instance.get_active_material(0).albedo_color = Color.DARK_OLIVE_GREEN
				RenderingServer.set_default_clear_color(DUNGEON_COLOR)


		player.hurt_frame += 1

	player.pos.x = clamp(player.pos.x, -WRAP_X, WRAP_X)
	player.pos.z = clamp(player.pos.z, -WRAP_Z, WRAP_Z)
			
	player.mesh_instance.transform.origin = player.pos

	var player_theta = Vector2(player.dir.x, -player.dir.z).angle()
	var m1 = Basis.IDENTITY
	player.mesh_instance.transform.basis = m1.rotated(Vector3.UP, player_theta)

	var breathing_scale = 0.9 + 0.1 * abs(pow(sin(0.02 * frame), 3))
	player.mesh_instance.scale = Vector3(breathing_scale, 1.0, breathing_scale)

	sword.transform.origin = Vector3(PLAYER_SWORD_LENGTH/1.5, 0.0, 0.0) # can i do this up top? or not until it is added to the scene?

	if Input.is_key_pressed(KEY_H):
		sword_debug.visible = !sword_debug.visible

	is_attacking = Input.is_key_pressed(KEY_J)
	if is_attacking && !was_attacking && sword_frame > PLAYER_NUM_SWORD_FRAMES:
		sword_frame = 1

	was_attacking = is_attacking

	if sword_frame <= PLAYER_NUM_SWORD_FRAMES:
		sword.show()

		match sword_frame:
			1:
				sword_pivot.transform = Transform3D.IDENTITY
				sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, PLAYER_SWORD_ATTACK_START_ANGLE)
				player.pos += player.dir * PLAYER_SWORD_ROOT_MOTION * -0.15 # BUG!!! ONE FRAME BEHIND, SINCE WE UPDATE PLAYER ABOVE! BUT IF ITS DOWN HERE, FALSE POSITIVE ON SWIPE!!!
				sword.get_active_material(0).albedo_color = Color.WHITE
			_ when sword_frame < 7:
				sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, 0.10 * PLAYER_SWORD_ATTACK_ANGLE_INCREMENT)
				player.pos += player.dir * (PLAYER_SWORD_ROOT_MOTION / PLAYER_NUM_SWORD_FRAMES) * 0.0
				sword.get_active_material(0).albedo_color = Color.YELLOW
			_ when sword_frame < 11:
				sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, 2.2 * PLAYER_SWORD_ATTACK_ANGLE_INCREMENT)
				player.pos += player.dir * (PLAYER_SWORD_ROOT_MOTION / PLAYER_NUM_SWORD_FRAMES)
				sword.get_active_material(0).albedo_color = Color(1, 1, 0, 0.27)
			_ when sword_frame < PLAYER_NUM_SWORD_FRAMES:
				sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, 0.65 * PLAYER_SWORD_ATTACK_ANGLE_INCREMENT)
				player.pos += player.dir * (PLAYER_SWORD_ROOT_MOTION / PLAYER_NUM_SWORD_FRAMES) * 0.1
				sword.get_active_material(0).albedo_color = Color.YELLOW
			_ when sword_frame == PLAYER_NUM_SWORD_FRAMES:
				sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, 0.40 * PLAYER_SWORD_ATTACK_ANGLE_INCREMENT)
				sword.get_active_material(0).albedo_color = Color(1, 1, 0, 0.50)

		sword_frame += 1
				
	else: 
		sword_pivot.transform = Transform3D.IDENTITY
		sword_pivot.transform = sword_pivot.transform.rotated(Vector3.UP, PLAYER_SWORD_ATTACK_START_ANGLE)
		sword.hide()

	sword_debug.transform.origin = Vector3.ZERO
	sword_debug.transform.origin += sword_pivot.basis.x.normalized() * 0.9 * PLAYER_SWORD_LENGTH
	
	for i in baddie_list.size():
		var b = baddie_list[i]
		b.hurt_frame += 1

		if b.hurt_frame > b.num_hurt_frames && is_overlapping(b.pos, b.radius, sword_debug.global_transform.origin, PLAYER_SWORD_DEBUG_SPHERE_SIZE) && sword_frame <= PLAYER_NUM_SWORD_FRAMES:
			b.hurt_frame = 1
			b.knockback_dir.x = b.pos.x - player.pos.x
			b.knockback_dir.z = b.pos.z - player.pos.z
			b.knockback_dir = b.knockback_dir.normalized()
			b.hp -= 1
			if b.hp == 0:
				camera_shake_amount = b.camera_shake_amount
				camera_shake_frame = 1
			b.speed *= -1

		if b.hurt_frame <= b.num_hurt_frames:

			match b.hurt_frame:
				1:
					b.mesh_instance.get_active_material(0).albedo_color = b.color
					b.mesh_instance.scale = Vector3(0.9, 0.9, 0.9)
					b.pos += b.knockback_dir * -0.05
					b.pos.x += randf_range(-1.0, 1.0) * 0.1
					b.pos.z += randf_range(-1.0, 1.0) * 0.1

				2:
					b.mesh_instance.get_active_material(0).albedo_color = Color.WHITE
					b.mesh_instance.scale = Vector3(0.8, 0.8, 0.8)
					b.pos += b.knockback_dir * -0.03
					b.pos.x += randf_range(-1.0, 1.0) * 0.09
					b.pos.z += randf_range(-1.0, 1.0) * 0.09
				3:
					b.mesh_instance.get_active_material(0).albedo_color = Color.WHITE
					b.mesh_instance.scale = Vector3(1.35, 1.35, 1.35)
					b.pos += b.knockback_dir * 0.55
					b.pos.x += randf_range(-1.0, 1.0) * 0.08
					b.pos.z += randf_range(-1.0, 1.0) * 0.08
				4:
					b.mesh_instance.get_active_material(0).albedo_color = Color.WHITE
					b.mesh_instance.scale = Vector3(1.2, 1.2, 1.2)
					b.pos += b.knockback_dir * 0.35
					b.pos.x += randf_range(-1.0, 1.0) * 0.07
					b.pos.z += randf_range(-1.0, 1.0) * 0.07
				5:
					b.mesh_instance.get_active_material(0).albedo_color = b.color
					b.mesh_instance.scale = Vector3(1.1, 1.1, 1.1)
					b.pos += b.knockback_dir * 0.22
					b.pos.x += randf_range(-1.0, 1.0) * 0.06
					b.pos.z += randf_range(-1.0, 1.0) * 0.06
				_ when b.hurt_frame < b.num_hurt_frames:
					b.mesh_instance.get_active_material(0).albedo_color = b.color
					b.mesh_instance.scale = Vector3(1, 1, 1)
					b.pos.x += randf_range(-1.0, 1.0) * 0.01
					b.pos.z += randf_range(-1.0, 1.0) * 0.01
					b.pos += b.knockback_dir * 0.10
					if b.hp == 0:
						b.pos = Vector3(999, 999, 999)
						b.speed = 0
						b.mesh_instance.hide()
				_ when b.hurt_frame == b.num_hurt_frames:
					b.mesh_instance.get_active_material(0).albedo_color = b.color

		b.behavior_func.call(b, player.pos)

		b.mesh_instance.transform.origin = b.pos

		if is_overlapping(b.pos, b.radius, player.pos, player.radius) && sword_frame > PLAYER_NUM_SWORD_FRAMES:
			player.hurt_frame = 1
			player.knockback_dir.x = player.pos.x - b.pos.x
			player.knockback_dir.z = player.pos.z - b.pos.z
			player.knockback_dir = player.knockback_dir.normalized()
			player.hp -= 1
			if (player.hp <= 0):
				pass
				#player.is_dead = true
				#player.mesh_instance.hide()
			camera_shake_amount = player.camera_shake_amount
			camera_shake_frame = 1

	if camera_shake_frame <= CAMERA_SHAKE_FRAMES:
		camera.transform.origin.x = randf_range(-1.0, 1.0) * camera_shake_amount * (1.0 - float(camera_shake_frame)/CAMERA_SHAKE_FRAMES)
		camera.transform.origin.z = randf_range(-1.0, 1.0) * camera_shake_amount * (1.0 - float(camera_shake_frame)/CAMERA_SHAKE_FRAMES)
		var camera_theta = randf_range(-PI, PI) * 0.02
		camera.rotation_degrees.z += camera_theta
		camera_shake_frame += 1
	else:
		camera.look_at_from_position(Vector3(0, 20, 0), Vector3(0, 0, 0), Vector3(0, 0, -1))
