extends Control

@export var slot_name: String = "Slot"

var car = null

@onready var title_label: Label = $SlotTitle
@onready var name_label: Label = $Panel/VBoxContainer/InterventionName
@onready var intervention_bar: ProgressBar = $Panel/VBoxContainer/InterventionProgress
@onready var total_bar: ProgressBar = $Panel/VBoxContainer/TotalProgress
@onready var time_left_label: Label = $Panel/VBoxContainer/TimeLeftLabel


func _ready():
	title_label.text = slot_name
	reset_ui()


# Appelée depuis Garage
func update_slot(new_car):
	car = new_car

	if car == null:
		reset_ui()
		return

	# 🔌 Connexions (une seule fois)
	if not car.intervention_progress.is_connected(_on_intervention_progress):
		car.intervention_progress.connect(_on_intervention_progress)

	if not car.total_progress.is_connected(_on_total_progress):
		car.total_progress.connect(_on_total_progress)

	if not car.intervention_changed.is_connected(_on_intervention_changed):
		car.intervention_changed.connect(_on_intervention_changed)

	# Affichage initial
	name_label.text = car.get_current_intervention_name()
	intervention_bar.value = car.get_current_intervention_progress()
	total_bar.value = car.get_total_progress_percent()
	
	if not car.intervention_time_left.is_connected(_on_intervention_time_left):
		car.intervention_time_left.connect(_on_intervention_time_left)


func _on_intervention_time_left(seconds_left: int):
	time_left_label.text = "Temps restant : " + format_time(seconds_left)


func format_time(seconds: int) -> String:
	if seconds < 0:
		return "--:--"

	var m := seconds / 60
	var s := seconds % 60
	return "%02d:%02d" % [m, s]

func reset_ui():
	name_label.text = "Aucune intervention"
	intervention_bar.value = 0
	total_bar.value = 0
	time_left_label.text = "Temps restant : --:--"


func _on_intervention_changed(name: String):
	name_label.text = name
	intervention_bar.value = 0


func _on_intervention_progress(progress: float):
	animate_progress(intervention_bar, progress * 100.0)


func _on_total_progress(progress: float):
	animate_progress(total_bar, progress * 100.0)

func animate_progress(bar: ProgressBar, target_value: float):
	var tween := create_tween()
	tween.tween_property(
		bar,
		"value",
		target_value,
		0.25 # animation douce
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
