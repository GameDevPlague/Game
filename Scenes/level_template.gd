@tool
extends Node3D

@export var block_size = Vector3(1, 0.2, 1)

@export_group("Export")
@export_file var source_tmx_file: String = "res://TiledWorkspace/scenes/test.tmx" # 仅测试

@export_dir var output_path: String = "res://scene_lock/"
@export var filename: String = ""

# YATI 加载器实例
@export_tool_button("Export as .tscn") var exportx: Callable = generate_in_place_and_save_as


func _ready() -> void:
	print("?")
	#generate_in_place_and_save_as()


func generate_in_place_and_save_as() -> void:
	print("开始在当前场景中生成...")

	for n in $GeneratedLevel.get_children():
		n.free()

	print("清理完成")
	var level_root: Node3D = $GeneratedLevel
	level_root.owner = self
	print("已创建新节点")
	var loaded_tmx_scene: Node2D = load(source_tmx_file).instantiate()

	print("加载完成")
	if not loaded_tmx_scene:
		print_rich("[color=red]错误: 加载 TMX 文件失败: %s[/color]" % source_tmx_file)
		level_root.free()
		
		
	print("寻找墙壁和地板...")
	var floor_layer = loaded_tmx_scene.find_child("Floor")
	var wall_layer  = loaded_tmx_scene.find_child("Wall")

	print("生成地板...")
	generate_floor(floor_layer, level_root)
	print("地板创建完成")

	if wall_layer:
		print("生成墙壁...")
		generate_walls(floor_layer, wall_layer, level_root)
		print("墙壁创建完成")
	else:
		print_rich("[color=orange]警告: 未在 TMX 文件中找到 'Wall' 图层。[/color]")

	loaded_tmx_scene.free()
	print("几何体生成完毕。")
	
	var packed_scene = PackedScene.new()
	var result       = packed_scene.pack(self)
	if result == OK:
		var dir = output_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(dir)
		var error = ResourceSaver.save(packed_scene, output_path+filename+".tscn")
		if error == OK:
			print_rich("[color=green]成功! 整个场景已另存为到: %s[/color]" % output_path)
		else:
			print_rich("[color=red]错误: 保存场景文件失败，错误代码: %s[/color]" % error)
	else:
		print_rich("[color=red]错误: 打包场景节点失败，错误代码: %s[/color]" % result)
		
# --- 地板生成函数 (合并版) ---
func generate_floor(floor_layer: TileMapLayer, level_root: Node3D):

	# 寻找TileSet
	var tile_set: TileSet = floor_layer.tile_set
	if not tile_set:
		printerr("Floor layer does not have a TileSet.")
		return
	print("Start generating merged floor...")

	var used_cells = floor_layer.get_used_cells()
	if used_cells.is_empty():
		print("Floor layer has no used cells. Skipping floor generation.")
		return

	var source_id                        = floor_layer.get_cell_source_id(used_cells[0])
	var atlas_source: TileSetAtlasSource = tile_set.get_source(source_id)

	#创建 SurfaceTool，用于收集所有地板的几何数据
	#SurfaceTool可以把大量的面组成更大的面，并且速度更快
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	print("创建了新的surface")
	# 遍历所有使用到的格子，但只向SurfaceTool添加数据
	for cell_coords in used_cells:
		print("added", cell_coords)
		var atlas_coords = floor_layer.get_cell_atlas_coords(cell_coords)
		#print("added",cell_coords)
		# 计算这个方块在世界空间中的偏移量
		var block_offset = Vector3(
								cell_coords.x * block_size.x,
								-block_size.y, # 地板的顶面是0
								cell_coords.y * block_size.z
							)
		# 将单个方块的几何数据添加到共享的SurfaceTool中
		_add_floor_box_to_surface_tool(st, block_size, block_offset, atlas_source, atlas_coords)

	print("Generated Floors data for %d blocks." % used_cells.size())

	# 循环结束后，如果收集到了顶点，则创建单个的网格和物理体
	if true:
		# 为整个合并后的网格生成平滑的法线和切线
		st.generate_normals()
		st.generate_tangents()

		# 创建材质
		var material = StandardMaterial3D.new()
		material.albedo_texture = atlas_source.texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

		# 提交网格数据并应用材质
		var array_mesh = st.commit()
		array_mesh.surface_set_material(0, material)

		# 创建单个的 MeshInstance3D
		var floor_mi = MeshInstance3D.new()
		floor_mi.mesh = array_mesh
		$GeneratedLevel.add_child(floor_mi)
		floor_mi.owner = self
		floor_mi.name = "FloorMesh"

		# 创建单个的 StaticBody3D，并从网格自动生成精确的碰撞体
		floor_mi.create_trimesh_collision()
		#floor_mi.print_tree_pretty()		#floor_mi.find_child("StaticBody").owner = self

		print("Merged floor mesh created and added to the scene.")


