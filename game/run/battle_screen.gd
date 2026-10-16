# A TELA DA BATALHA, e repare no tamanho da regra que ela contem: nenhuma.
#
# Quem decide quem bate, quanto tira e quando acaba e `systems/combat/battle.gd`. Esta classe
# chama `advance(delta)`, le `hero_fraction()` e desenha. Se voce procurar aqui um numero de
# dano ou uma condicao de vitoria, nao vai achar -- e esse e o ponto.
#
# E quando acaba, ela NAO navega: emite `ended` e fica parada. Quem decide o que vem depois de
# uma vitoria e `run/main.gd`.
class_name BattleScreen
extends Screen

## A batalha terminou. `true` quando o heroi venceu.
signal ended(hero_won: bool)

## O CENARIO, e ele esta em codigo de proposito -- por enquanto.
##
## A regra do projeto manda todo dado para um CSV, e um caminho de arte de UMA tela ainda nao e
## dado: e uma decisao desta tela, que so tem um cenario. No dia em que houver biomas, isto vira
## coluna numa tabela de fases junto com o inimigo que mora la, e esta constante desaparece. Ate
## la, uma tabela de uma linha so seria cerimonia.
const BACKDROP := "res://art/scenery/arena.png"

## Quanto tempo o alvo fica vermelho depois de apanhar.
const FLASH := 0.12
## Segundos por quadro da animacao parada. Quatro quadros numa folha de 1024x256.
const FRAME_TIME := 0.15
const FRAMES := 4


## Um lado da tela: o boneco, o nome e a barra. Classe interna porque nada fora deste arquivo
## precisa dela -- e uma peca que dois lugares usassem viraria um arquivo em `common/`.
class Fighter:
	var root: Control
	var sprite: Sprite2D
	var name_label: Label
	var bar: ProgressBar
	var hp_label: Label
	var flash: float = 0.0

	func hit() -> void:
		flash = FLASH

	## Devolve a cor que o boneco deve ter agora. A tela aplica; o lutador so conta o tempo.
	func fade(delta: float) -> void:
		if flash <= 0.0:
			return
		flash = maxf(0.0, flash - delta)
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.4, 0.45), flash / FLASH)


var _battle: Battle
var _hero: Fighter
var _enemy: Fighter
var _verdict: Label
var _clock: Label
var _frame_time: float = 0.0
var _hero_unit: Unit
var _enemy_unit: Unit


func setup(with_tokens: Tokens, tables: DataTables) -> void:
	dress(with_tokens, "BATALHA")
	set_backdrop(BACKDROP)
	_hero_unit = Unit.first_of_side(tables, "hero")
	_enemy_unit = Unit.first_of_side(tables, "enemy")

	_hero = _build_fighter(_hero_unit)
	_enemy = _build_fighter(_enemy_unit)

	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.write(_clock, tokens, 20, "text_dim")
	add_child(_clock)

	_verdict = Label.new()
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.visible = false
	Chrome.write(_verdict, tokens, 56, "gold")
	add_child(_verdict)

	set_process(false)


## Comeca uma batalha NOVA. Chamada pelo roteador toda vez que a tela e aberta -- uma tela que
## guardasse a batalha anterior mostraria um cadaver na segunda entrada.
func start() -> void:
	_battle = Battle.new(_hero_unit, _enemy_unit)
	_verdict.visible = false
	_hero.sprite.modulate = Color.WHITE
	_enemy.sprite.modulate = Color.WHITE
	_refresh()
	set_process(true)


func _process(delta: float) -> void:
	if _battle == null or _battle.is_over():
		return  # terminada: nada anima, e o esmaecido do perdedor fica como esta
	_animate(delta)
	_hero.fade(delta)
	_enemy.fade(delta)

	for blow in _battle.advance(delta):
		(_hero if blow.target_is_hero else _enemy).hit()
	_refresh()

	if _battle.is_over():
		set_process(false)
		_verdict.text = "VITÓRIA" if _battle.hero_won() else "DERROTA"
		_verdict.visible = true
		# QUEM CAIU TEM DE PARECER CAIDO. Sem isto os dois continuam em pe, piscando a mesma
		# animacao parada, e a tela depende do texto para dizer o que o desenho ja deveria.
		var loser: Fighter = _enemy if _battle.hero_won() else _hero
		loser.sprite.modulate = Color(0.45, 0.45, 0.5, 0.55)
		# A TELA AVISA E PARA. Ela nao abre a proxima coisa, nao soma recompensa e nao salva
		# nada -- quem faz isso e quem escutar este sinal.
		ended.emit(_battle.hero_won())


