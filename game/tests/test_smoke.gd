# Prova que a suite roda sem janela antes de existir qualquer regra de jogo.
#
# E o primeiro teste de um projeto, e nao o ultimo: um arnes que so e montado depois que ha
# codigo e um arnes que ninguem usa enquanto escreve o codigo.
extends GutTest


func test_the_data_folder_is_readable() -> void:
	var file := FileAccess.open("res://data/01-units.csv", FileAccess.READ)
	assert_not_null(file, "a tabela de unidades tem de ser legivel")


func test_the_schema_exists() -> void:
	var schema := DataSchema.new()
	assert_true(schema.load_from(), "o schema.csv tem de carregar")
