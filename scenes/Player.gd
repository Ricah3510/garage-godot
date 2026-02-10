extends CharacterBody2D

@export var speed := 200.0
@onready var animated_sprite := $AnimatedSprite
@onready var interaction_hint := get_tree().get_root().get_node("Garage/UI/InteractionHint")
@onready var repair_panel := get_tree().get_root().get_node("Garage/UI/RepairPanel")


var last_direction := "down"
var nearby_car = null

func _ready():
	add_to_group("player")
	print("RepairPanel =", repair_panel)
	if interaction_hint:
		interaction_hint.visible = false

func _physics_process(_delta):
	var direction := Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		velocity = direction * speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

	move_and_slide()

func play_walk_animation(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		last_direction = "right" if dir.x > 0 else "left"
	else:
		last_direction = "down" if dir.y > 0 else "up"

	animated_sprite.play("walk_" + last_direction)

func play_idle_animation():
	animated_sprite.play("idle_" + last_direction)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == Key.KEY_E:
			print("E pressé")
			print("nearby_car =", nearby_car)

			if nearby_car:
				print("🧪 Player utilise Car instance_id =", nearby_car.get_instance_id())

			if nearby_car and repair_panel:
				print("Ouverture RepairPanel")
				repair_panel.show_for_car(nearby_car)


func show_interaction_hint():
	interaction_hint.visible = true

func hide_interaction_hint():
	interaction_hint.visible = false
