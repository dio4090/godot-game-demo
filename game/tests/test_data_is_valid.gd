# O MESMO VALIDADOR DO PORTAO, dentro da suite.
#
# Ele roda nos dois lugares de proposito: o portao barra o commit, e a suite falha enquanto
# voce ainda esta escrevendo. Quem so tem o portao descobre tarde.
extends GutTest


func test_the_data_matches_the_schema() -> void:
	var problems := DataValidator.new().validate()
	assert_eq(problems, [] as Array[String], "o dado tem de bater com o schema")
