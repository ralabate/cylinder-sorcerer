extends Node3D

@export var NUM_BADDIES: int

class Character:
	
	var pos: Vector3
	var radius: float
	var color: Color
	var meshInstance: MeshInstance3D
	
	func _init(p_pos: Vector3, p_radius: float, p_color: Color):
		self.pos = p_pos
		self.radius = p_radius
		self.color = p_color
		self.meshInstance = MeshInstance3D.new()
		self.meshInstance.mesh = BoxMesh.new()
		var material = StandardMaterial3D.new()
		material.albedo_color = p_color
		material.flags_unshaded = true
		self.meshInstance.mesh.surface_set_material(0, material)

var player: Character
var baddie: Character
var baddie_list: Array[Character]
var camera: Camera3D	

func _ready() -> void:
	# create characters
	player = Character.new(Vector3.ZERO, 1.0, Color.RED)
	for i in NUM_BADDIES:
			var random_position = Vector3.ZERO
			random_position.x = randi_range(-10, 10)
			random_position.z = randi_range(-10, 10)
			baddie_list.append(Character.new(random_position, 1.0, Color.MAGENTA))
			print("Adding baddie" + str(i) + " at x=" + str(random_position.x) + " z=" + str(random_position.z))
	
	# create camera
	camera = Camera3D.new()
	camera.look_at_from_position(Vector3(0, 20, 0), Vector3(0, 0, 0), Vector3(0, 0, -1))
	camera.make_current()
	
	# add meshes and camera to render list
	var root = get_tree().root.get_children()[0]
	root.add_child(player.meshInstance)
	for i in NUM_BADDIES:
		root.add_child(baddie_list[i].meshInstance)
	root.add_child(camera)
	
func _process(_delta: float) -> void:
	if (Input.is_action_just_pressed("ui_accept")):
		player.pos.x += 1;
	player.meshInstance.global_transform.origin = player.pos
	
	for i in NUM_BADDIES:
		baddie_list[i].meshInstance.global_transform.origin = baddie_list[i].pos
