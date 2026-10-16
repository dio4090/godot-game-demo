# O carregador: tipagem, coluna calculada e ausencia barulhenta.
#
# Repare que estes testes nao abrem janela e nao instanciam tela nenhuma. E por isso que eles
# rodam em milissegundos -- a regra vive fora da cena, de proposito.
extends GutTest

var _tables: DataTables


func before_each() -> void:
	_tables = DataTables.new()
	assert_true(_tables.load_all(), "as tabelas carregam: %s" % [_tables.errors()])


func test_numbers_arrive_typed() -> void:
	var row := _tables.find("01-units.csv", "id", "knight")
	assert_false(row.is_empty(), "o knight tem de existir")
	assert_typeof(row["hp"], TYPE_INT, "hp e inteiro, nao texto")
	assert_typeof(row["attack"], TYPE_FLOAT, "attack e decimal")


func test_the_computed_column_is_computed() -> void:
	var row := _tables.find("01-units.csv", "id", "archer")
	# 9.5 x 1.9 -- o numero NAO esta no CSV; o schema o derivou ao carregar.
	assert_almost_eq(float(row["dps"]), 18.05, 0.001, "dps = attack * attacks_per_s")


func test_a_missing_table_is_not_an_empty_one() -> void:
	# A DISTINCAO QUE COSTUMA FALTAR: "nunca carregada" nao e "nao tem linhas". Quando as duas
	# devolvem `[]`, um sistema inteiro pode ser ignorado enquanto o jogo segue imprimindo
	# numeros. Pedir `rows()` de uma tabela desconhecida registra erro e grita no console --
	# aqui o teste faz a pergunta pela porta silenciosa, que e `has_table`.
	assert_true(_tables.has_table("01-units.csv"), "uma tabela real esta carregada")
	assert_false(_tables.has_table("99-nao-existe.csv"),
		"um nome desconhecido NAO esta carregado, e perguntar tem de dizer isso")


func test_an_absent_word_is_the_empty_word() -> void:
	var row := _tables.find("02-palette.csv", "token", "ink")
	assert_typeof(row["note"], TYPE_STRING, "palavra ausente vira \"\", nunca null")
