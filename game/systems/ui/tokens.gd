# Toda cor e toda medida que o jogo pinta, pedidas pelo NOME.
#
# Sem isto, uma cor vira literal espalhado: `Color(0.96, 0.77, 0.26)` em sete arquivos, e
# mudar "o dourado" vira cacar por semelhanca e torcer para nao haver um oitavo. Entao a cor
# virou tabela, que e o que todo numero deste projeto ja e: um dono, e os consumidores citam.
#
# AS MEDIDAS ESTAO AQUI TAMBEM, de proposito. Margem, raio e vao nao sao de graca: escolher
# cada um na hora de escrever cada tela e exatamente como as telas passam a discordar entre si.
class_name Tokens
extends RefCounted

const TABLE := "02-palette.csv"

## A margem que uma tela guarda contra a borda. UM numero, porque o normal e virarem cinco --
## cada tela escolhe o seu enquanto e escrita e ninguem compara com a tela do lado.
const PAD := 32.0
const GAP := 16.0
const GAP_TIGHT := 8.0
const RADIUS := 14.0
## A borda de baixo e mais grossa que as outras tres. Essa unica assimetria e o que faz um
## retangulo chapado parecer um botao.
const BORDER := 3.0
const BORDER_BOTTOM := 7.0
## Altura minima de um alvo de toque. 48 dp -- o minimo do Android.
const TOUCH := 56.0

var _by_token: Dictionary = {}
var _by_role: Dictionary = {}
var _errors: Array[String] = []


func errors() -> Array[String]:
	return _errors


## Barulhento quando a tabela falta ou um hex nao se le. Uma cor que cai em magenta sozinha e
## um buraco que ninguem ve ate a primeira captura de tela.
func load_from(tables: DataTables) -> bool:
	_errors.clear()
	_by_token.clear()
	_by_role.clear()
	var rows: Array = tables.rows(TABLE)
	if rows.is_empty():
		_errors.append("%s: nenhuma linha de cor" % [TABLE])
		return false
	for row in rows:
		var token := str(row.get("token", ""))
		var hex := str(row.get("hex", ""))
		var role := str(row.get("role", ""))
		if token == "" or hex.length() != 6 or not hex.is_valid_hex_number(false):
			_errors.append("%s: %s nao tem hex usavel (%s)" % [TABLE, token, hex])
			continue
		var colour := Color.from_string("#" + hex, Color.MAGENTA)
		_by_token[token] = colour
		if not _by_role.has(role):
			_by_role[role] = {}
		_by_role[role][token] = colour
	return _errors.is_empty()


## A cor de um token. Token desconhecido e erro, nunca um padrao silencioso -- magenta e a
## coisa mais barulhenta que esta paleta nao contem.
func color(token: String) -> Color:
	if _by_token.has(token):
		return _by_token[token]
	push_error("tokens: nao existe cor chamada '%s' em %s" % [token, TABLE])
	return Color.MAGENTA


func has(token: String) -> bool:
	return _by_token.has(token)


## Todos os tokens de um papel, para as ferramentas e os testes que varrem a paleta em vez de
## fazer uma pergunta a ela.
func of_role(role: String) -> Dictionary:
	return _by_role.get(role, {})


func tokens() -> Array:
	return _by_token.keys()
