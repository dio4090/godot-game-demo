# O PONTO DE ENTRADA, e a unica coisa que ele faz e decidir qual tela o jogador esta vendo.
#
# A ORDEM DO `_ready` NAO E ARBITRARIA: dados, paleta, telas. Nenhuma tela pode ser construida
# antes da paleta, porque ela pede cor por nome no momento em que monta seus controles. E a
# paleta vem de uma tabela, entao os dados vem antes dela. Se os dados nao carregam, o jogo
# PARA aqui e diz por que -- abrir uma tela sobre dados quebrados so adia o erro para um lugar
# onde ele nao se explica.
#
# NAO HA TROCA DE CENA, e isso e deliberado e nao pendente. Toda tela aqui e um `Control`
# montado em codigo e alternado por `visible`. Um roteador que trocasse de cena teria de
# reconstruir as tabelas e a paleta a cada ida e volta -- custo real, ganho nenhum que o
# jogador perceba. Quando o projeto crescer e uma tela ficar pesada, ai sim ela vira cena
# propria; a decisao fica aqui, num arquivo, e nao espalhada por quinze.
extends Control

var _tables: DataTables
var _tokens: Tokens

var _home: HomeScreen
var _roster: RosterScreen
var _battle: BattleScreen


func _ready() -> void:
	_tables = DataTables.new()
	if not _tables.load_all():
		push_error("os dados nao carregaram: %s" % [_tables.errors()])
		return

	_tokens = Tokens.new()
	if not _tokens.load_from(_tables):
		push_error("a paleta nao carregou: %s" % [_tokens.errors()])
		return

	_home = HomeScreen.new()
	_home.name = "Home"
	_home.setup(_tokens)
	add_child(_home)
	_home.roster_requested.connect(_show_roster)
	_home.battle_requested.connect(_show_battle)

	_roster = RosterScreen.new()
	_roster.name = "Roster"
	_roster.setup(_tokens, _tables)
	add_child(_roster)
	_roster.left.connect(_show_home)

	_battle = BattleScreen.new()
	_battle.name = "Battle"
	_battle.setup(_tokens, _tables)
	add_child(_battle)
	_battle.left.connect(_show_home)
	# O QUE ACONTECE DEPOIS DE UMA VITORIA E DECISAO DAQUI, nao da tela de batalha. Hoje e so
	# uma linha no console; amanha e recompensa, save e proxima fase -- e o lugar onde isso vai
	# ser escrito ja existe, que e metade do trabalho.
	_battle.ended.connect(func(hero_won: bool) -> void:
		print("batalha terminada: ", "vitoria" if hero_won else "derrota"))

	_show_home()


## A unica funcao que liga e desliga tela. Enquanto ela for a unica, "quem esta visivel" e uma
## pergunta com uma resposta; no dia em que duas funcoes mexerem em `visible`, nao e mais.
func _show(screen: Screen) -> void:
	for child in get_children():
		if child is Screen:
			child.visible = child == screen


func _show_home() -> void:
	_show(_home)


func _show_roster() -> void:
	_show(_roster)


## A batalha e RECOMECADA a cada entrada. Uma tela que guardasse a anterior mostraria o
## resultado velho por um quadro, e o jogador veria o cadaver antes da luta.
func _show_battle() -> void:
	_show(_battle)
	_battle.start()
