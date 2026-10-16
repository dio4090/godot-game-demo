# A FORMA QUE TODA TELA DESTE JOGO COMPARTILHA.
#
# O defeito que esta classe existe para impedir e visivel sem ler uma linha de codigo: "cada
# tela tem um cabecalho diferente". Ele e estrutural. Sem uma base, cada tela e um
# `extends Control` com o seu proprio `_place()` fazendo aritmetica contra `size`, e nada e
# compartilhado porque nao ha COM QUEM compartilhar.
#
# Entao esta e a coisa. Ela e dona das tres partes que toda tela estava rederivando:
#
#   o chao        o preenchimento de `bg_deep`, desenhado aqui em vez de em cada `_draw`
#   o cabecalho   o titulo dourado, e um subtitulo opcional
#   a saida       o botao de voltar, na unica posicao que ele tem
#
# e entrega a subclasse o unico retangulo que sobra: `body()`.
#
# O QUE ELA DE PROPOSITO NAO FAZ: nao monta o corpo, nao sabe o que uma lista de unidades e, e
# NAO NAVEGA. Ela emite `left` e quem roteia decide. Uma classe base que soubesse o que suas
# subclasses contem seria as telas todas de novo, agora num arquivo so.
class_name Screen
extends Control

## O jogador pediu para sair. O roteador decide para onde isso leva; esta classe nunca navega.
signal left

const TITLE_ROW := 64.0
const SUBTITLE_ROW := 36.0

var tokens: Tokens

var _title: Label
var _subtitle: Label
var _back: Button
var _backdrop: TextureRect
var _veil: ColorRect


## Monta o cromo. A subclasse chama isto PRIMEIRO no seu proprio `setup` e so depois acrescenta
## o corpo -- entao o cabecalho e a saida sao filhos antes do que a tela e sobre, que tambem e
## a ordem em que sao desenhados.
func dress(with_tokens: Tokens, title: String, with_back: bool = true) -> void:
	tokens = with_tokens
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_title = Label.new()
	_title.name = "Title"
	_title.text = title
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Chrome.write(_title, tokens, 40, "gold")
	add_child(_title)

	# CONSTRUIDO SEMPRE, MOSTRADO SOB DEMANDA. Um subtitulo que so existe quando a tela pede faz
	# o `_place` ramificar sobre a EXISTENCIA de um no -- e um `_place` que ramifica assim e onde
	# um layout comeca a discordar de si mesmo.
	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.visible = false
	Chrome.write(_subtitle, tokens, 20, "text_dim")
	add_child(_subtitle)

	_back = Chrome.button(tokens, "< voltar")
	_back.name = "Back"
	_back.visible = with_back
	_back.custom_minimum_size = Vector2(160, Tokens.TOUCH)
	_back.pressed.connect(func() -> void: left.emit())
	add_child(_back)


## Troca o chao de cor chapada por uma imagem. Opcional: uma tela que nao chamar isto fica com
## o `bg_deep` de sempre, e nada mais muda.
##
## O VEU NAO E ENFEITE. Texto claro sobre uma ilustracao cheia de forma clara perde contraste
## em pedacos imprevisiveis da tela -- some num cogumelo e reaparece numa sombra. Uma camada de
## `ink` por cima da imagem derruba o fundo inteiro alguns passos e devolve a leitura, sem
## precisar de contorno em cada rotulo.
##
## STRETCH_KEEP_ASPECT_COVERED porque a janela deste projeto pode ser redimensionada: a imagem
## cobre a tela e perde o excesso num eixo, em vez de esticar e deformar o desenho.
func set_backdrop(path: String, veil: float = 0.45) -> void:
	if not ResourceLoader.exists(path):
		push_error("backdrop: nao existe %s" % [path])
		return
	_backdrop = TextureRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.texture = load(path)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(tokens.color("ink"), veil)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	# ATRAS DE TUDO, e por isso os dois sao movidos para o comeco da lista: `dress` ja criou o
	# titulo e o botao, e um filho acrescentado depois desenha POR CIMA deles. A ordem dos
	# irmaos e a ordem do desenho, e e so isso que decide o que cobre o que.
	move_child(_backdrop, 0)
	move_child(_veil, 1)
	_place()


func set_subtitle(text: String) -> void:
	_subtitle.text = text
	_subtitle.visible = text != ""
	_place()


## O retangulo que sobra para a subclasse: abaixo do cabecalho, acima do rodape, dentro da
## margem. Nenhuma tela mede isso sozinha -- era assim que cinco margens diferentes nasciam.
func body() -> Rect2:
	var top := Tokens.PAD + TITLE_ROW
	if _subtitle.visible:
		top += SUBTITLE_ROW
	var bottom := size.y - Tokens.PAD - Tokens.TOUCH - Tokens.GAP
	return Rect2(Tokens.PAD, top, size.x - Tokens.PAD * 2.0, max(0.0, bottom - top))


## Onde a subclasse posiciona o que ela mesma acrescentou. Chamado sempre que a janela muda --
## E TAMBEM DURANTE A CONSTRUCAO, antes de o corpo existir: `set_subtitle` reposiciona, e a
## subclasse costuma chamar isso logo depois de `dress` e antes de montar seus proprios
## controles. Por isso toda implementacao comeca verificando se o que ela move ja existe. E
## uma linha chata e o erro que ela evita e `Invalid assignment ... on a base object of type
## 'Nil'`, que aparece so as vezes e so para quem redimensiona a janela na hora errada.
func _place_body() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()


func _place() -> void:
	if _title == null:
		return
	_title.position = Vector2(Tokens.PAD, Tokens.PAD)
	_title.size = Vector2(size.x - Tokens.PAD * 2.0, TITLE_ROW)
	_subtitle.position = Vector2(Tokens.PAD, Tokens.PAD + TITLE_ROW)
	_subtitle.size = Vector2(size.x - Tokens.PAD * 2.0, SUBTITLE_ROW)
	if _backdrop != null:
		_backdrop.position = Vector2.ZERO
		_backdrop.size = size
		_veil.position = Vector2.ZERO
		_veil.size = size
	_back.position = Vector2(Tokens.PAD, size.y - Tokens.PAD - Tokens.TOUCH)
	_back.size = Vector2(160, Tokens.TOUCH)
	_place_body()
	queue_redraw()


## O chao, desenhado uma vez aqui em vez de em cada tela.
func _draw() -> void:
	if tokens == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), tokens.color("bg_deep"))
