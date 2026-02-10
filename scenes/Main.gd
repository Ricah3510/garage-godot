extends Node2D


func _ready():
	VercelAPI.garage_state_received.connect(_on_garage_state)
	VercelAPI.api_error.connect(_on_api_error)

	VercelAPI.get_garage_state()

func _on_garage_state(data):
	print("📦 GARAGE STATE =")
	print(data)

func _on_api_error(msg):
	push_error(msg)
