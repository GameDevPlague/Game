extends CharacterBody3D

# 移动速度
@export var speed: float = 5.0
@export var isRunning: bool = false
# 动画播放速度 (帧/秒)
@export var animation_speed: float = 8.0

# 重力，从项目设置中获取默认值
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# 对Sprite3D节点的引用
@onready var sprite_3d: Sprite3D = $Sprite3D

# 动画帧数据
# 第1行 (帧 0-3): 向下移动 (Z轴正方向)
# 第2行 (帧 4-7): 向左移动 (X轴负方向)
# 第3行 (帧 8-11): 向右移动 (X轴正方向)
# 第4行 (帧 12-15): 向上移动 (Z轴负方向)

const ANIMATION_FRAMES: Dictionary = {
	"down": [0, 1, 2, 3],
	"left": [4, 5, 6, 7],
	"right": [8, 9, 10, 11],
	"up": [12, 13, 14, 15]
}

# 动画相关的变量
var current_animation_frames: Array = ANIMATION_FRAMES["down"]
var animation_timer: float = 0.0
var current_frame_index: int = 0
var is_moving: bool = false


func _physics_process(delta: float):
	# --- 1. 重力处理 ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- 2. 获取输入 ---
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# --- 3. 计算移动方向 ---
	# input_dir.y 的负值表示“前”，正值表示“后”
	# Godot 3D 中, -Z 是前方, +Z 是后方
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	var speedDepth := input_dir.length()
	
	isRunning = speedDepth >= 0.5
	
	# --- 4. 应用速度 ---
	if direction:
		is_moving = true
		velocity.x = direction.x * speed * speedDepth
		velocity.z = direction.z * speed * speedDepth
	else:
		is_moving = false
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# --- 5. 执行移动 ---
	move_and_slide()

	# --- 6. 更新动画 ---
	update_animation(delta, direction)


func update_animation(delta: float, move_direction: Vector3) -> void:
	if not is_moving:
		# 如果不移动，停在当前方向动画的第一帧
		sprite_3d.frame = current_animation_frames[0]
		animation_timer = 0 # 重置计时器
		return

	# --- 判断主要移动方向来选择动画 ---
	# 比较X和Z轴上的移动量哪个更大
	if abs(move_direction.x) > abs(move_direction.z):
		if move_direction.x > 0:
			set_animation_direction("right")
		else:
			set_animation_direction("left")
	else:
		if move_direction.z > 0:
			set_animation_direction("down") # 朝向 +Z
		else:
			set_animation_direction("up")   # 朝向 -Z
	if not isRunning:
		animation_speed = 4.0;
	else:
		animation_speed = 8.0
	# --- 播放动画帧 ---
	animation_timer += delta
	if animation_timer > 1.0 / animation_speed:
		animation_timer = 0
		current_frame_index = (current_frame_index + 1) % current_animation_frames.size()
		sprite_3d.frame = current_animation_frames[current_frame_index]


func set_animation_direction(direction_name: String):
	# 如果方向没变，就不用重置动画
	if current_animation_frames == ANIMATION_FRAMES[direction_name]:
		return
	
	# 如果方向变了，切换到新的动画序列并从第一帧开始
	current_animation_frames = ANIMATION_FRAMES[direction_name]
	current_frame_index = 0
	sprite_3d.frame = current_animation_frames[current_frame_index]
