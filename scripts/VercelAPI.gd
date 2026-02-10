extends Node

const BASE_URL := "https://garage-notifications.vercel.app"

signal garage_state_received(data)
signal reparation_loaded(reparation_id, data)
signal api_error(message)
signal api_success(data)
signal reparation_paid(data)

var http: HTTPRequest

# ✅ Queue unifiée (GET + POST)
var request_queue: Array[Dictionary] = []
var is_requesting := false


# ------------------------
# INIT
# ------------------------

func _ready():
	print("✅ VercelAPI singleton READY")

	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)


# ------------------------
# QUEUE SYSTEM
# ------------------------

func _enqueue_request(method: int, url: String, body := ""):
	var headers: Array[String] = []

	if method == HTTPClient.METHOD_POST:
		headers = ["Content-Type: application/json"]

	request_queue.append({
		"method": method,
		"url": url,
		"headers": headers,
		"body": body
	})

	_process_queue()


func _process_queue():
	if is_requesting:
		return
	if request_queue.is_empty():
		return

	var req: Dictionary = request_queue.pop_front()
	is_requesting = true

	print("➡️ API", req["method"], req["url"])

	http.request(
		req["url"],
		req["headers"],
		req["method"],
		req["body"]
	)


# ------------------------
# API CALLS
# ------------------------

func get_garage_state():
	var url = BASE_URL + "/api/garage/state"
	print("🌐 GET", url)
	_enqueue_request(HTTPClient.METHOD_GET, url)


func get_reparation_by_id(reparation_id: String):
	var url = BASE_URL + "/api/reparations/" + reparation_id
	print("🌐 GET", url)
	_enqueue_request(HTTPClient.METHOD_GET, url)


func start_reparation(reparation_id: String, slot_number: int):
	var url = BASE_URL + "/api/reparations/start"
	var body = JSON.stringify({
		"reparation_id": reparation_id,
		"slot": slot_number
	})

	print("➡️ API POST", url, body)
	_enqueue_request(HTTPClient.METHOD_POST, url, body)


func complete_intervention(reparation_id: String, intervention_name: String):
	var url = BASE_URL + "/api/interventions/complete"
	var body = JSON.stringify({
		"reparation_id": reparation_id,
		"intervention_name": intervention_name
	})

	print("➡️ API POST", url, body)
	_enqueue_request(HTTPClient.METHOD_POST, url, body)


func complete_reparation(reparation_id: String):
	#var url = BASE_URL + "/api/reparations/complete"
	var url = BASE_URL + "/api/complete"
	var body = JSON.stringify({
		"reparation_id": reparation_id
	})

	print("➡️ API POST", url, body)
	_enqueue_request(HTTPClient.METHOD_POST, url, body)

func get_reparation_status(reparation_id: String):
	var url = BASE_URL + "/api/reparations/status?id=" + reparation_id
	print("🌐 GET", url)
	_enqueue_request(HTTPClient.METHOD_GET, url)

func free_slot(slot_number: int):
	var url = BASE_URL + "/api/slots/update"
	var body = JSON.stringify({
		"slot_number": slot_number,
		"action": "free"
	})

	print("➡️ API POST", url, body)
	_enqueue_request(HTTPClient.METHOD_POST, url, body)

# ------------------------
# CALLBACK HTTP
# ------------------------

func _on_request_completed(_result, response_code, _headers, body):
	print("🟢 CALLBACK HTTP reçu, code =", response_code)

	is_requesting = false

	if response_code == 0:
		print("⚠️ HTTP aborted")
		_process_queue()
		return
	if response_code == 500:
		print("❌ ERREUR SERVEUR (500) — réparation NON complétée")
		emit_signal("api_error", "Erreur serveur, paiement non validé")
		_process_queue()
		return

	if response_code < 200 or response_code >= 300:
		emit_signal("api_error", "HTTP error code: " + str(response_code))
		_process_queue()
		return

	#var text := body.get_string_from_utf8()\
	var text: String = body.get_string_from_utf8()
	print("🧪 RAW response =", text)

	var json = JSON.parse_string(text)
	if json == null:
		emit_signal("api_error", "Invalid JSON response")
		_process_queue()
		return

	print("🧪 JSON parsed =", json)

	if json.has("slots"):
		print("📦 garage_state_received")
		emit_signal("garage_state_received", json)

	elif json.has("reparation_id"):
		print("📦 reparation_loaded :", json["reparation_id"])
		emit_signal("reparation_loaded", json["reparation_id"], json)

	elif json.has("success") and json["success"] == true:
		print("✅ API success")
		emit_signal("api_success", json)
	elif json.has("status") and json["status"] == "payee":
		emit_signal("reparation_paid", json)


	else:
		print("⚠️ Réponse API inconnue")

	_process_queue()

func _on_api_success(data):
	if data.has("message") and data.message.find("Reparation marked as complete") != -1:
		print("✅ Réparation confirmée côté serveur")
		# Maintenant seulement :
		VercelAPI.get_garage_state()
		
func occupy_payment_slot(reparation_id: String):
	var url = BASE_URL + "/api/slots/update"
	var body = JSON.stringify({
		"slot_number": 3,
		"action": "occupy",
		"reparation_id": reparation_id
	})

	print("➡️ API POST", url, body)
	_enqueue_request(HTTPClient.METHOD_POST, url, body)

func free_payment_slot():
	var url = BASE_URL + "/api/slots/update"
	var body = JSON.stringify({
		"slot_number": 3,
		"action": "free"
	})

	print("➡️ API POST", url, body)
	_enqueue_request(HTTPClient.METHOD_POST, url, body)
