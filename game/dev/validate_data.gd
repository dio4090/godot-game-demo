# Chamado pelo portao: godot --headless --path game -s res://dev/validate_data.gd
# Sai com 2 em caso de falha -- o codigo que barra o commit.
extends SceneTree

func _init() -> void:
	var problems := DataValidator.new().validate()
	for problem in problems:
		printerr("  dados: ", problem)
	if problems.is_empty():
		print("os dados batem com o schema")
		quit(0)
	else:
		printerr("\n%d problema(s)" % [problems.size()])
		quit(2)
