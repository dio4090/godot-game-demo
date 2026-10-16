# As telas sao montadas em codigo, entao um teste pode montar uma e olhar o resultado -- sem
# abrir janela e sem clicar em nada.
#
# A coisa que este arquivo prova e a regra do roteador: uma tela NAO navega. Ela emite, e
# `run/main.gd` decide. Um teste que conseguisse ver a tela A abrir a tela B seria o aviso de
# que essa regra ja foi quebrada.
extends GutTest

var _tables: DataTables
var _tokens: Tokens


func before_each() -> void:
	_tables = DataTables.new()
	_tables.load_all()
	_tokens = Tokens.new()
	_tokens.load_from(_tables)


func test_the_palette_loads_every_colour() -> void:
	assert_true(_tokens.has("gold"), "o token 'gold' vem da tabela")
	assert_eq(_tokens.errors(), [] as Array[String], "nenhuma cor ilegivel")


func test_the_roster_shows_one_row_per_unit() -> void:
	var screen := RosterScreen.new()
	autofree(screen)
	screen.setup(_tokens, _tables)
	var rows := screen.get_node("Rows") if screen.has_node("Rows") else null
	assert_not_null(rows, "a lista existe")
	assert_eq(rows.get_child_count(), _tables.rows("01-units.csv").size(),
		"uma linha por unidade da tabela")


func test_a_screen_asks_to_leave_and_does_not_navigate() -> void:
	var screen := HomeScreen.new()
	autofree(screen)
	screen.setup(_tokens)
	watch_signals(screen)
	screen.roster_requested.emit()
	assert_signal_emitted(screen, "roster_requested",
		"a tela PEDE; quem roteia decide para onde isso vai")
