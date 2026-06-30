class_name LaneCoords
extends RefCounted

## Grid-to-world conversion for the 3D lane (XZ plane).
## Resize lanes by editing config/lane.json — spawn, exit, builder, and AI margins derive from it.

static var grid_width: int = 16
static var grid_height: int = 26
static var cell_size: float = 2.0
static var spawn_cell: Vector2i = Vector2i(8, 0)
static var exit_cell: Vector2i = Vector2i(8, 25)
static var builder_cell: Vector2i = Vector2i(4, 12)
static var ai_label_cell: Vector2i = Vector2i(8, 2)


static func load_from_config() -> void:
	var lane: Dictionary = BalanceConfig.lane
	grid_width = maxi(int(lane.get("grid_width", 16)), 3)
	grid_height = maxi(int(lane.get("grid_height", 26)), 3)
	cell_size = float(lane.get("cell_size", 2.0))

	if lane.has("spawn_cell"):
		spawn_cell = _read_cell(lane.get("spawn_cell"), default_spawn_cell())
	else:
		spawn_cell = default_spawn_cell()

	if lane.has("exit_cell"):
		exit_cell = _read_cell(lane.get("exit_cell"), default_exit_cell())
	else:
		exit_cell = default_exit_cell()

	if lane.has("builder_cell"):
		builder_cell = _read_cell(lane.get("builder_cell"), default_builder_cell())
	else:
		builder_cell = default_builder_cell()

	if lane.has("ai_label_cell"):
		ai_label_cell = _read_cell(lane.get("ai_label_cell"), default_ai_label_cell())
	else:
		ai_label_cell = default_ai_label_cell()

	_clamp_layout_cells()
	_validate_config()


static func default_spawn_cell() -> Vector2i:
	var inset := _spawn_exit_inset()
	return Vector2i(grid_width / 2, inset)


static func default_exit_cell() -> Vector2i:
	var inset := _spawn_exit_inset()
	return Vector2i(grid_width / 2, grid_height - 1 - inset)


static func default_builder_cell() -> Vector2i:
	var x := clampi(spawn_cell.x - maxi(grid_width / 4, 1), buildable_x_min(), buildable_x_max())
	var y := clampi((spawn_cell.y + exit_cell.y) / 2, buildable_y_min(), buildable_y_max())
	return Vector2i(x, y)


static func default_ai_label_cell() -> Vector2i:
	return Vector2i(
		clampi(spawn_cell.x, 0, grid_width - 1),
		clampi(spawn_cell.y + 2, 0, grid_height - 1)
	)


static func grid_center_cell() -> Vector2i:
	return Vector2i(grid_width / 2, grid_height / 2)


static func lane_world_width() -> float:
	return float(grid_width) * cell_size


static func lane_world_depth() -> float:
	return float(grid_height) * cell_size


static func lane_stride(extra_spacing: float = 0.0) -> float:
	return lane_world_width() + extra_spacing


static func buildable_x_min() -> int:
	return 1


static func buildable_x_max() -> int:
	return grid_width - 2


static func buildable_y_min() -> int:
	return 1


static func buildable_y_max() -> int:
	return grid_height - 2


static func is_border_cell(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.x == grid_width - 1


static func is_margin_row(cell: Vector2i) -> bool:
	return cell.y == 0 or cell.y == grid_height - 1


static func is_creep_path_cell(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not is_border_cell(cell) and not is_margin_row(cell)


static func is_in_bounds(grid: Vector2i) -> bool:
	return grid.x >= 0 and grid.x < grid_width and grid.y >= 0 and grid.y < grid_height


static func is_buildable_interior(grid: Vector2i) -> bool:
	return (
		grid.x >= buildable_x_min()
		and grid.x <= buildable_x_max()
		and grid.y >= buildable_y_min()
		and grid.y <= buildable_y_max()
	)


static func playable_cell_cols() -> int:
	return buildable_x_max() - buildable_x_min() + 1


static func playable_cell_rows() -> int:
	return buildable_y_max() - buildable_y_min() + 1


static func playable_world_origin() -> Vector3:
	var ox := grid_origin_offset_x()
	return Vector3(ox + buildable_x_min() * cell_size, 0.0, buildable_y_min() * cell_size)


static func playable_world_center() -> Vector3:
	var origin := playable_world_origin()
	return origin + Vector3(
		playable_cell_cols() * cell_size * 0.5,
		0.0,
		playable_cell_rows() * cell_size * 0.5
	)


static func playable_world_size() -> Vector2:
	return Vector2(playable_cell_cols() * cell_size, playable_cell_rows() * cell_size)


static func grid_origin_offset_x() -> float:
	return -grid_width * cell_size * 0.5


static func grid_to_world(grid: Vector2i) -> Vector3:
	var ox := grid_origin_offset_x()
	return Vector3(ox + grid.x * cell_size, 0.0, grid.y * cell_size)


static func world_to_grid(world: Vector3) -> Vector2i:
	var ox := grid_origin_offset_x()
	var gx := int(floor((world.x - ox) / cell_size))
	var gz := int(floor(world.z / cell_size))
	return Vector2i(gx, gz)


static func grid_to_world_center(grid: Vector2i) -> Vector3:
	var ox := grid_origin_offset_x()
	return Vector3(ox + (grid.x + 0.5) * cell_size, 0.0, (grid.y + 0.5) * cell_size)


## Chebyshev distance — how many square grid steps apart (includes diagonals).
static func grid_tile_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Gameplay distances/speeds in config are expressed in tiles; convert for 3D physics.
static func tiles_to_world(tiles: float) -> float:
	return tiles * cell_size


static func tile_speed_to_world(tiles_per_second: float) -> float:
	return tiles_per_second * cell_size


static func range_world_size(range_tiles: int) -> float:
	return tiles_to_world(float(range_tiles * 2 + 1))


static func lane_bounds() -> AABB:
	var ox := grid_origin_offset_x()
	return AABB(
		Vector3(ox, 0.0, 0.0),
		Vector3(grid_width * cell_size, 0.1, grid_height * cell_size)
	)


static func _spawn_exit_inset() -> int:
	var lane: Dictionary = BalanceConfig.lane
	return maxi(int(lane.get("spawn_exit_inset", 2)), 0)


static func _read_cell(data: Variant, fallback: Vector2i) -> Vector2i:
	if data is Vector2i:
		return data
	if data is Dictionary:
		return Vector2i(int(data.get("x", fallback.x)), int(data.get("y", fallback.y)))
	return fallback


static func _clamp_layout_cells() -> void:
	spawn_cell = Vector2i(clampi(spawn_cell.x, 0, grid_width - 1), clampi(spawn_cell.y, 0, grid_height - 1))
	exit_cell = Vector2i(clampi(exit_cell.x, 0, grid_width - 1), clampi(exit_cell.y, 0, grid_height - 1))
	builder_cell = Vector2i(
		clampi(builder_cell.x, buildable_x_min(), buildable_x_max()),
		clampi(builder_cell.y, buildable_y_min(), buildable_y_max())
	)
	ai_label_cell = Vector2i(clampi(ai_label_cell.x, 0, grid_width - 1), clampi(ai_label_cell.y, 0, grid_height - 1))


static func _validate_config() -> void:
	if spawn_cell == exit_cell:
		push_warning("LaneCoords: spawn_cell and exit_cell must differ.")
	if spawn_cell.y >= exit_cell.y:
		push_warning("LaneCoords: spawn_cell should be above exit_cell (lower y → higher y).")
	if buildable_y_min() > buildable_y_max():
		push_warning("LaneCoords: grid too small for spawn/exit margins — increase grid_height.")
