extends Node2D
@onready var overlay := $UI/GarageOverlay
@onready var payment_slot := $PaymentSlot
var payment_car = null
var garage_initialized := false
var waiting_repairs: Array = []
var payment_poll_timer: Timer = null
var car_waiting_payment = null
@export var car_scene: PackedScene
var pending_repairs := {}
@onready var waiting_panel := $UI/WaitingRepairsPanel
@onready var repair_panel := $UI/RepairPanel
@onready var slots_progress_ui_map := {
	"RepairSlot1": $UI/Slot1UI,
	"RepairSlot2": $UI/Slot2UI
}
const RepairSlot = preload("res://scripts/RepairSlot.gd")


func _on_voir_reparations_button_pressed():
	if waiting_repairs.is_empty():
		print("ℹ️ Aucune réparation en attente")
	
	waiting_panel.open(waiting_repairs)

func start_repair_in_slot(reparation_id: String, slot_number: int):
	print("🚀 Demande affectation réparation", reparation_id, "→ slot", slot_number)

	# 🔒 Bloquer l’UI
	overlay.show_message("🔄 Affectation de la réparation...")

	# 📡 Appel API
	VercelAPI.start_reparation(reparation_id, slot_number)

func _on_api_success(data: Dictionary):
	if data.has("message") and data.message.find("Reparation marked as complete") != -1:
		print("⏳ Réparation terminée, attente slot paiement côté serveur")
		VercelAPI.get_garage_state()


	

func _ready():
	overlay.show_message("🔄 Chargement data, attendez jusqu'a ce que je finisse...")
	#await get_tree().create_timer(2.0).timeout
	overlay.hide_overlay()
	add_to_group("garage")
	print("Garage ajouté au groupe garage")

	# Connexions API
	VercelAPI.garage_state_received.connect(_on_garage_state)
	VercelAPI.reparation_loaded.connect(_on_reparation_loaded)
	VercelAPI.api_error.connect(_on_api_error)
	VercelAPI.api_success.connect(_on_api_success)

	VercelAPI.reparation_paid.connect(_on_reparation_paid)
	#VercelAPI.reparation_paid.connect(_on_reparation_paid)

	# Chargement état global du garage
	#overlay.show_message("🔄 Recharge des données...")
	VercelAPI.get_garage_state()
	overlay.show_message("FINIT")
	overlay.hide_overlay()
	if not waiting_panel.repair_selected.is_connected(_on_repair_selected):
		waiting_panel.repair_selected.connect(_on_repair_selected)

func get_free_slot():
	for slot in get_tree().get_nodes_in_group("repair_slot"):
		if slot.name == "RepairSlot3":
			continue
		if slot.is_free():
			print("✅ Slot libre trouvé :", slot.name)
			return slot

	print("❌ Aucun slot libre")
	overlay.show_message("❌ Aucun slot de réparation disponible")
	await get_tree().create_timer(1.5).timeout
	overlay.hide_overlay()
	return null

func _on_repair_selected(repair_data: Dictionary) -> void:
	print("➡️ Demande placement réparation", repair_data.get("reparation_id"))

	var free_slot = await (get_free_slot())
	if free_slot == null:
		print("❌ Aucun slot libre")
		overlay.show_message("❌ Aucun slot libre")
		await get_tree().create_timer(1.5).timeout
		overlay.hide_overlay()
		return

	# 🔒 Bloquer l’UI
	overlay.show_message("🔄 Affectation de la réparation...")

	var reparation_id: String = repair_data.get("reparation_id")
	var slot_number: int = free_slot.slot_number

	# 📡 API = source de vérité
	VercelAPI.start_reparation(reparation_id, slot_number)

	# ✅ AJOUT : placer immédiatement la voiture côté client
	free_slot.place_car_placeholder(reparation_id)

	# ✅ mémoriser en attente de détails API
	pending_repairs[reparation_id] = free_slot

	# ✅ retirer de la waiting list
	_remove_from_waiting_list(reparation_id)

	# 🔥 LIGNE OBLIGATOIRE (MANQUANTE)
	VercelAPI.get_reparation_by_id(reparation_id)
	overlay.hide_overlay()

func _remove_from_waiting_list(reparation_id: String):
	if waiting_repairs.is_empty():
		return

	for i in range(waiting_repairs.size()):
		if waiting_repairs[i].get("reparation_id") == reparation_id:
			waiting_repairs.remove_at(i)
			print("🗑️ Réparation retirée de la liste d’attente :", reparation_id)

			# 🔐 sécurité : notifier le panel
			if waiting_panel:
				waiting_panel.refresh_list(waiting_repairs)


			return


