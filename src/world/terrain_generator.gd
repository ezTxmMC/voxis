class_name TerrainGenerator
extends RefCounted

var noise = FastNoiseLite.new()
var base_height = 32
var amplitude = 16

func _init(world_seed: int = 0):
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01
	
	
func height_at(world_x: int, world_z: int) -> int:
	var n = noise.get_noise_2d(world_x, world_z)
	return base_height + int(n * amplitude)
	
	
func block_at(world_x: int, world_y: int, world_z: int) -> int:
	var surface = height_at(world_x, world_z)
	
	if world_y > surface:
		return Block.Type.AIR
	
	if world_y == surface:
		return Block.Type.GRASS_BLOCK
		
	if world_y > surface - 4:
		return Block.Type.DIRT
		
	return Block.Type.STONE
	
