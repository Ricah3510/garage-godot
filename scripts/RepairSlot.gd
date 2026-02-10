class_name RepairSlot
extends Node2D

@export var slot_number: int = 1
@export var car_scene: PackedScene

var current_car = null


func is_free() -> bool:
	return current_car == null


# =========================
# Placement normal
# =========================
func place_car(car):
	clear_slot()

	current_car = car
	add_child(car)
	car.position = Vector2.ZERO

	_connect_car_to_garage(car)

	print("🚗 Voiture placée dans le slot", slot_number)


# =========================
# Placeholder (UX immédiate)
# =========================
func place_car_placeholder(reparation_id: String):
	if car_scene == null:
		push_error("❌ car_scene non assignée dans " + name)
		return

	# ❗ NE PAS clear_slot ici : le backend décidera
	if current_car != null:
		return

	var car = car_scene.instantiate()
	current_car = car
	add_child(car)
	car.position = Vector2.ZERO

	car.reparation_id = reparation_id
	car.is_repairing = false # 🔥 PAS encore en réparation

	_connect_car_to_garage(car)

	print("🚗 Placeholder voiture placé dans", name)


# =========================
# Placement depuis API
# =========================
func place_car_from_api(data: Dictionary):
	print("🚗 place_car_from_api CALLED", data)

	var reparation_id = data.get("reparation_id")

	# 🔁 Remplacer le placeholder si présent
	if current_car != null:
		if current_car.reparation_id == reparation_id:
			print("🔁 Remplacement placeholder par voiture API")
			current_car.queue_free()
			current_car = null
		else:
			push_warning("Slot %d occupé par une autre voiture" % slot_number)
			return

	var car = car_scene.instantiate()
	place_car(car)

	car.initialize_from_api(data)


# =========================
# Nettoyage
# =========================
func clear_slot():
	if current_car:
		current_car.queue_free()
		current_car = null


# =========================
# Connexion UI
# =========================
func _connect_car_to_garage(car):
	var garage = get_tree().get_first_node_in_group("garage")
	if garage:
		if not car.progress_updated.is_connected(garage._on_car_progress_updated):
			car.progress_updated.connect(garage._on_car_progress_updated.bind(self))

		garage._on_car_progress_updated(self)
