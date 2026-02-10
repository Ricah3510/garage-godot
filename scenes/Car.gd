extends StaticBody2D

@export var car_texture: Texture2D
@onready var sprite := $Sprite

# ------------------------------------
# SIGNAUX
# ------------------------------------

# ❌ Ancien signal trop vague (gardé pour compat)
# signal progress_updated(intervention_progress, total_progress)
signal progress_updated
signal intervention_time_left(seconds_left: int)
signal repair_completed(car)
signal intervention_completed(reparation_id: String, intervention_name: String)
signal interventions_updated(interventions)

# ✅ NOUVEAUX SIGNAUX TEMPS RÉEL (CLÉS)
signal intervention_progress(progress) # 0.0 → 1.0
signal total_progress(progress)        # 0.0 → 1.0
signal intervention_changed(name)

# ------------------------------------
# ÉTAT
# ------------------------------------
var progress_tick_accumulator := 0.0
const PROGRESS_TICK_INTERVAL := 1.0 # secondes

var player_near := false
var player_ref = null

var intervention_elapsed := 0.0
var reparation_id := ""
var voiture_data := {}

var current_intervention_index := -1
var is_repairing := false

#var total_progress: float = 0.0
var total_progress_value: float = 0.0

var repair_completed_emitted := false

var interventions: Array = []
var interventions_loaded := false


# ------------------------------------
# INITIALISATION API
# ------------------------------------

func initialize_from_full_api(data: Dictionary):
	print("📦 Initialisation COMPLÈTE (FROM FULL API) depuis API")
	print("📦 API -> Car instance_id =", get_instance_id())

	reparation_id = data.get("reparation_id", reparation_id)
	voiture_data = data.get("voiture", voiture_data)

	interventions.clear()
	for intervention in data.get("interventions", []):
		interventions.append({
			"name": intervention.get("name", ""),
			"duration": intervention.get("duree_secondes", 0),
			"price": intervention.get("prix", 0),
			"completed": intervention.get("completed", false)
		})

	print("✅ Interventions chargées :", interventions)
	interventions_loaded = true
	emit_signal("progress_updated")
	emit_signal("interventions_updated", interventions)

	recalculate_progress_from_interventions()


func initialize_from_api(data: Dictionary):
	print("🧩 Initialisation Car depuis API")

	reparation_id = data.get("reparation_id", "")
	voiture_data = data.get("voiture", {})
	print("🚘 Voiture:", voiture_data)

	# ❌ DANGEREUX : ne JAMAIS toucher aux interventions ici
	# interventions.clear()
	# emit_signal("interventions_updated", interventions)

	recalculate_progress_from_interventions()


# ------------------------------------
# PROGRESSION GLOBALE
# ------------------------------------

func recalculate_progress_from_interventions():
	var total := interventions.size()
	if total == 0:
		return

	var completed := 0
	for i in interventions:
		if i["completed"]:
			completed += 1

	total_progress_value = float(completed) / total * 100.0
	print("📊 Progression totale :", total_progress, "%")

	# ❌ Ancien signal non exploitable
	# emit_signal("progress_updated")

	# ✅ NOUVEAU : signal propre pour l’UI
	emit_signal("total_progress", total_progress_value / 100.0)

	# 🔒 EMISSION UNE SEULE FOIS À 100 %
	if completed == total and not repair_completed_emitted:
		repair_completed_emitted = true
		emit_signal("repair_completed", self)


# ------------------------------------
# READY
# ------------------------------------

func _ready():
	add_to_group("car")
	print("🚗 Car READY | instance_id =", get_instance_id())
	print("Car READY (sans reset), interventions =", interventions)


# ------------------------------------
# INTERACTION PLAYER
# ------------------------------------

func _on_interaction_area_body_entered(body):
	if body.name == "Player":
		player_near = true
		body.nearby_car = self
		body.show_interaction_hint()
		print("Player proche de la voiture | Car id =", get_instance_id())


func _on_interaction_area_body_exited(body):
	if body.name == "Player":
		player_near = false
		body.nearby_car = null
		body.hide_interaction_hint()
		print("Player s'éloigne de la voiture")


