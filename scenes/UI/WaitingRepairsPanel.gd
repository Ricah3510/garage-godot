extends Control

signal repair_selected(repair_data)

@onready var list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ListContainer

func _ready():
	visible = false


func open(waiting_repairs: Array):
	visible = true
	refresh_list(waiting_repairs)


func close():
	visible = false
	clear_list()


func refresh_list(waiting_repairs: Array):
	clear_list()

	if waiting_repairs.is_empty():
		var label := Label.new()
		label.text = "Aucune réparation en attente"
		list_container.add_child(label)
		return

	for repair in waiting_repairs:
		list_container.add_child(create_repair_item(repair))


func clear_list():
	for child in list_container.get_children():
		child.queue_free()


func create_repair_item(repair_data: Dictionary) -> Control:
	var container := HBoxContainer.new()

	var info := Label.new()
	var voiture = repair_data.get("voiture", {})
	var modele = voiture.get("modele", "Inconnu")
	var immat = voiture.get("immatriculation", "---")
	var count = repair_data.get("interventions", []).size()

	info.text = "%s (%s) - %d interventions" % [modele, immat, count]
	container.add_child(info)

	var button := Button.new()
	button.text = "Mettre dans le garage"
	button.pressed.connect(func():
		emit_signal("repair_selected", repair_data)
	)
	container.add_child(button)

	return container


func _on_CloseButton_pressed():
	close()


func _on_close_button_pressed() -> void:
	_on_CloseButton_pressed()