# --- 墙壁生成函数 (合并版) ---
func generate_walls(floor_layer: TileMapLayer, wall_layer: TileMapLayer, level_root: Node3D) -> void:
	var wall_tile_set: TileSet = wall_layer.tile_set
	if not wall_tile_set:
		printerr("Wall layer does not have a TileSet.")
		return

	var used_wall_cells = wall_layer.get_used_cells()
	if used_wall_cells.is_empty():
		print("Wall layer has no used cells. Skipping wall generation.")
		return

	var wall_source_id                        = wall_layer.get_cell_source_id(used_wall_cells[0])
	var wall_atlas_source: TileSetAtlasSource = wall_tile_set.get_source(wall_source_id)
	var wall_block_size                       = Vector3(block_size.x, block_size.x, block_size.z)

	# 在循环外创建 SurfaceTool，用于收集所有墙壁的几何数据
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for cell_coords in used_wall_cells:
		var adjacent_floors: Dictionary = {
									"north": floor_layer.get_cell_source_id(cell_coords + Vector2i(0, -1)) != -1,
									"south": floor_layer.get_cell_source_id(cell_coords + Vector2i(0, 1)) != -1,
									"west": floor_layer.get_cell_source_id(cell_coords + Vector2i(-1, 0)) != -1,
									"east": floor_layer.get_cell_source_id(cell_coords + Vector2i(1, 0)) != -1
								}
		var adjacent_walls: Dictionary  = {
									"north": wall_layer.get_cell_source_id(cell_coords + Vector2i(0, -1)) != -1,
									"south": wall_layer.get_cell_source_id(cell_coords + Vector2i(0, 1)) != -1,
									"west": wall_layer.get_cell_source_id(cell_coords + Vector2i(-1, 0)) != -1,
									"east": wall_layer.get_cell_source_id(cell_coords + Vector2i(1, 0)) != -1
								}
		var wall_atlas_coords = wall_layer.get_cell_atlas_coords(cell_coords)

		# 计算这个墙壁方块在世界空间中的偏移量
		var block_offset = Vector3(
								cell_coords.x * block_size.x,
								0, # 遵循你原有的Y坐标逻辑
								cell_coords.y * block_size.z
							)

		# 将单个墙壁的可见面几何数据添加到共享的SurfaceTool中
		_add_selective_wall_to_surface_tool(st, wall_block_size, block_offset, wall_atlas_source, wall_atlas_coords, adjacent_floors, adjacent_walls)

	print("Generated Walls data for %d blocks." % used_wall_cells.size())

	if true:
		st.generate_normals()
		st.generate_tangents()

		var material = StandardMaterial3D.new()
		material.albedo_texture = wall_atlas_source.texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		

		var array_mesh = st.commit()
		array_mesh.surface_set_material(0, material)

		var wall_mi = MeshInstance3D.new()
		wall_mi.mesh = array_mesh
		# 阴影依然由一个完整的(但不可见的)方块来投射，以保证正确性
		# 我们为合并后的整个墙体创建一个大的包围盒作为阴影投射体

		$GeneratedLevel.add_child(wall_mi)
		wall_mi.owner = self
		wall_mi.name = "WallMesh"
		wall_mi.create_trimesh_collision()
		print("Merged wall mesh created and added to the scene.")


# --- 新的辅助函数，用于将单个方块的几何数据添加到现有的 SurfaceTool 中 ---

func _add_floor_box_to_surface_tool(st: SurfaceTool, size: Vector3, offset: Vector3, atlas_source: TileSetAtlasSource, atlas_coords: Vector2i):
	var atlas_texture      = atlas_source.texture
	var texture_size       = atlas_texture.get_size()
	var tile_region: Rect2 = atlas_source.get_tile_texture_region(atlas_coords)
	var uv_offset          = tile_region.position / texture_size
	var uv_size            = tile_region.size / texture_size
	var uv_zero            = Vector2(0.0, 0.0)
	var uv_a               = uv_offset
	var uv_b               = uv_offset + Vector2(uv_size.x, 0)
	var uv_c               = uv_offset + uv_size
	var uv_d               = uv_offset + Vector2(0, uv_size.y)

	# 注意，顶点坐标现在基于 `offset`，而不是(0,0,0)
	var vertices: Array[Variant] = [
									offset + Vector3(0, 0, size.z),
									offset + Vector3(size.x, 0, size.z),
									offset + Vector3(size.x, size.y, size.z),
									offset + Vector3(0, size.y, size.z),
									offset + Vector3(0, 0, 0),
									offset + Vector3(size.x, 0, 0),
									offset + Vector3(size.x, size.y, 0),
									offset + Vector3(0, size.y, 0)
									]

	# 顶面 (Y+)
	st.set_uv(uv_d); st.add_vertex(vertices[7])
	st.set_uv(uv_c); st.add_vertex(vertices[6])
	st.set_uv(uv_b); st.add_vertex(vertices[2])
	st.set_uv(uv_d); st.add_vertex(vertices[7])
	st.set_uv(uv_b); st.add_vertex(vertices[2])
	st.set_uv(uv_a); st.add_vertex(vertices[3])


