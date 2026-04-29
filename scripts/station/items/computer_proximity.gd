extends Area3D

const SCREENSAVER_DELAY := 45.0

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SCREENSAVER_DELAY
	_timer.timeout.connect(_on_screensaver_timeout)
	add_child(_timer)
	body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node3D) -> void:
	_set_black_screen(false)
	_timer.start()

func _on_screensaver_timeout() -> void:
	_set_black_screen(true)

func _set_black_screen(is_visible: bool) -> void:
	var screen := get_parent().get_node_or_null("Node3D/Monitor_2/black_screen") as Node3D
	if screen:
		screen.visible = is_visible