func _build_fighter(unit: Unit) -> Fighter:
	var f := Fighter.new()
	f.root = Control.new()
	f.root.name = unit.id
	f.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f.root)

	f.sprite = Sprite2D.new()
	# AUSENCIA TRATADA, e nao assumida: `sprite` e coluna opcional no schema, entao uma unidade
	# sem folha desenha so a barra em vez de derrubar a tela.
	if unit.sprite != "" and ResourceLoader.exists(unit.sprite):
		f.sprite.texture = load(unit.sprite)
		f.sprite.hframes = FRAMES
	f.root.add_child(f.sprite)

	f.name_label = Label.new()
	f.name_label.text = unit.name
	f.name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.write(f.name_label, tokens, 28, "gold")
	f.root.add_child(f.name_label)

	f.bar = ProgressBar.new()
	f.bar.max_value = 1.0
	f.bar.value = 1.0
	f.bar.show_percentage = false
	f.bar.add_theme_stylebox_override("background", Chrome.panel(tokens, "ink"))
	var fill := Chrome.panel(tokens, "danger")
	f.bar.add_theme_stylebox_override("fill", fill)
	f.root.add_child(f.bar)

	f.hp_label = Label.new()
	f.hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.write(f.hp_label, tokens, 22, "text")
	f.root.add_child(f.hp_label)
	return f


## Um acumulador e um resto: quatro quadros em loop, sem AnimationPlayer e sem SpriteFrames.
## Para uma animacao parada de quatro quadros, qualquer coisa alem disto e cerimonia.
func _animate(delta: float) -> void:
	_frame_time += delta
	var frame := int(_frame_time / FRAME_TIME) % FRAMES
	_hero.sprite.frame = frame
	_enemy.sprite.frame = frame


func _refresh() -> void:
	if _battle == null:
		return
	_hero.bar.value = _battle.hero_fraction()
	_enemy.bar.value = _battle.enemy_fraction()
	_hero.hp_label.text = "%d / %d" % [ceili(_battle.hero_hp), _hero_unit.hp]
	_enemy.hp_label.text = "%d / %d" % [ceili(_battle.enemy_hp), _enemy_unit.hp]
	_clock.text = "%.1f s" % [_battle.elapsed]


func _place_body() -> void:
	if _hero == null:
		return  # ainda sendo construida; veja Screen._place_body
	var area := body()
	var half := area.size.x / 2.0
	_place_fighter(_hero, Rect2(area.position, Vector2(half, area.size.y)))
	_place_fighter(_enemy, Rect2(
		Vector2(area.position.x + half, area.position.y), Vector2(half, area.size.y)))

	_clock.position = Vector2(area.position.x, area.position.y)
	_clock.size = Vector2(area.size.x, 24.0)
	_verdict.position = Vector2(area.position.x, area.position.y + area.size.y / 2.0 - 40.0)
	_verdict.size = Vector2(area.size.x, 80.0)


func _place_fighter(f: Fighter, slot: Rect2) -> void:
	f.root.position = slot.position
	f.root.size = slot.size
	var inner: float = min(slot.size.x - Tokens.GAP * 2.0, 320.0)
	var x := (slot.size.x - inner) / 2.0

	f.name_label.position = Vector2(x, 40.0)
	f.name_label.size = Vector2(inner, 36.0)
	# O Sprite2D desenha a partir do CENTRO, e nao do canto como um Control -- por isso a
	# metade aqui. Trocar os dois e o bug de layout mais comum de quem mistura 2D com UI.
	f.sprite.position = Vector2(slot.size.x / 2.0, slot.size.y / 2.0)
	f.bar.position = Vector2(x, slot.size.y - 90.0)
	f.bar.size = Vector2(inner, 28.0)
	f.hp_label.position = Vector2(x, slot.size.y - 56.0)
	f.hp_label.size = Vector2(inner, 28.0)
