extends Node3D

const RENDER_DISTANCE = 4
const UNLOAD_DISTANCE = RENDER_DISTANCE + 2
const MAX_PENDING = 6
const FINALIZE_PER_FRAME = 2

var generator = TerrainGenerator.new(12345)
var materials: Array
var chunks = {}
var pending = {}
var load_queue = []
var player: Player
var current_chunk = Vector2i(99999, 99999)


func _ready() -> void:
	materials = _build_materials()
	_add_lighting()
	_spawn_player()

	var center = _chunk_of(player.position)
	_build_chunk_sync(center)
	_update_chunks(center)


func _physics_process(_delta: float) -> void:
	if player == null:
		return

	var coord = _chunk_of(player.position)

	if coord != current_chunk:
		_update_chunks(coord)

	_dispatch_from_queue()
	_process_pending()


func _exit_tree() -> void:
	for coord in pending:
		WorkerThreadPool.wait_for_task_completion(pending[coord]["task"])

	pending.clear()


func _chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / float(Chunk.SIZE)), floori(pos.z / float(Chunk.SIZE)))


func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


func _update_chunks(center: Vector2i) -> void:
	current_chunk = center
	_queue_needed_chunks(center)
	_free_distant_chunks(center)


func _queue_needed_chunks(center: Vector2i) -> void:
	var wanted = []

	for x in range(center.x - RENDER_DISTANCE, center.x + RENDER_DISTANCE + 1):
		for z in range(center.y - RENDER_DISTANCE, center.y + RENDER_DISTANCE + 1):
			var coord = Vector2i(x, z)

			if chunks.has(coord):
				continue

			if pending.has(coord):
				continue

			if load_queue.has(coord):
				continue

			wanted.append(coord)

	wanted.sort_custom(func(a, b):
		var da = a - center
		var db = b - center
		return da.x * da.x + da.y * da.y < db.x * db.x + db.y * db.y)

	load_queue.append_array(wanted)


func _free_distant_chunks(center: Vector2i) -> void:
	var to_remove = []

	for coord in chunks:
		if _chunk_distance(center, coord) <= UNLOAD_DISTANCE:
			continue

		to_remove.append(coord)

	for coord in to_remove:
		chunks[coord].queue_free()
		chunks.erase(coord)

	var kept = []

	for coord in load_queue:
		if _chunk_distance(center, coord) > UNLOAD_DISTANCE:
			continue

		kept.append(coord)

	load_queue = kept


func _dispatch_from_queue() -> void:
	while pending.size() < MAX_PENDING and not load_queue.is_empty():
		var coord = load_queue.pop_front()

		if chunks.has(coord):
			continue

		if pending.has(coord):
			continue

		_dispatch_chunk(coord)


func _dispatch_chunk(coord: Vector2i) -> void:
	var chunk = Chunk.new()
	add_child(chunk)
	chunk.setup(generator, coord, materials)

	var task = WorkerThreadPool.add_task(chunk.build_data)
	pending[coord] = { "chunk": chunk, "task": task }


func _process_pending() -> void:
	var done = []

	for coord in pending:
		if WorkerThreadPool.is_task_completed(pending[coord]["task"]):
			done.append(coord)

	var count = 0

	for coord in done:
		if count >= FINALIZE_PER_FRAME:
			break

		var entry = pending[coord]
		WorkerThreadPool.wait_for_task_completion(entry["task"])
		pending.erase(coord)

		var chunk = entry["chunk"]

		if not is_instance_valid(chunk):
			continue

		chunk.apply()
		chunks[coord] = chunk
		count += 1


func _build_chunk_sync(coord: Vector2i) -> void:
	if chunks.has(coord):
		return

	var chunk = Chunk.new()
	add_child(chunk)
	chunk.setup(generator, coord, materials)
	chunk.build_data()
	chunk.apply()
	chunks[coord] = chunk


func _add_lighting() -> void:
	var sun = DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, -0.5, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	add_child(env)


func _spawn_player() -> void:
	player = Player.new()
	var surface = generator.height_at(0, 0)
	player.position = Vector3(0.5, surface + 3, 0.5)
	add_child(player)


func _build_materials() -> Array:
	var mats = []
	mats.resize(Chunk.Tex.size())
	mats[Chunk.Tex.GRASS_SIDE] = _make_material("res://assets/textures/blocks/grass_block_side.png")
	mats[Chunk.Tex.GRASS_TOP] = _make_material("res://assets/textures/blocks/grass_block_top.png")
	mats[Chunk.Tex.DIRT] = _make_material("res://assets/textures/blocks/dirt.png")
	mats[Chunk.Tex.STONE] = _make_material("res://assets/textures/blocks/stone.png")
	return mats


func _make_material(path: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
