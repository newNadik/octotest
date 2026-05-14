extends PanelContainer
class_name SubtitleDisplay

@onready var _label: Label = $SubtitleMargin/SubtitleLabel

var _hide_timer: SceneTreeTimer


func _ready() -> void:
	add_to_group("subtitle_display")
	hide()


func show_line(text: String, duration: float) -> void:
	var settings := get_node_or_null("/root/GameSettings")
	var subtitles_on := true
	if settings != null and settings.has_method("get_subtitles_enabled"):
		subtitles_on = bool(settings.call("get_subtitles_enabled"))
	var is_ua := TranslationServer.get_locale().begins_with("uk")
	if not subtitles_on and not is_ua:
		return
	_label.text = text
	show()
	if _hide_timer != null and _hide_timer.timeout.is_connected(_on_hide_timer):
		_hide_timer.timeout.disconnect(_on_hide_timer)
	_hide_timer = get_tree().create_timer(duration)
	_hide_timer.timeout.connect(_on_hide_timer)


func _on_hide_timer() -> void:
	hide()
