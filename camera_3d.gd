extends Camera3D

var pan_speed = 5.0
var zoom_speed = 2.0

func _input(event):
	# 鼠标拖拽移动
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		position -= Vector3(event.relative.x, 0, event.relative.y) * 0.05
	
	# 滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = max(size - zoom_speed, 5)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size += zoom_speed
