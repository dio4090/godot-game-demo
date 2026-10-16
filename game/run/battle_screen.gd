# A TELA DA BATALHA, e repare no tamanho da regra que ela contem: nenhuma.
#
# Quem decide quem bate, quanto tira e quando acaba e `systems/combat/battle.gd`. Esta classe
# chama `advance(delta)`, le `hero_fraction()` e desenha. Se voce procurar aqui um numero de
# dano ou uma condicao de vitoria, nao vai achar -- e esse e o ponto.
#
# TUDO QUE ESTA AQUI E APARENCIA: a folha de sprite que esta tocando, o passo a frente do
# golpe, o vermelho de quem apanhou. Nada disso altera a luta. A prova e direta -- apague este
# arquivo inteiro e `tests/test_battle.gd` continua passando, com o mesmo vencedor e o mesmo
# tempo.
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


## Um lado da tela: o boneco, o nome e a barra -- e tudo que o boneco faz enquanto a regra
## resolve a luta em outro arquivo.
##
## Classe interna porque nada fora daqui precisa dela. Uma peca que dois lugares usassem viraria
## um arquivo em `common/`; uma que so um usa e ruido se virar arquivo.
class Fighter:
	## Quatro quadros numa tira de 1024x256, nas duas folhas.
	const FRAMES := 4
	## Segundos por quadro da animacao parada.
	const IDLE_FRAME := 0.15
	## Quanto dura o golpe inteiro: a folha de ataque toca uma vez e o passo vai e volta.
	##
	## Tem de caber FOLGADO no intervalo entre dois golpes do lutador mais rapido, senao a
	## animacao ainda estaria correndo quando a proxima comeca e o boneco nunca voltaria ao
	## lugar. O mais rapido desta demo bate a cada 1,1 s; isto e um terco disso.
	const STRIKE := 0.36
	## Quantos pixels o lutador avanca na investida. Uma fracao curta da distancia entre os
	## dois: ele AMEACA o outro, nao chega nele -- dois bonecos que se encostam viram um borrao.
	const LUNGE := 120.0
	## Quanto tempo o alvo fica vermelho depois de apanhar.
	const FLASH := 0.12
	## A cor do golpe, e ela PASSA DE 1 nos tres canais de proposito.
	##
	## `modulate` MULTIPLICA a textura. Um vermelho "normal" como (1, 0.4, 0.45) escurece tudo
	## que nao e vermelho -- o bicho verde-azulado virava uma silhueta preta, que o olho le como
	## sombra e nao como dor. Multiplicar por mais de 1 estoura o canal e CLAREIA: o alvo fica
	## lavado de vermelho claro, que e o que uma pancada parece.
	const FLASH_TINT := Color(2.2, 0.9, 0.95)

	var root: Control
	var sprite: Sprite2D
	var name_label: Label
	var bar: ProgressBar
	var hp_label: Label

	var idle_sheet: Texture2D
	## Pode ser `null`: o schema deixa `sprite_attack` ausente, e entao o golpe e so o passo a
	## frente com a folha parada. Ausencia tratada, e nao presumida.
	var attack_sheet: Texture2D

	## Para que lado este lutador avanca: +1 direita, -1 esquerda.
	##
	## ELE DECIDE O ESPELHAMENTO TAMBEM, e e por isso que e um numero e nao um booleano. A arte
	## deste projeto e desenhada OLHANDO PARA A DIREITA -- o cavaleiro estoca para a direita, a
	## garra do bicho se estende para a direita. Quem luta da direita da tela precisa olhar para
	## a esquerda, e e o mesmo fato: avanca para a esquerda, logo esta espelhado. Antes disto o
	## inimigo lutava de costas para o heroi.
	var facing: float = 1.0
	## Onde o boneco fica quando nao esta golpeando. Definido pelo layout, nao pela animacao.
	var home: Vector2 = Vector2.ZERO

	var _idle_time: float = 0.0
	var _strike_left: float = 0.0
	var _flash_left: float = 0.0
	## Quanto falta ate o vermelho COMECAR. Veja `hit`.
	var _flash_wait: float = 0.0

	## O lutador golpeou AGORA. A regra ja aplicou o dano; isto e so o corpo acompanhando.
	func strike() -> void:
		_strike_left = STRIKE

	## O lutador apanhou. O vermelho nao comeca agora: comeca no AUGE da investida de quem
	## bateu, que e meio golpe depois.
	##
	## A regra resolve o dano num instante -- `advance` devolve o golpe e a vida ja caiu. A
	## animacao leva 0,36 s para contar a mesma coisa, e piscar no instante zero fazia o alvo
	## reagir enquanto o atacante ainda estava saindo do lugar: dois bonecos a meia tela de
	## distancia, um deles ja com dor. O olho le isso como erro mesmo sem saber nomear.
	func hit() -> void:
		_flash_wait = STRIKE * 0.5

	## Volta ao estado de quem ainda nao lutou.
	func reset() -> void:
		_strike_left = 0.0
		_flash_left = 0.0
		_flash_wait = 0.0
		sprite.modulate = Color.WHITE
		sprite.texture = idle_sheet
		sprite.position = home

	## Um quadro de animacao. Tudo que muda de aparencia passa por aqui, entao nao ha dois
	## lugares decidindo onde o boneco esta.
	func tick(delta: float) -> void:
		sprite.flip_h = facing < 0.0
		if _flash_wait > 0.0:
			_flash_wait = maxf(0.0, _flash_wait - delta)
			if _flash_wait == 0.0:
				_flash_left = FLASH
		_flash_left = maxf(0.0, _flash_left - delta)
		sprite.modulate = Color.WHITE.lerp(FLASH_TINT, _flash_left / FLASH)

		if _strike_left > 0.0:
			_strike_left = maxf(0.0, _strike_left - delta)
			# `t` vai de 0 (comeco do golpe) a 1 (fim), e os dois usos abaixo saem dele -- um
			# relogio so para a folha e para o passo, que e o que os mantem juntos.
			var t: float = 1.0 - _strike_left / STRIKE
			if attack_sheet != null:
				sprite.texture = attack_sheet
			sprite.frame = clampi(int(t * FRAMES), 0, FRAMES - 1)
			# sin(PI*t) vale 0 nas pontas e 1 no meio: sai, chega no auge do golpe e volta --
			# uma expressao no lugar de uma maquina de estados de ida e de volta.
			sprite.position = home + Vector2(facing * LUNGE * sin(PI * t), 0.0)
			return

		sprite.texture = idle_sheet
		sprite.position = home
		_idle_time += delta
		sprite.frame = int(_idle_time / IDLE_FRAME) % FRAMES


