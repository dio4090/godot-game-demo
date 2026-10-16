# A batalha inteira, simulada sem abrir janela.
#
# Estes testes sao a prova pratica da separacao entre `systems/` e `run/`: eles rodam a luta
# do inicio ao fim, milhares de passos, em milissegundos. Se a regra morasse dentro da tela,
# cada um deles precisaria instanciar uma cena, esperar quadros de verdade e ainda assim
# mediria o desenho junto com a regra.
extends GutTest

const STEP := 1.0 / 60.0
## Teto de passos: 60 segundos simulados. Um `while not is_over()` sem teto vira suite travada
## no dia em que alguem puser `attacks_per_s` zero nos dois lados.
const MAX_STEPS := 3600

var _tables: DataTables
var _hero: Unit
var _enemy: Unit


func before_each() -> void:
	_tables = DataTables.new()
	_tables.load_all()
	_hero = Unit.first_of_side(_tables, "hero")
	_enemy = Unit.first_of_side(_tables, "enemy")


## Roda ate acabar e devolve quantos passos levou (-1 quando estourou o teto).
func _run_to_end(battle: Battle) -> int:
	for i in MAX_STEPS:
		battle.advance(STEP)
		if battle.is_over():
			return i + 1
	return -1


func test_a_battle_begins_whole() -> void:
	var battle := Battle.new(_hero, _enemy)
	assert_false(battle.is_over(), "ninguem ganhou antes do primeiro passo")
	assert_null(battle.winner(), "e nao ha vencedor enquanto corre")
	assert_eq(battle.hero_fraction(), 1.0, "o heroi comeca inteiro")
	assert_eq(battle.enemy_fraction(), 1.0, "o inimigo tambem")


func test_a_battle_ends() -> void:
	var battle := Battle.new(_hero, _enemy)
	assert_gt(_run_to_end(battle), 0, "a batalha tem de terminar dentro do teto")
	assert_true(battle.is_over(), "e terminar significa terminar")
	assert_not_null(battle.winner(), "com um vencedor")


func test_the_example_battle_is_short_enough_to_watch() -> void:
	# O CONTEUDO TAMBEM E VERIFICADO, e nao so o motor. Os numeros de `01-units.csv` existem
	# para caber numa demonstracao: se alguem triplicar a vida do inimigo, isto falha e diz
	# por que, em vez de deixar a tela de exemplo levar um minuto.
	var battle := Battle.new(_hero, _enemy)
	_run_to_end(battle)
	assert_between(battle.elapsed, 3.0, 20.0,
		"a batalha de exemplo tem de durar alguns segundos, nao um minuto")


func test_the_hero_wins_the_example_battle() -> void:
	var battle := Battle.new(_hero, _enemy)
	_run_to_end(battle)
	assert_true(battle.hero_won(), "a luta de exemplo e vencivel")
	assert_eq(battle.winner(), _hero, "e quem ganha e o heroi")


func test_damage_lands_on_the_other_side() -> void:
	var battle := Battle.new(_hero, _enemy)
	var blows: Array[Battle.Blow] = []
	for i in MAX_STEPS:
		blows = battle.advance(STEP)
		if not blows.is_empty():
			break
	assert_false(blows.is_empty(), "alguem tem de bater em algum momento")
	var blow: Battle.Blow = blows[0]
	assert_ne(blow.attacker, blow.target, "ninguem bate em si mesmo")
	assert_gt(blow.amount, 0.0, "um golpe tira alguma coisa")


func test_a_finished_battle_stays_finished() -> void:
	var battle := Battle.new(_hero, _enemy)
	_run_to_end(battle)
	var hp_at_the_end := battle.hero_hp
	assert_eq(battle.advance(STEP), [] as Array[Battle.Blow],
		"depois do fim nao ha mais golpe")
	assert_eq(battle.hero_hp, hp_at_the_end, "nem dano")


func test_a_unit_that_cannot_attack_never_attacks() -> void:
	# O caso que dividiria por zero. A resposta e INF, e um intervalo infinito simplesmente
	# nunca vence -- entao o inofensivo apanha ate cair, sem travar e sem crashar.
	var harmless := Unit.new()
	harmless.hp = 50
	harmless.attack = 10.0
	harmless.attacks_per_s = 0.0
	var battle := Battle.new(harmless, _enemy)
	assert_gt(_run_to_end(battle), 0, "a batalha termina mesmo assim")
	assert_false(battle.hero_won(), "quem nao ataca nao ganha")


func test_the_step_is_capped() -> void:
	# Um quadro de meio segundo nao pode valer meia duzia de golpes: a batalha aceleraria
	# justamente quando o jogo engasga.
	var slow := Battle.new(_hero, _enemy)
	slow.advance(10.0)
	assert_almost_eq(slow.elapsed, Battle.MAX_STEP, 0.0001,
		"um passo gigante conta como o passo maximo")
