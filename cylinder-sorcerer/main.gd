extends Node3D

@onready var node_3d_cylinder: Node3D = $Node3D_Cylinder

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	if (Input.is_action_just_pressed("ui_accept")):
		node_3d_cylinder.position.z += 0.1;
