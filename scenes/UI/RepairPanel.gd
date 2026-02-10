extends Control

var current_car = null

@onready var interventions_list := $Panel/VBoxContainer/InterventionsList
@onready var payment_button := $Panel/VBoxContainer/PaymentButton


func _ready():
	visible = false


func show_for_car(car):
	current_car = car
	visible = true

	refresh_interventions()

	# 🔐 recalcul STRICT basé sur CETTE voiture
	payment_button.visible = car != null and car.is_repair_completed()


func _on_interventions_updated(interventions):
	print("🔄 RepairPanel rafraîchi après chargement API :", interventions)
	refresh_interventions()



func refresh_interventions():
	if current_car == null:
		return

	# Nettoyer la liste
	for child in interventions_list.get_children():
		child.queue_free()

	# ⚠️ CAS IMPORTANT : interventions pas encore chargées
	if current_car.interventions.is_empty():
		var loading_label = Label.new()
		loading_label.text = "Chargement des interventions..."
		interventions_list.add_child(loading_label)
		return

	# ❌ AVANT : logique OK mais déclenchée trop tôt
	# if current_car.is_repair_completed():

	# ✅ MAINTENANT : OK car interventions non vides
	if current_car.is_repair_completed():
		var done_label = Label.new()
		done_label.text = "Toutes les interventions sont terminées"
		interventions_list.add_child(done_label)

		# ✅ Le bouton paiement devient visible ICI
		payment_button.visible = true
		return

	# Recréer les items
	for i in range(current_car.interventions.size()):
		var intervention = current_car.interventions[i]

		var hbox = HBoxContainer.new()

		# Nom + état
		var label = Label.new()
		var status = "✔" if intervention["completed"] else "✖"
		label.text = "%s %s" % [status, intervention["name"]]
		hbox.add_child(label)

		# Bouton Démarrer
		var button = Button.new()
		button.text = "Démarrer"

		if current_car.can_start_intervention(i):
			button.disabled = false
			button.pressed.connect(func():
				current_car.start_intervention(i)
				hide_panel()
			)
		else:
			button.disabled = true

		hbox.add_child(button)
		interventions_list.add_child(hbox)



# ❌ FONCTION REDONDANTE
# Elle est correcte, mais tu ne l’utilises pas ici.
# Tu peux la garder pour plus tard (stats, debug, etc.)
func are_all_interventions_done(interventions: Array) -> bool:
	if interventions.is_empty():
		return false # vide ≠ terminé

	for intervention in interventions:
		if intervention.get("completed") == false:
			return false

	return true



func _on_payment_button_pressed():
	print("💰 Bouton paiement cliqué")
	print("current_car =", current_car)
	var car_to_move = current_car
	hide_panel()
	get_tree().call_group("garage", "move_car_to_payment", car_to_move)



func hide_panel():
	visible = false
	current_car = null



func _on_button_pressed() -> void:
	hide_panel()
