# A lista de unidades -- e o exemplo de uma tela que LE DADOS.
#
# Ela nao abre CSV nenhum. Recebe `DataTables` pronto, pede `Unit.all(...)` e desenha o que
# voltou. Toda a aritmetica de combate (o `dps`) ja veio calculada pelo schema; a tela nao
# recalcula nada, porque uma tela que recalcula e o mesmo numero vivendo em dois lugares.
class_name RosterScreen
extends Screen

var _rows: VBoxContainer
var _units: Array[Unit] = []


func setup(with_tokens: Tokens, tables: DataTables) -> void:
	dress(with_tokens, "UNIDADES")
	_units = Unit.all(tables)
	set_subtitle("%d linhas em 01-units.csv" % [_units.size()])

	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", int(Tokens.GAP_TIGHT))
	add_child(_rows)

	for unit in _units:
		_rows.add_child(_row_for(unit))


func _row_for(unit: Unit) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Chrome.panel(tokens))

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", int(Tokens.GAP))
	panel.add_child(line)

	var name := Label.new()
	name.text = unit.name
	name.custom_minimum_size.x = 160.0
	Chrome.write(name, tokens, 26, "gold")
	line.add_child(name)

	var role := Label.new()
	role.text = unit.role
	role.custom_minimum_size.x = 120.0
	Chrome.write(role, tokens, 20, "text_dim")
	line.add_child(role)

	var numbers := Label.new()
	# `dps` e coluna CALCULADA: ela nao existe no CSV, o schema a derivou ao carregar.
	numbers.text = "%d hp   %.1f dps" % [unit.hp, unit.dps]
	numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Chrome.write(numbers, tokens, 22, "text")
	line.add_child(numbers)

	return panel


func _place_body() -> void:
	if _rows == null:
		return  # ainda sendo construida; veja Screen._place_body
	var area := body()
	_rows.position = area.position
	_rows.size = area.size