# 根据需要，取消注释以添加其他面
# var uv_zero = Vector2.ZERO
# 底面 (Y-)
# st.set_uv(uv_zero); st.add_vertex(vertices[4]) ...


func _add_selective_wall_to_surface_tool(st: SurfaceTool, size: Vector3, offset: Vector3, atlas_source: TileSetAtlasSource, atlas_coords: Vector2i, adjacent_floors: Dictionary, adjacent_walls: Dictionary):
	var atlas_texture      = atlas_source.texture
	var texture_size       = atlas_texture.get_size()
	var tile_region: Rect2 = atlas_source.get_tile_texture_region(atlas_coords)
	var uv_offset          = tile_region.position / texture_size
	var uv_size            = tile_region.size / texture_size
	var uv_a               = uv_offset
	var uv_b               = uv_offset + Vector2(uv_size.x, 0)
	var uv_c               = uv_offset + uv_size
	var uv_d               = uv_offset + Vector2(0, uv_size.y)

	# 顶点坐标基于 `offset`
	var half_size     = size / 2.0
	var center_offset            = offset + size / 2.0
	var vertices: Array[Variant] = [
						center_offset + Vector3(-half_size.x, -half_size.y, half_size.z), # 0
						center_offset + Vector3( half_size.x, -half_size.y, half_size.z), # 1
						center_offset + Vector3( half_size.x, half_size.y, half_size.z), # 2
						center_offset + Vector3(-half_size.x, half_size.y, half_size.z), # 3
						center_offset + Vector3(-half_size.x, -half_size.y, -half_size.z), # 4
						center_offset + Vector3( half_size.x, -half_size.y, -half_size.z), # 5
						center_offset + Vector3( half_size.x, half_size.y, -half_size.z), # 6
						center_offset + Vector3(-half_size.x, half_size.y, -half_size.z)  # 7
						]

	# AI干脏活
	if adjacent_floors.south and (not adjacent_walls.south):
		st.set_normal(Vector3.FORWARD); st.set_uv(uv_a); st.add_vertex(vertices[0]); st.set_uv(uv_d); st.add_vertex(vertices[3]); st.set_uv(uv_c); st.add_vertex(vertices[2]); st.set_uv(uv_a); st.add_vertex(vertices[0]); st.set_uv(uv_c); st.add_vertex(vertices[2]); st.set_uv(uv_b); st.add_vertex(vertices[1])
	if adjacent_floors.north and (not adjacent_walls.north):
		st.set_normal(Vector3.BACK); st.set_uv(uv_b); st.add_vertex(vertices[5]); st.set_uv(uv_c); st.add_vertex(vertices[6]); st.set_uv(uv_d); st.add_vertex(vertices[7]); st.set_uv(uv_b); st.add_vertex(vertices[5]); st.set_uv(uv_d); st.add_vertex(vertices[7]); st.set_uv(uv_a); st.add_vertex(vertices[4])
	if adjacent_floors.west and (not adjacent_walls.west):
		st.set_normal(Vector3.LEFT); st.set_uv(uv_b); st.add_vertex(vertices[4]); st.set_uv(uv_c); st.add_vertex(vertices[7]); st.set_uv(uv_d); st.add_vertex(vertices[3]); st.set_uv(uv_b); st.add_vertex(vertices[4]); st.set_uv(uv_d); st.add_vertex(vertices[3]); st.set_uv(uv_a); st.add_vertex(vertices[0])
	if adjacent_floors.east and (not adjacent_walls.east):
		st.set_normal(Vector3.RIGHT); st.set_uv(uv_a); st.add_vertex(vertices[1]); st.set_uv(uv_d); st.add_vertex(vertices[2]); st.set_uv(uv_c); st.add_vertex(vertices[6]); st.set_uv(uv_a); st.add_vertex(vertices[1]); st.set_uv(uv_c); st.add_vertex(vertices[6]); st.set_uv(uv_b); st.add_vertex(vertices[5])

	# 顶面，根据你的代码，这里也需要生成
	# TODO:理论上这里不合适，不过在Wall_Top节点实装前只能这样了。之后实装我会亲自改这部分。
	st.set_normal(Vector3.UP)
	st.set_uv(uv_d); st.add_vertex(vertices[7]); st.set_uv(uv_c); st.add_vertex(vertices[6]); st.set_uv(uv_b); st.add_vertex(vertices[2]); st.set_uv(uv_d); st.add_vertex(vertices[7]); st.set_uv(uv_b); st.add_vertex(vertices[2]); st.set_uv(uv_a); st.add_vertex(vertices[3])
