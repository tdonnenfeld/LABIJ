extends CharacterBody3D

var floor_id := 0
var direction := Vector2.ZERO
var heading := 0.0
var look_pitch := 0.0
var camera: Camera3D

func setup(local: bool, visual: bool = true) -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	collision.shape = capsule
	add_child(collision)
	if not visual:
		return
	var mesh := MeshInstance3D.new()
	var model := CapsuleMesh.new()
	model.radius = 0.32
	model.height = 1.7
	mesh.mesh = model
	mesh.visible = not local
	add_child(mesh)
	if local:
		camera = Camera3D.new()
		camera.position.y = 0.55
		camera.current = true
		add_child(camera)
		var light := OmniLight3D.new()
		light.omni_range = 14
		light.light_energy = 2.5
		camera.add_child(light)

func simulate(delta: float) -> void:
	rotation.y = heading
	var forward := Vector3(sin(heading), 0, cos(heading))
	var right := Vector3(cos(heading), 0, -sin(heading))
	var motion := (right * direction.x + forward * direction.y) * 4.5
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = maxf(velocity.y - 18.0 * delta, -20.0)
	move_and_slide()
