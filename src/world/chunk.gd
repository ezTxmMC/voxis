# Chunk.gd
class_name Chunk
extends MeshInstance3D

const SIZE = 16
const HEIGHT = 64

const VERTS = [
	Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0),
	Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1),
]

enum Face { TOP, BOTTOM, NORTH, SOUTH, EAST, WEST }
enum Tex { GRASS_SIDE, GRASS_TOP, DIRT, STONE }

const FACES = [
	{ "dir": Vector3i(0, 1, 0),  "corners": [2, 3, 7, 6], "normal": Vector3(0, 1, 0),  "id": Face.TOP },
	{ "dir": Vector3i(0, -1, 0), "corners": [0, 1, 5, 4], "normal": Vector3(0, -1, 0), "id": Face.BOTTOM },
	{ "dir": Vector3i(0, 0, -1), "corners": [3, 2, 1, 0], "normal": Vector3(0, 0, -1), "id": Face.NORTH },
	{ "dir": Vector3i(0, 0, 1),  "corners": [6, 7, 4, 5], "normal": Vector3(0, 0, 1),  "id": Face.SOUTH },
	{ "dir": Vector3i(1, 0, 0),  "corners": [2, 6, 5, 1], "normal": Vector3(1, 0, 0),  "id": Face.EAST },
	{ "dir": Vector3i(-1, 0, 0), "corners": [7, 3, 0, 4], "normal": Vector3(-1, 0, 0), "id": Face.WEST },
]

const FACE_UVS = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
const TRI_ORDER = [0, 2, 1, 0, 3, 2]

var generator: TerrainGenerator
var chunk_pos: Vector2i
var materials: Array
var blocks = PackedByteArray()
var _ready_mesh: ArrayMesh
var _ready_shape: Shape3D


func setup(gen: TerrainGenerator, pos: Vector2i, mats: Array) -> void:
	generator = gen
	chunk_pos = pos
	materials = mats
	position = Vector3(pos.x * SIZE, 0, pos.y * SIZE)


func build_data() -> void:
	_generate()
	_build_mesh_data()
	

func apply() -> void:
	mesh = _ready_mesh

	if _ready_shape == null:
		return

	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	col.shape = _ready_shape
	body.add_child(col)
	add_child(body)


func _index(x: int, y: int, z: int) -> int:
	return x + z * SIZE + y * SIZE * SIZE


func _generate() -> void:
	blocks.resize(SIZE * HEIGHT * SIZE)

	for x in SIZE:
		for z in SIZE:
			var world_x = chunk_pos.x * SIZE + x
			var world_z = chunk_pos.y * SIZE + z

			for y in HEIGHT:
				blocks[_index(x, y, z)] = generator.block_at(world_x, y, world_z)


func _is_solid(x: int, y: int, z: int) -> bool:
	if y < 0:
		return true

	if y >= HEIGHT:
		return false

	if x < 0 or x >= SIZE or z < 0 or z >= SIZE:
		var world_x = chunk_pos.x * SIZE + x
		var world_z = chunk_pos.y * SIZE + z
		return generator.block_at(world_x, y, world_z) != Block.Type.AIR

	return blocks[_index(x, y, z)] != Block.Type.AIR
	
	
func _build_mesh_data() -> void:
	var tools = {}

	for x in SIZE:
		for y in HEIGHT:
			for z in SIZE:
				var type = blocks[_index(x, y, z)]

				if type == Block.Type.AIR:
					continue

				_add_block(tools, x, y, z, type)

	var array_mesh = ArrayMesh.new()
	var surface_index = 0

	for tex in tools:
		var st = tools[tex]
		st.generate_tangents()
		st.commit(array_mesh)
		array_mesh.surface_set_material(surface_index, materials[tex])
		surface_index += 1

	_ready_mesh = array_mesh

	if array_mesh.get_surface_count() > 0:
		_ready_shape = array_mesh.create_trimesh_shape()


func _add_block(tools: Dictionary, x: int, y: int, z: int, type: int) -> void:
	for face in FACES:
		var dir = face["dir"]

		if _is_solid(x + dir.x, y + dir.y, z + dir.z):
			continue

		var tex = _tex_for(type, face["id"])
		var st = _tool_for(tools, tex)
		_add_face(st, x, y, z, face)


func _tool_for(tools: Dictionary, tex: int) -> SurfaceTool:
	if tools.has(tex):
		return tools[tex]

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	tools[tex] = st
	return st


func _add_face(st: SurfaceTool, x: int, y: int, z: int, face: Dictionary) -> void:
	var base = Vector3(x, y, z)
	var corners = face["corners"]
	var normal = face["normal"]

	for i in TRI_ORDER:
		st.set_normal(normal)
		st.set_uv(FACE_UVS[i])
		st.add_vertex(base + VERTS[corners[i]])


func _tex_for(type: int, face: int) -> int:
	if type == Block.Type.GRASS_BLOCK:
		if face == Face.TOP:
			return Tex.GRASS_TOP

		if face == Face.BOTTOM:
			return Tex.DIRT

		return Tex.GRASS_SIDE

	if type == Block.Type.DIRT:
		return Tex.DIRT

	return Tex.STONE