@onready var slot1_ui = $UI/Slot1UI
@onready var slot2_ui = $UI/Slot2UI
func find_car_by_reparation_id(reparation_id: String):
	for slot in get_tree().get_nodes_in_group("repair_slot"):
		if slot.current_car and slot.current_car.reparation_id == reparation_id:
			return slot.current_car
	return null

func _on_car_progress_updated(slot):
	var car = slot.current_car
	if car == null:
		return

	# 🔄 Mise à jour UI de progression (slot)
	if slots_progress_ui_map.has(slot.name):
		slots_progress_ui_map[slot.name].update_slot(car)

	# 🔒 Mettre à jour le RepairPanel UNIQUEMENT
	if repair_panel.visible and repair_panel.current_car == car:
		repair_panel.refresh_interventions()
		repair_panel.payment_button.visible = car.is_repair_completed()






func show_payment_button_for_slot(slot):
	print("💰 Paiement DISPONIBLE pour", slot.name)
	# TODO: afficher le bouton paiement UNIQUEMENT pour ce slot


func hide_payment_button_for_slot(slot):
	print("🚫 Paiement NON disponible pour", slot.name)
	# TODO: cacher le bouton paiement UNIQUEMENT pour ce slot


func _on_api_error(message):
	if message == null:
		return
	push_error("API ERROR: " + str(message))


func _on_reparation_loaded(reparation_id: String, data: Dictionary):
	print("🔁 Détails réparation reçus :", reparation_id)

	# 🅰️ Cas 1 : réparation venant de waiting list
	if pending_repairs.has(reparation_id):
		var slot = pending_repairs[reparation_id]
		pending_repairs.erase(reparation_id)

		if slot.current_car:
			slot.current_car.initialize_from_full_api(data)
			print("✅ Détails appliqués (waiting → slot)", slot.name)
			_on_car_progress_updated(slot)
		return

	# 🅱️ Cas 2 : réparation déjà en slot (Firebase)
	var car = find_car_by_reparation_id(reparation_id)
	if car:
		car.initialize_from_full_api(data)
		print("✅ Détails appliqués (slot existant)")
		return

	# ❌ Cas anormal
	print("⚠️ Réparation introuvable :", reparation_id)




