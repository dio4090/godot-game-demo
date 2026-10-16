# A camada tipada entre os CSVs e o jogo.
#
# Um CSV chega como texto. Isto fecha a distancia ate o valor tipado sem abrir mao do que o
# CSV compra: um diff que um humano le, e nenhum arquivo derivado que possa ficar velho.
#
# A REGRA QUE FAZ ISTO VALER A PENA: NENHUM SISTEMA LE UM CSV. Os sistemas perguntam ao
# DataTables e recebem valores tipados. Sem essa regra, cada sistema cria a sua propria ideia
# do que uma coluna significa, e o mesmo numero acaba morando em dois lugares outra vez.
class_name DataTables
extends RefCounted

const DATA_DIR := "res://data/"

## Numero ausente continua null; palavra ausente vira a palavra vazia.
##
## Para um NUMERO os dois casos sao fatos diferentes: um custo ausente nao e zero, e o codigo
## que o ler como zero distribui coisa de graca em silencio. Para uma PALAVRA sao o mesmo fato
## -- "sem nota" e "" levam ao mesmo `if texto != ""` -- e `String(null)` derruba o jogo.
const WORD_TYPES := ["text", "enum", "id", "computed"]

var _schema := DataSchema.new()
# nome do arquivo -> Array[Dictionary]
var _tables: Dictionary = {}
var _errors: Array[String] = []


func _init(schema: DataSchema = null) -> void:
	if schema != null:
		_schema = schema


func errors() -> Array[String]:
	return _errors


## Carrega e tipa todas as tabelas. Falso quando algo falhou; veja `errors()`.
func load_all(data_dir: String = DATA_DIR, schema_path: String = DataSchema.SCHEMA_PATH) -> bool:
	_tables.clear()
	_errors.clear()
	if not _schema.load_from(schema_path):
		_errors.append("%s: nenhuma regra pode ser lida" % [schema_path])
		return false
	for file_name in _schema.files():
		var rows := DataSchema.read_csv(data_dir + file_name)
		if rows.is_empty():
			_errors.append("%s: vazio ou ausente" % [file_name])
			continue
		_tables[file_name] = _type_rows(file_name, rows)
	return _errors.is_empty()


## Todas as linhas de uma tabela, tipadas.
##
## AUSENCIA NUNCA E SILENCIOSA. Uma tabela que nunca foi carregada nao e uma tabela vazia: e
## uma referencia quebrada. Devolver `[]` para as duas e como um sistema inteiro passa a ser
## ignorado enquanto o jogo segue imprimindo numeros.
func rows(file_name: String) -> Array:
	if not _tables.has(file_name):
		var problem := "%s nao esta carregada -- ela esta declarada no schema.csv?" % [file_name]
		if not _errors.has(problem):
			_errors.append(problem)
		push_error(problem)
	return _tables.get(file_name, [])


## Verdadeiro quando a tabela foi carregada. "Nunca carregada" e "nao tem linhas" sao
## respostas diferentes.
func has_table(file_name: String) -> bool:
	return _tables.has(file_name)


## A unica linha cuja `column` vale `value`, ou um dicionario vazio.
##
## "Nao encontrei" e uma resposta legitima; "essa coluna nao existe" nao e, e as duas eram
## indistinguiveis antes desta checagem.
func find(file_name: String, column: String, value: Variant) -> Dictionary:
	var all := rows(file_name)
	if not all.is_empty() and not all[0].has(column):
		var problem := "%s nao tem a coluna %s" % [file_name, column]
		if not _errors.has(problem):
			_errors.append(problem)
		push_error(problem)
	for record in all:
		if record.get(column) == value:
			return record
	return {}


func _type_rows(file_name: String, rows_in: Array) -> Array:
	var rules: Dictionary = _schema.rules_for(file_name)
	var header: PackedStringArray = rows_in[0]
	var typed: Array = []
	for i in range(1, rows_in.size()):
		var row: PackedStringArray = rows_in[i]
		var record := {}
		for c in range(min(header.size(), row.size())):
			var column: String = header[c]
			var raw: String = row[c]
			if not rules.has(column):
				record[column] = raw
				continue
			record[column] = _convert(raw, rules[column])
		_compute(file_name, record)
		typed.append(record)
	_check_ids(file_name, rules, typed)
	return typed


func _convert(raw: String, rule: DataSchema.ColumnRule) -> Variant:
	if DataSchema.is_absent(raw):
		return "" if WORD_TYPES.has(rule.type) else null
	match rule.type:
		"integer":
			return int(raw)
		"decimal":
			return float(raw)
		_:
			return raw


## Avalia as colunas que o schema declara como formula, usando os valores da propria linha
## como variaveis.
##
## FORMULA DEPENDE DE FORMULA. A ordem certa e propriedade das formulas, nao do arquivo de
## schema -- entao ela e DESCOBERTA e nao declarada: passa de novo ate que uma passada nao
## calcule nada novo. Uma passada que nao calcula nada com colunas pendentes e um ciclo de
## verdade, e isso ela relata em vez de girar para sempre.
func _compute(file_name: String, record: Dictionary) -> void:
	var rules: Dictionary = _schema.rules_for(file_name)
	var pending: Array = []
	for column in rules:
		if (rules[column] as DataSchema.ColumnRule).is_computed():
			pending.append(column)
	while not pending.is_empty():
		var progressed := false
		var still: Array = []
		for column in pending:
			if _try_compute(record, rules[column], column):
				progressed = true
			else:
				still.append(column)
		pending = still
		if not progressed:
			for column in pending:
				var problem := "%s.%s: a formula nunca ficou calculavel -- variavel faltando ou ciclo" % [
					file_name, column]
				if not _errors.has(problem):
					_errors.append(problem)
					push_error(problem)
			return


## Verdadeiro quando a formula produziu um valor. Falso significa "AINDA nao da para calcular".
func _try_compute(record: Dictionary, rule: DataSchema.ColumnRule, column: String) -> bool:
	var names: Array = []
	var values: Array = []
	for key in record:
		if record[key] is float or record[key] is int:
			names.append(key)
			values.append(record[key])
	var expression := Expression.new()
	if expression.parse(rule.formula, PackedStringArray(names)) != OK:
		return false
	# `show_error` e FALSO de proposito: uma passada que ainda nao consegue calcular e o caso
	# normal enquanto as dependencias se resolvem. A falha de verdade e relatada uma vez, pelo
	# chamador, depois que as passadas param de progredir.
	var value: Variant = expression.execute(values, null, false)
	if expression.has_execute_failed():
		return false
	record[column] = value
	return true


## Uma coluna `id` tem de nomear exatamente uma linha.
func _check_ids(file_name: String, rules: Dictionary, typed: Array) -> void:
	for column in rules:
		var rule: DataSchema.ColumnRule = rules[column]
		if not rule.is_id():
			continue
		var seen := {}
		for record in typed:
			var value: Variant = record.get(column)
			if value == null:
				continue
			if seen.has(value):
				_errors.append("%s: %s \"%s\" nomeia mais de uma linha" % [
					file_name, column, value])
			seen[value] = true
