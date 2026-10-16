# Como um controle se PARECE, num lugar so.
#
# Tokens diz quais sao as cores e as medidas. Chrome diz o que fazer com elas: que um texto
# corrido usa `text` neste tamanho, que uma face elevada tem a borda de baixo mais grossa.
# Sem este arquivo, cada tela escreve `add_theme_color_override` do seu jeito e o jogo passa a
# ter cinco aparencias -- uma por tela, nenhuma decidida.
#
# Tudo aqui e `static`: Chrome nao guarda estado, nao pertence a ninguem e nao desenha nada.
class_name Chrome
extends RefCounted


## Escreve um rotulo. Uma unica porta para texto, entao mudar a fonte do jogo e mudar aqui.
static func write(label: Label, tokens: Tokens, size: int, token: String = "text") -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tokens.color(token))


## A face de um painel: o corpo de um cartao, de um modal, de uma linha de lista.
static func panel(tokens: Tokens, token: String = "bg_panel") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tokens.color(token)
	box.set_corner_radius_all(int(Tokens.RADIUS))
	box.content_margin_left = Tokens.GAP
	box.content_margin_right = Tokens.GAP
	box.content_margin_top = Tokens.GAP_TIGHT
	box.content_margin_bottom = Tokens.GAP_TIGHT
	return box


## A face de um botao. A borda de baixo e mais grossa que as outras tres, e e so isso que faz
## um retangulo chapado ler como algo que se aperta.
static func face(tokens: Tokens, token: String = "bg_raised") -> StyleBoxFlat:
	var box := panel(tokens, token)
	box.border_color = tokens.color("ink")
	box.border_width_left = int(Tokens.BORDER)
	box.border_width_right = int(Tokens.BORDER)
	box.border_width_top = int(Tokens.BORDER)
	box.border_width_bottom = int(Tokens.BORDER_BOTTOM)
	return box


## Um botao ja vestido. `pressed` continua sendo do chamador -- Chrome nunca liga sinal, nunca
## decide para onde um toque leva.
static func button(tokens: Tokens, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = Tokens.TOUCH
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", tokens.color("text"))
	b.add_theme_color_override("font_hover_color", tokens.color("gold"))
	b.add_theme_stylebox_override("normal", face(tokens))
	b.add_theme_stylebox_override("hover", face(tokens))
	b.add_theme_stylebox_override("pressed", face(tokens, "bg_panel"))
	b.add_theme_stylebox_override("focus", face(tokens))
	return b
