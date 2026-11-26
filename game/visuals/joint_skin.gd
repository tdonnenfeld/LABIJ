extends RefCounted

static func sleeve(skeleton: Skeleton3D, upper: int, lower: int, radius: float, material: Material) -> MeshInstance3D:
	var rest := skeleton.get_bone_global_rest(lower)
	var center := rest.origin
	var axis := rest.basis.y.normalized()
	var right := rest.basis.x.normalized()
	var forward := rest.basis.z.normalized()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(4):
		for side in range(8):
			for corner in [[ring, side], [ring + 1, side], [ring + 1, side + 1], [ring, side], [ring + 1, side + 1], [ring, side + 1]]:
				var t := float(corner[0]) / 4.0
				var angle := float(corner[1]) * TAU / 8.0
				var normal := right * cos(angle) + forward * sin(angle)
				var at := center + axis * lerpf(radius, -radius, t) + normal * radius
				surface.set_normal(normal)
				surface.set_uv(Vector2(float(corner[1]) / 8.0, t))
				surface.set_bones(PackedInt32Array([upper, lower, 0, 0]))
				surface.set_weights(PackedFloat32Array([1.0 - t, t, 0.0, 0.0]))
				surface.add_vertex(at)
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = material
	var skin := Skin.new()
	for i in range(skeleton.get_bone_count()):
		skin.add_bind(i, skeleton.get_bone_global_rest(i).affine_inverse())
	node.skin = skin
	skeleton.add_child(node)
	node.skeleton = NodePath("..")
	return node