# ------------------------------------
# LOGIQUE MÉTIER
# ------------------------------------

func interact():
	if is_repairing:
		print("Une intervention est déjà en cours")
		return

	var next_index = get_next_intervention_index()
	if next_index == -1:
		print("Toutes les interventions sont terminées")
		return

	start_intervention(next_index)


func get_next_intervention_index():
	for i in range(interventions.size()):
		if interventions[i]["completed"] == false:
			return i
	return -1


func start_intervention(index):
	current_intervention_index = index
	is_repairing = true
	intervention_elapsed = 0.0
	progress_tick_accumulator = 0.0

	var intervention = interventions[index]
	print("▶️ Démarrage intervention :", intervention["name"], "(", intervention["duration"], "s )")

	# ✅ SIGNAL DÉBUT (UI)
	emit_signal("intervention_changed", intervention["name"])
	emit_signal("intervention_progress", 0.0)
	# ✅ NOUVEAU : durée initiale
	emit_signal("intervention_time_left", int(intervention["duration"]))
# ------------------------------------
# TEMPS RÉEL (CŒUR DU FIX)
# ------------------------------------

func _process(delta):
	# ❌ pas en réparation
	if not is_repairing:
		return

	# ❌ interventions pas encore chargées
	if interventions.is_empty():
		return

	# ❌ index invalide
	if current_intervention_index < 0 or current_intervention_index >= interventions.size():
		return

	intervention_elapsed += delta
	progress_tick_accumulator += delta

	var intervention = interventions[current_intervention_index]
	var duration = max(intervention["duration"], 0.001)

	var progress: float = clamp(intervention_elapsed / duration, 0.0, 1.0)

	# ⏱️ Émettre toutes les 1 seconde
	if progress_tick_accumulator >= PROGRESS_TICK_INTERVAL:
		progress_tick_accumulator = 0.0

		emit_signal("intervention_progress", progress)

		var seconds_left: int = int(ceil(duration - intervention_elapsed))
		seconds_left = max(seconds_left, 0)

		emit_signal("intervention_time_left", seconds_left)
		emit_signal("progress_updated")

	if intervention_elapsed >= duration:
		complete_current_intervention()





#func complete_current_intervention():
	#if current_intervention_index < 0:
		#return
#
	#var intervention = interventions[current_intervention_index]
	#intervention["completed"] = true
#
	#print("✅ Intervention terminée :", intervention["name"])
#
	## 🔄 Recalcul centralisé
	#recalculate_progress_from_interventions()
#
	#is_repairing = false
	#current_intervention_index = -1
func complete_current_intervention():
	if current_intervention_index < 0:
		return

	var intervention = interventions[current_intervention_index]
	intervention["completed"] = true

	print("✅ Intervention terminée :", intervention["name"])
	
	# 🔔 NOUVEAU : prévenir le Garage
	emit_signal(
		"intervention_completed",
		reparation_id,
		intervention["name"]
	)
	# ✅ CORRECTION : forcer l’UI à 00:00
	emit_signal("intervention_time_left", 0)
	emit_signal("intervention_progress", 1.0)

	recalculate_progress_from_interventions()

	is_repairing = false
	current_intervention_index = -1



# ------------------------------------
# GETTERS (UTILISÉS PAR UI)
# ------------------------------------

func get_total_progress():
	var total = interventions.size()
	var completed = 0

	for intervention in interventions:
		if intervention["completed"]:
			completed += 1

	if total == 0:
		return 100

	return int((completed / float(total)) * 100)


func is_repair_completed():
	if interventions.is_empty():
		return false

	for intervention in interventions:
		if intervention["completed"] == false:
			return false
	return true


func can_start_intervention(index):
	if is_repairing:
		return false
	return interventions[index]["completed"] == false


func get_current_intervention_progress():
	if not is_repairing:
		return 0

	var intervention = interventions[current_intervention_index]
	return int((intervention_elapsed / intervention["duration"]) * 100)


func get_total_progress_percent():
	return get_total_progress()


func get_current_intervention_name():
	if not is_repairing or current_intervention_index == -1:
		return "Aucune intervention en cours"

	return interventions[current_intervention_index]["name"]


func has_active_intervention():
	return is_repairing
