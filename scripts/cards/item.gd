class_name Item
extends Resource

var id: String
var name: String
var theme_id: String
var icon: String
var description: String

func _init(p_id: String = "", p_name: String = "", p_theme: String = "food", p_icon: String = "", p_description: String = ""):
	id = p_id
	name = p_name
	theme_id = p_theme
	icon = p_icon
	description = p_description
		
