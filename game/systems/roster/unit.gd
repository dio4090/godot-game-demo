# Uma unidade, construida a partir de UMA linha de `01-units.csv`.
#
# ESTE ARQUIVO E O EXEMPLO DA CAMADA `systems/`: regra pura, sem no de cena, sem desenho, sem
# entrada do jogador. E por ser pura que um teste a roda em milissegundos e sem abrir janela.
#
# Repare no que ela NAO faz: nao abre CSV. Ela recebe um dicionario ja tipado do DataTables.
# O dia em que um sistema le um arquivo e o dia em que o mesmo numero passa a ter dois donos.
class_name Unit
extends RefCounted

var id: String
var name: String
var role: String
var hp: int
var attack: float
var attacks_per_s: float
## Veio do schema como coluna CALCULADA (`attack * attacks_per_s`), entao nao esta no CSV.
var dps: float


## O UNICO construtor. Quando houver dois caminhos para montar a mesma coisa, eles divergem --
## um ganha um campo novo e o outro nao, e o bug aparece so no caminho menos usado.
static func from_row(row: Dictionary) -> Unit:
	var unit := Unit.new()
	unit.id = str(row.get("id", ""))
	unit.name = str(row.get("name", ""))
	unit.role = str(row.get("role", ""))
	unit.hp = int(row.get("hp", 0))
	unit.attack = float(row.get("attack", 0.0))
	unit.attacks_per_s = float(row.get("attacks_per_s", 0.0))
	unit.dps = float(row.get("dps", 0.0))
	return unit


## Todas as unidades da tabela, na ordem do arquivo.
static func all(tables: DataTables) -> Array[Unit]:
	var units: Array[Unit] = []
	for row in tables.rows("01-units.csv"):
		units.append(from_row(row))
	return units


## Quantos segundos esta unidade leva para derrubar `other`. INF quando ela nao causa dano --
## e INF e a resposta honesta; zero ou um numero grande seriam mentira arredondada.
func seconds_to_kill(other: Unit) -> float:
	if dps <= 0.0:
		return INF
	return other.hp / dps
