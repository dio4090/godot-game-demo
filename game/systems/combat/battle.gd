# UMA BATALHA 1x1, e ela nao sabe que existe uma tela.
#
# Esta e a peca que prova por que `systems/` e separado de `run/`. A batalha inteira -- quem
# bate, quando, quanto, e quando acabou -- esta aqui, num `RefCounted` sem no de cena, sem
# `_process`, sem desenho e sem input. A tela chama `advance(delta)` e desenha o que voltou.
#
# TRES CONSEQUENCIAS, e cada uma e um problema que nao existe:
#
#   o teste roda sem janela e em milissegundos -- `tests/test_battle.gd` simula a luta inteira
#   a batalha pode ser simulada mil vezes para medir balanceamento, sem abrir o jogo
#   trocar a tela nao arrisca a regra, e mexer na regra nao quebra a tela
#
# O DIA EM QUE ISTO VIRAR UM `Node` COM `_process`, as tres somem de uma vez.
class_name Battle
extends RefCounted

## Um golpe que acabou de acontecer. A tela usa para piscar o alvo; a regra ja aplicou o dano.
class Blow:
	var attacker: Unit
	var target: Unit
	var amount: float
	var target_is_hero: bool

	func _init(by: Unit, on: Unit, damage: float, on_hero: bool) -> void:
		attacker = by
		target = on
		amount = damage
		target_is_hero = on_hero

## TETO DE PASSO. Um quadro que demorou meio segundo -- a janela foi arrastada, o sistema
## engasgou -- nao pode virar meia dezena de golpes de uma vez. Sem este teto a batalha
## ACELERA quando o jogo trava, que e o contrario do que qualquer um espera ver.
const MAX_STEP := 0.1

var hero: Unit
var enemy: Unit
var hero_hp: float
var enemy_hp: float
var elapsed: float = 0.0

var _hero_cooldown: float = 0.0
var _enemy_cooldown: float = 0.0


func _init(with_hero: Unit, with_enemy: Unit) -> void:
	hero = with_hero
	enemy = with_enemy
	hero_hp = float(hero.hp)
	enemy_hp = float(enemy.hp)
	# O PRIMEIRO GOLPE NAO E NO INSTANTE ZERO. Cada lado espera o proprio intervalo antes de
	# bater pela primeira vez, senao quem tem mais ataques por segundo leva vantagem duas
	# vezes: na frequencia e na largada.
	_hero_cooldown = _interval(hero)
	_enemy_cooldown = _interval(enemy)


func is_over() -> bool:
	return hero_hp <= 0.0 or enemy_hp <= 0.0


## Quem venceu, ou `null` enquanto a batalha corre. Empate -- os dois caem no mesmo passo --
## conta como derrota do heroi, que e a leitura severa e a unica que nao premia o jogador por
## um arredondamento.
func winner() -> Unit:
	if not is_over():
		return null
	return hero if hero_hp > 0.0 else enemy


func hero_won() -> bool:
	return is_over() and hero_hp > 0.0


## A fracao de vida restante, 0..1 -- o que uma barra desenha.
func hero_fraction() -> float:
	return clampf(hero_hp / float(hero.hp), 0.0, 1.0)


func enemy_fraction() -> float:
	return clampf(enemy_hp / float(enemy.hp), 0.0, 1.0)


## Avanca a batalha em `delta` segundos e devolve os golpes que aconteceram nesse intervalo.
##
## Devolver os golpes em vez de emitir sinal e deliberado: quem chama decide o que fazer com
## eles, e um simulador que roda mil batalhas nao paga por sinal nenhum.
func advance(delta: float) -> Array[Blow]:
	var blows: Array[Blow] = []
	if is_over():
		return blows
	var step: float = minf(delta, MAX_STEP)
	elapsed += step

	_hero_cooldown -= step
	_enemy_cooldown -= step

	# OS DOIS GOLPES DO MESMO PASSO ACONTECEM, mesmo que o primeiro mate. Um moribundo que ja
	# ergueu a espada acerta -- e e isso que torna o empate possivel. A alternativa (parar no
	# meio do passo) faria o vencedor depender da ORDEM EM QUE ESTE ARQUIVO ESTA ESCRITO, que
	# e a pior coisa que uma regra de combate pode depender.
	if _hero_cooldown <= 0.0 and hero_hp > 0.0:
		_hero_cooldown += _interval(hero)
		enemy_hp = maxf(0.0, enemy_hp - hero.attack)
		blows.append(Blow.new(hero, enemy, hero.attack, false))
	if _enemy_cooldown <= 0.0 and enemy_hp > 0.0:
		_enemy_cooldown += _interval(enemy)
		hero_hp = maxf(0.0, hero_hp - enemy.attack)
		blows.append(Blow.new(enemy, hero, enemy.attack, true))

	return blows


## Segundos entre dois golpes. INF para quem nao ataca -- e `_cooldown -= step` nunca chega a
## zero a partir de INF, entao um lado sem ataque simplesmente nunca bate, em vez de dividir
## por zero.
func _interval(unit: Unit) -> float:
	if unit.attacks_per_s <= 0.0:
		return INF
	return 1.0 / unit.attacks_per_s