func move_car_to_payment(car):
	if car == null:
		return
	
	var slot = get_slot_of_car(car)
	if slot:
		print("🔓 Libération slot réparation côté serveur :", slot.slot_number)
		VercelAPI.free_slot(slot.slot_number)

	print("🚗 Début animation slot → paiement")

	var start_pos = car.global_position

	# 🔁 Reparentage temporaire
	var old_parent = car.get_parent()
	old_parent.remove_child(car)
	add_child(car)
	car.global_position = start_pos

	var up_position = start_pos + Vector2(0, -800)
	var target_position = payment_slot.global_position

	# 🔥 Calcul dynamique durée
	var player_speed = get_player_speed()

	var dist_up = start_pos.distance_to(up_position)
	var dist_down = up_position.distance_to(target_position)

	var duration_up = dist_up / player_speed
	var duration_down = dist_down / player_speed

	# Sécurité (éviter 0 ou trop lent)
	duration_up = clamp(duration_up, 0.3, 1.5)
	duration_down = clamp(duration_down, 0.3, 1.5)

	var tween = create_tween()

	# Phase 1 : montée
	tween.tween_property(
		car,
		"global_position",
		up_position,
		duration_up
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Phase 2 : vers paiement
	tween.tween_property(
		car,
		"global_position",
		target_position,
		duration_down
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.finished.connect(func():
		on_car_arrived_to_payment(car)
	)


func get_player_speed() -> float:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return 200.0 # fallback

	var s = player.get("speed")
	if typeof(s) == TYPE_FLOAT:
		return s

	return 200.0 # fallback sécurité


func on_car_arrived_to_payment(car):
	if car == null:
		return

	print("💰 Voiture arrivée au slot paiement")

	overlay.show_message("💳 Validation Notification ...")

	# 1️⃣ OCCUPER le slot paiement côté serveur
	#VercelAPI.occupy_payment_slot(car.reparation_id)
	# 1️⃣ OCCUPER le slot paiement côté serveur
	VercelAPI.occupy_payment_slot(car.reparation_id)
	# 2️⃣ APPELER /api/complete (UNE SEULE FOIS)
	VercelAPI.complete_reparation(car.reparation_id)
#
	## 3️⃣ Attendre paiement (polling ou event)
	start_payment_polling(car)






func on_payment_received():
	if payment_car == null:
		return

	print("✅ Paiement reçu")

	var car = payment_car
	payment_car = null

	# Position de sortie (vers le bas)
	var exit_position = car.global_position + Vector2(0, -200)

	var tween = create_tween()

	# Animation sortie
	tween.tween_property(
		car,
		"global_position",
		exit_position,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.finished.connect(func():
		car.queue_free()
		print("🚗 Voiture supprimée, slot paiement libre"))

func debug_payment_received():
	on_payment_received()

func place_car_in_payment_from_api(payment_data):
	var reparation_id = payment_data.get("reparation_id")
	if reparation_id == null:
		return

	# Déjà affichée → ne rien faire
	if payment_car and payment_car.reparation_id == reparation_id:
		return

	print("💰 Slot paiement occupé par :", reparation_id)

	var car = car_scene.instantiate()
	add_child(car)
	car.global_position = payment_slot.global_position
	car.reparation_id = reparation_id

	payment_car = car
	car_waiting_payment = car


#func _on_garage_state(data):
	#print("🔄 Reconstruction du garage (sélective)")
#
	#garage_initialized = true
#
	## --- 1️⃣ SLOTS RÉPARATION ---
	#var slots_data = data.get("slots", {})
#
	#for slot_name in slots_data.keys():
		#var slot_data = slots_data[slot_name]
#
		#var repair_slot: RepairSlot = null
		#match slot_name:
			#"slot1":
				#repair_slot = $Slots/RepairSlot1 as RepairSlot
			#"slot2":
				#repair_slot = $Slots/RepairSlot2 as RepairSlot
			#"slot3":
				#continue
			#_:
				#repair_slot = null
#
		#if repair_slot == null:
			#push_warning("Slot introuvable: " + slot_name)
			#continue
#
		## 🟢 CAS A — SLOT VIDE CÔTÉ API
		#if slot_data == null:
			#if repair_slot.current_car != null:
				## ⚠️ Ne jamais casser une intervention en cours
				#if repair_slot.current_car.is_repairing:
					#print("⏳ Slot", slot_name, "conservé (intervention en cours)")
				#else:
					#print("🧹 Slot", slot_name, "libéré")
					#repair_slot.clear_slot()
			#continue
#
		## 🟢 CAS B — SLOT OCCUPÉ CÔTÉ API
		#var api_reparation_id = slot_data.get("reparation_id")
#
		## Si la bonne voiture est déjà là → ne rien faire
		#if repair_slot.current_car \
		#and repair_slot.current_car.reparation_id == api_reparation_id:
			#continue
#
		## Si une autre voiture est là MAIS intervention en cours → ne pas toucher
		#if repair_slot.current_car \
		#and repair_slot.current_car.is_repairing:
			#print("⏳ Intervention en cours, slot préservé :", slot_name)
			#continue
#
		## Sinon → remplacer / créer
		#print("➡️ Placement réparation", api_reparation_id, "dans", slot_name)
		#repair_slot.clear_slot()
		#repair_slot.place_car_from_api(slot_data)
		#repair_slot.current_car.intervention_completed.connect(_on_intervention_completed)
#
		## Charger les détails complets (durées, prix, etc.)
		#if api_reparation_id != null:
			#VercelAPI.get_reparation_by_id(api_reparation_id)
#
	## --- 2️⃣ SLOT PAIEMENT ---
	#var payment_data = data.get("payment_slot")
	#if payment_data != null:
		#print("💰 Placement voiture au slot paiement")
		#place_car_in_payment_from_api(payment_data)
#
	## --- 3️⃣ WAITING LIST ---
	#waiting_repairs = data.get("waiting_repairs", [])
	#print("📋 Réparations en attente =", waiting_repairs.size())
#
	## --- 4️⃣ FIN : cacher l’overlay ---
	#overlay.hide_overlay()

func _on_garage_state(data):
	print("🔥 _on_garage_state CALLED")
	print("📦 DATA =", data)
	print("🧪 slots =", data.get("slots"), {})
	print("🔄 Reconstruction du garage (sélective)")

	garage_initialized = true

	# =========================
	# 1️⃣ SLOTS RÉPARATION
	# =========================
	var slots_data = data.get("slots", {})

	for slot_name in slots_data.keys():
		var slot_data = slots_data[slot_name]

		var repair_slot: RepairSlot = null
		match slot_name:
			"slot1":
				repair_slot = $Slots/RepairSlot1 as RepairSlot
				print("🔎 Slot reçu :", slot_name)
			"slot2":
				repair_slot = $Slots/RepairSlot2 as RepairSlot
				print("🔎 Slot reçu :", slot_name)
			"slot3":
				continue # ❗ slot3 = paiement, géré plus bas
			_:
				continue

		if repair_slot == null:
			continue

		# 🟢 CAS A — SLOT VIDE CÔTÉ API
		if slot_data == null:
			if repair_slot.current_car != null:
				# ⚠️ Ne jamais casser une intervention en cours
				if repair_slot.current_car.is_repairing:
					print("⏳ Slot", slot_name, "conservé (intervention en cours)")
				else:
					print("🧹 Slot", slot_name, "libéré par backend")
					repair_slot.clear_slot()
			continue

		# 🟢 CAS B — SLOT OCCUPÉ CÔTÉ API
		var api_reparation_id = slot_data.get("reparation_id")

		# Si la bonne voiture est déjà là → ne rien faire
		if repair_slot.current_car \
		and repair_slot.current_car.reparation_id == api_reparation_id:
			continue

		# Si une autre voiture est là MAIS intervention en cours → ne pas toucher
		if repair_slot.current_car \
		and repair_slot.current_car.is_repairing:
			print("⏳ Intervention en cours, slot préservé :", slot_name)
			continue

		# Sinon → remplacer / créer
		print("➡️ Placement réparation", api_reparation_id, "dans", slot_name)
		repair_slot.clear_slot()
		repair_slot.place_car_from_api(slot_data)

		if repair_slot.current_car:
			repair_slot.current_car.intervention_completed.connect(_on_intervention_completed)

		# Charger les détails complets (durées, prix, etc.)
		if api_reparation_id != null:
			VercelAPI.get_reparation_by_id(api_reparation_id)

	# =========================
# 2️⃣ SLOT PAIEMENT
# =========================
	var payment_data = data.get("payment_slot")

	if payment_data != null:
		print("💰 Slot paiement occupé côté serveur")
		place_car_in_payment_from_api(payment_data)
	else:
		# 🔓 Slot paiement libéré côté backend
		if payment_car != null:
			print("🧹 Slot paiement libéré par backend")
			payment_car.queue_free()
			payment_car = null
			car_waiting_payment = null

	# =========================
	# 3️⃣ WAITING LIST
	# =========================
	waiting_repairs = data.get("waiting_repairs", [])
	print("📋 Réparations en attente =", waiting_repairs.size())

	# =========================
	# 4️⃣ FIN
	# =========================
	overlay.hide_overlay()



func _on_intervention_completed(reparation_id: String, intervention_name: String) -> void:
	print("📡 API → intervention terminée :", intervention_name)

	VercelAPI.complete_intervention(
		reparation_id,
		intervention_name
	)


func _on_voir_réparations_pressed() -> void:
	_on_voir_reparations_button_pressed()

func start_payment_polling(car):
	car_waiting_payment = car

	if payment_poll_timer == null:
		payment_poll_timer = Timer.new()
		payment_poll_timer.wait_time = 5.0
		payment_poll_timer.autostart = true
		payment_poll_timer.timeout.connect(_check_payment_status)
		add_child(payment_poll_timer)

	payment_poll_timer.start()

func _check_payment_status():
	if car_waiting_payment == null:
		return

	VercelAPI.get_reparation_status(car_waiting_payment.reparation_id)

func _on_reparation_paid(_data):
	print("✅ Paiement confirmé côté serveur")

	overlay.show_message("✅ Paiement reçu")

	# 🛑 arrêter le polling
	if payment_poll_timer:
		payment_poll_timer.stop()

	# 🚗 animation de sortie (VISUELLE UNIQUEMENT)
	if payment_car:
		animate_car_exit(payment_car)

	# 🔓 libérer slot paiement côté backend
	VercelAPI.free_payment_slot()

	# 🔄 resync global (SOURCE DE VÉRITÉ)
	VercelAPI.get_garage_state()


func animate_car_exit(car):
	if car == null:
		return

	print("🚗 Sortie de la voiture du slot paiement")

	var exit_position = car.global_position + Vector2(0, -300)

	var tween = create_tween()
	tween.tween_property(
		car,
		"global_position",
		exit_position,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)




	
func get_slot_of_car(car) -> Node:
	if car == null:
		return null

	for slot in get_tree().get_nodes_in_group("repair_slot"):
		if slot.current_car == car:
			return slot

	return null

func clear_payment_slot():
	if car_waiting_payment == null:
		return

	print("🧹 Libération slot paiement")

	car_waiting_payment.queue_free()
	car_waiting_payment = null
