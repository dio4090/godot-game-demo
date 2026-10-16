# A camada de regra, testada sem cena, sem janela e sem arquivo.
extends GutTest

var _tables: DataTables


func before_each() -> void:
	_tables = DataTables.new()
	_tables.load_all()


func test_every_row_becomes_a_unit() -> void:
	var units := Unit.all(_tables)
	assert_eq(units.size(), 3, "tres linhas na tabela, tres unidades")
	assert_eq(units[0].id, "knight", "a ordem do arquivo e preservada")


func test_seconds_to_kill() -> void:
	var knight := Unit.from_row(_tables.find("01-units.csv", "id", "knight"))
	var archer := Unit.from_row(_tables.find("01-units.csv", "id", "archer"))
	# O cavaleiro derruba o arqueiro antes de cair: o arqueiro bate mais, e o cavaleiro tem
	# vida demais para isso resolver. O teste afirma a RELACAO e nao o numero exato -- o numero
	# e decisao de balanceamento e vai mudar na primeira semana.
	assert_lt(knight.seconds_to_kill(archer), archer.seconds_to_kill(knight),
		"num 1v1 o tanque ganha do dano puro")
	assert_gt(archer.dps, knight.dps, "mas e o arqueiro quem tem o dps mais alto")


func test_no_damage_is_infinity_and_not_a_lie() -> void:
	var dummy := Unit.new()
	dummy.dps = 0.0
	assert_eq(dummy.seconds_to_kill(dummy), INF, "sem dano, a resposta honesta e INF")
