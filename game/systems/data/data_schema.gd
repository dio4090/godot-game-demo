# Le `data/schema.csv` -- a UNICA declaracao do que cada coluna pode conter.
#
# Mora em `systems/` e nao em `dev/` porque DOIS consumidores precisam dele: o carregador que
# roda no jogo e o validador que roda no portao. Um leitor, dois consumidores.
class_name DataSchema
extends RefCounted

const SCHEMA_PATH := "res://data/schema.csv"
## Celula vazia e celula com um traco sao a mesma coisa: ausencia. Escolha uma convencao e
## deixe-a num lugar so, senao cada leitor inventa a sua.
const ABSENT := ["", "-"]


## Uma linha do schema: a regra de UMA coluna.
class ColumnRule:
	var file: String
	var column: String
	var type: String
	var range_spec: String
	var required: bool
	## `derivation` (coluna 6 do CSV) diz POR QUE. Isto aqui diz COMO, e o carregador executa.
	var formula: String

	func _init(row: PackedStringArray) -> void:
		file = row[0]
		column = row[1]
		type = row[2]
		range_spec = row[3]
		required = row[4] == "yes"
		formula = row[6] if row.size() > 6 else ""

	## Uma coluna com formula e CALCULADA AO CARREGAR e nunca armazenada. Numero derivado
	## guardado no CSV e o mesmo numero em dois lugares -- e os dois divergem.
	func is_computed() -> bool:
		return formula != ""

	## Uma coluna `id` e o ENDERECO da linha. Um endereco que aponta para duas linhas nao e
	## um endereco, e e por isso que a unicidade e verificada.
	func is_id() -> bool:
		return type == "id"

	## Para `enum`: os valores aceitos, separados por " | " no schema.
	func allowed_values() -> PackedStringArray:
		return range_spec.split(" | ")

	## Para numero: [minimo, maximo], ou [] quando o schema nao declarou faixa.
	func bounds() -> Array:
		var parts := range_spec.split("..")
		if parts.size() != 2:
			return []
		return [float(parts[0]), float(parts[1])]


# nome do arquivo -> nome da coluna -> ColumnRule
var by_file: Dictionary = {}


## O unico leitor de CSV do projeto. Todo mundo passa por aqui, entao a decisao sobre linha
## vazia e aspas esta num lugar so.
static func read_csv(path: String) -> Array:
	var rows := []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() > 1 or (line.size() == 1 and line[0] != ""):
			rows.append(line)
	return rows


static func is_absent(value: String) -> bool:
	return value in ABSENT


func load_from(path: String = SCHEMA_PATH) -> bool:
	by_file.clear()
	var rows := read_csv(path)
	if rows.is_empty():
		return false
	for i in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 5:
			continue
		var rule := ColumnRule.new(row)
		if not by_file.has(rule.file):
			by_file[rule.file] = {}
		by_file[rule.file][rule.column] = rule
	return not by_file.is_empty()


func rules_for(file_name: String) -> Dictionary:
	return by_file.get(file_name, {})


func files() -> Array:
	return by_file.keys()
