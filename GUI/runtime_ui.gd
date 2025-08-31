extends Control
#TODO: 只是测试，WIP
@export var time:int = 0
func onPress() -> void:
	time += 30
	print("im pressed")
	$Label.text = str(time/60)+":"+str(time%60)
func _ready() -> void:
	$Button.pressed.connect(onPress)
