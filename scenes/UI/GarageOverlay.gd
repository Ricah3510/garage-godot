extends Control

@onready var message_label: Label = $CenterContainer/Panel/MessageLabel


func show_message(text: String):
	message_label.text = text
	visible = true


func hide_overlay():
	visible = false