var _battle: Battle
var _hero: Fighter
var _enemy: Fighter
var _verdict: Label
var _clock: Label
var _hero_unit: Unit
var _enemy_unit: Unit


func setup(with_tokens: Tokens, tables: DataTables) -> void:
	dress(with_tokens, "BATALHA")
	set_backdrop(BACKDROP)
	_hero_unit = Unit.first_of_side(tables, "hero")
	_enemy_unit = Unit.first_of_side(tables, "enemy")

	_hero = _build_fighter(_hero_unit)
	_hero.facing = 1.0
	_enemy = _build_fighter(_enemy_unit)
	_enemy.facing = -1.0

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
	_hero.reset()
	_enemy.reset()
	_refresh()
	set_process(true)


func _process(delta: float) -> void:
	if _battle == null:
		return
	_hero.tick(delta)
	_enemy.tick(delta)
	if _battle.is_over():
		return

	# UM GOLPE DA REGRA VIRA DUAS ANIMACOES: quem bateu avanca, quem apanhou pisca. A tela nao
	# sabe quanto doeu e nao precisa saber.
	for blow in _battle.advance(delta):
		if blow.target_is_hero:
			_enemy.strike()
			_hero.hit()
		else:
			_hero.strike()
			_enemy.hit()
	_refresh()

	if _battle.is_over():
		_finish()


func _finish() -> void:
	var won := _battle.hero_won()
	_verdict.text = "VITÓRIA" if won else "DERROTA"
	_verdict.visible = true

	# O VENCEDOR VOLTA PARA O LUGAR. Sem isto ele congela no meio da investida, no quadro em que
	# estava quando o outro caiu -- de espada no ar e fora do proprio pe.
	var winner: Fighter = _hero if won else _enemy
	var loser: Fighter = _enemy if won else _hero
	winner.reset()
	# E QUEM CAIU TEM DE PARECER CAIDO. Sem isto os dois continuam em pe piscando a mesma
	# animacao, e a tela depende do texto para dizer o que o desenho ja deveria.
	loser.sprite.modulate = Color(0.45, 0.45, 0.5, 0.55)

	set_process(false)
	# A TELA AVISA E PARA. Ela nao abre a proxima coisa, nao soma recompensa e nao salva nada --
	# quem faz isso e quem escutar este sinal.
	ended.emit(won)


func _build_fighter(unit: Unit) -> Fighter:
	var f := Fighter.new()
	f.root = Control.new()
	f.root.name = unit.id
	f.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f.root)

	f.sprite = Sprite2D.new()
	f.idle_sheet = _sheet(unit.sprite)
	f.attack_sheet = _sheet(unit.sprite_attack)
	f.sprite.texture = f.idle_sheet
	f.sprite.hframes = Fighter.FRAMES
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
	f.bar.add_theme_stylebox_override("fill", Chrome.panel(tokens, "danger"))
	f.root.add_child(f.bar)

	f.hp_label = Label.new()
	f.hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.write(f.hp_label, tokens, 22, "text")
	f.root.add_child(f.hp_label)
	return f


## AUSENCIA TRATADA, E NAO ASSUMIDA: `sprite` e `sprite_attack` sao colunas opcionais, entao
## uma unidade sem folha desenha so a barra em vez de derrubar a tela. Um caminho PREENCHIDO e
## inexistente e outra coisa -- esse e erro, e grita.
func _sheet(path: String) -> Texture2D:
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		push_error("batalha: a folha %s nao existe" % [path])
		return null
	return load(path)


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

	_clock.position = area.position
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
	#
	# E o layout define `home`, nao a posicao: a animacao MEXE na posicao a cada quadro, entao
	# quem a escrevesse aqui estaria discutindo com ela. O lugar de voltar e um dado.
	f.home = Vector2(slot.size.x / 2.0, slot.size.y / 2.0)
	f.sprite.position = f.home
	f.bar.position = Vector2(x, slot.size.y - 90.0)
	f.bar.size = Vector2(inner, 28.0)
	f.hp_label.position = Vector2(x, slot.size.y - 56.0)
	f.hp_label.size = Vector2(inner, 28.0)
