# Verifica todo CSV de `data/` contra `data/schema.csv`.
#
# Ele vem ANTES de qualquer regra de jogo, de proposito: verificacao que chega depois do
# conteudo chega tarde.
#
# Nada aqui repete um numero do jogo. Ele le o que o schema DECLARA e confere o dado contra
# isso -- entao acrescentar uma tabela nao pede uma linha de codigo nova.
class_name DataValidator
extends RefCounted

const DATA_DIR := "res://data/"
const SCHEMA := DataSchema.SCHEMA_PATH


## Devolve a lista de problemas. Vazia significa que o dado bate com o schema.
func validate(data_dir: String = DATA_DIR, schema_path: String = SCHEMA) -> Array[String]:
	var problems: Array[String] = []
	var schema := DataSchema.new()
	if not schema.load_from(schema_path):
		problems.append("%s: nenhuma regra pode ser lida" % [schema_path])
		return problems
	var rules := schema.by_file

	var dir := DirAccess.open(data_dir)
	if dir == null:
		problems.append("%s: nao consigo abrir a pasta de dados" % [data_dir])
		return problems

	var seen := {}
	for name in dir.get_files():
		if not name.ends_with(".csv") or name == "schema.csv":
			continue
		seen[name] = true
		if not rules.has(name):
			problems.append("%s: o arquivo nao tem nenhuma linha no schema" % [name])
			continue

		var rows := DataSchema.read_csv(data_dir + name)
		if rows.is_empty():
			problems.append("%s: esta vazio" % [name])
			continue

		var header: PackedStringArray = rows[0]
		var file_rules: Dictionary = rules[name]
		# As duas direcoes, e as duas importam: coluna no arquivo que o schema nao conhece, e
		# coluna que o schema declara e o arquivo nao tem.
		for column in header:
			if not file_rules.has(column):
				problems.append("%s: a coluna %s nao esta no schema" % [name, column])
		for column in file_rules:
			var rule: DataSchema.ColumnRule = file_rules[column]
			if rule.is_computed():
				continue  # calculada ao carregar, e ausente do arquivo de proposito
			if not header.has(column):
				problems.append("%s: o schema declara a coluna %s e o arquivo nao a tem" % [
					name, column])

		var seen_ids := {}
		for column in file_rules:
			if (file_rules[column] as DataSchema.ColumnRule).is_id():
				seen_ids[column] = {}

		for i in range(1, rows.size()):
			var row: PackedStringArray = rows[i]
			for c in range(min(header.size(), row.size())):
				var column: String = header[c]
				if not file_rules.has(column):
					continue
				var complaint := _check_value(row[c], file_rules[column])
				if complaint != "":
					problems.append("%s:%d: %s %s" % [name, i + 1, column, complaint])
				if seen_ids.has(column) and not DataSchema.is_absent(row[c]):
					var already: Dictionary = seen_ids[column]
					if already.has(row[c]):
						problems.append("%s:%d: %s \"%s\" tambem nomeia a linha %d" % [
							name, i + 1, column, row[c], int(already[row[c]])])
					already[row[c]] = i + 1

	for name in rules:
		if not seen.has(name):
			problems.append("%s: o schema o descreve e o arquivo nao existe" % [name])

	return problems


func _check_value(value: String, rule: DataSchema.ColumnRule) -> String:
	if DataSchema.is_absent(value):
		if rule.required:
			return "esta vazia e o schema a marca como obrigatoria"
		return ""
	match rule.type:
		"integer":
			if not value.is_valid_int():
				return "e %s, e o schema diz inteiro" % [value]
			return _check_numeric_range(float(value), rule)
		"decimal":
			if not value.is_valid_float():
				return "e %s, e o schema diz decimal" % [value]
			return _check_numeric_range(float(value), rule)
		"enum":
			if not rule.allowed_values().has(value):
				return "e %s, que nao e um de: %s" % [value, rule.range_spec]
		"text", "id":
			# `id` e texto mais unicidade, e unicidade e propriedade da TABELA e nao da celula.
			pass
		_:
			return "tem tipo desconhecido no schema: %s" % [rule.type]
	return ""


func _check_numeric_range(value: float, rule: DataSchema.ColumnRule) -> String:
	var bounds := rule.bounds()
	if bounds.is_empty():
		return ""
	if value < float(bounds[0]) or value > float(bounds[1]):
		return "e %s, fora da faixa declarada %s" % [value, rule.range_spec]
	return ""
