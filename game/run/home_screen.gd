# A primeira tela. Ela faz UMA coisa: oferecer os destinos.
#
# Repare no que ela nao faz. Nao sabe o que a tela de unidades mostra, nao a constroi e nao a
# abre -- emite `roster_requested` e o roteador (`run/main.gd`) resolve. Uma tela que abre
# outra tela cria um grafo onde todo mundo conhece todo mundo, e nele nenhuma tela pode ser
# removida nem testada sozinha.
class_name HomeScreen
extends Screen

signal roster_requested

var _play: Button
var _roster: Button
var _hint: Label


func setup(with_tokens: Tokens) -> void:
	dress(with_tokens, "GODOT STARTER", false)
	set_subtitle("o minimo que ja e uma arquitetura")

	_play = Chrome.button(tokens, "jogar (ainda nao faz nada)")
	_play.disabled = true
	add_child(_play)

	_roster = Chrome.button(tokens, "ver as unidades")
	_roster.pressed.connect(func() -> void: roster_requested.emit())
	add_child(_roster)

	_hint = Label.new()
	_hint.text = "Os numeros vem de data/01-units.csv. As cores, de data/02-palette.csv.\n" \
		+ "Rode `make check` antes de cada commit."
	Chrome.write(_hint, tokens, 18, "text_dim")
	add_child(_hint)


func _place_body() -> void:
	if _hint == null:
		return  # ainda sendo construida; veja Screen._place_body
	var area := body()
	var width: float = min(520.0, area.size.x)
	var x := area.position.x + (area.size.x - width) / 2.0
	var y := area.position.y + Tokens.GAP * 2.0
	for b: Button in [_play, _roster]:
		b.position = Vector2(x, y)
		b.size = Vector2(width, Tokens.TOUCH)
		y += Tokens.TOUCH + Tokens.GAP
	_hint.position = Vector2(x, y + Tokens.GAP)
	_hint.size = Vector2(width, 60.0)
