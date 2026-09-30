extends Control
## The final ledger is supplied by Main, so kills and friendly casualties stay distinct.
const Style := preload("res://scripts/ui/ui_style.gd")

var _rows: Array[Label] = []
var _commendation: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var captions := ["Invaders defeated", "Enemies crushed", "Biggest fold", "Duels won", "Folds made", "Keep strength"]
	for i in captions.size():
		var label := Style.label(captions[i], Rect2(0, i * 29, 182, 28), 13)
		add_child(label)
		var value := Style.label("0", Rect2(184, i * 29, 72, 28), 14)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(value)
		_rows.append(value)
	_commendation = Style.label("", Rect2(0, 188, 256, 50), 21, Style.BLUE, true)
	_commendation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_commendation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_commendation)


func show_report(report: Dictionary) -> void:
	var biggest := int(report.get("biggest_fold", 0))
	var won := bool(report.get("won", false))
	var duels := int(report.get("duels_won", 0))
	var hp := int(report.get("keep_hp", 0))
	var maximum := int(report.get("keep_max_hp", 10))
	var values := [str(report.get("kills", 0)), str(report.get("crushed", 0)),
		"%d %s" % [biggest, "kill" if biggest == 1 else "kills"],
		"%d/%d" % [duels, int(report.get("duels_fought", 0))],
		str(report.get("folds", 0)), "%d/%d" % [hp, maximum]]
	for i in _rows.size():
		_rows[i].text = values[i]
	if won and hp == maximum:
		_commendation.text = "The Unbroken Keep"
	elif biggest >= 5:
		_commendation.text = "Master of the Fold"
	elif duels >= 2:
		_commendation.text = "Champion of the Keep"
	else:
		_commendation.text = "Keeper of the Realm" if won else "A defiant last stand"
	queue_redraw()


func _draw() -> void:
	Style.rule(self, 180, 0, 256)
