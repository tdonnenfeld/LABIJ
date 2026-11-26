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

static func convert_limb(skeleton: Skeleton3D, original: MeshInstance3D, owner_bone: int, upper: int, lower: int, width: float) -> MeshInstance3D:
	if not original.mesh:
		return null
	var owner_rest := skeleton.get_bone_global_rest(owner_bone)
	var joint_rest := skeleton.get_bone_global_rest(lower)
	var transform := owner_rest * original.transform
	var normal_basis := transform.basis.inverse().transposed()
	var mesh := ArrayMesh.new()
	for surface_id in range(original.mesh.get_surface_count()):
		var arrays := original.mesh.surface_get_arrays(surface_id)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for i in range(vertices.size()):
			vertices[i] = transform * vertices[i]
			var y := (vertices[i] - joint_rest.origin).dot(joint_rest.basis.y.normalized())
			var t := smoothstep(-width, width, -y)
			bones.append_array(PackedInt32Array([upper, lower, 0, 0]))
			weights.append_array(PackedFloat32Array([1.0 - t, t, 0.0, 0.0]))
			if i < normals.size():
				normals[i] = (normal_basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals if not normals.is_empty() else null
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface_id, original.get_active_material(surface_id))
	var skin := Skin.new()
	for i in range(skeleton.get_bone_count()):
		skin.add_bind(i, skeleton.get_bone_global_rest(i).affine_inverse())
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.skin = skin
	skeleton.add_child(node)
	node.skeleton = NodePath("..")
	original.hide()
	return node
