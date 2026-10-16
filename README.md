# Godot Starter

Um esqueleto de projeto Godot 4.7 que **roda** e já carrega uma arquitetura inteira em cerca de
mil linhas. Não é um jogo: são duas telas e três unidades numa tabela. O que ele ensina é a
**forma** — onde cada coisa mora, e por quê.

```
make run      # abre o jogo
make check    # os três portões (rode antes de cada commit)
make          # lista tudo que dá para fazer
```

Precisa de `godot` no PATH (`brew install godot`) e nada mais. Na primeira vez o `make`
importa o projeto sozinho — a pasta `.godot/` é derivada e não vem no repositório.

---

## Em 60 segundos

O caminho que um número faz, da planilha até a tela — e cada seta é uma fronteira que o projeto
não deixa ninguém atravessar por fora:

```
  data/*.csv          o número, e o único lugar onde ele mora
      |               ... validado contra data/schema.csv
      v
  DataTables          abre o arquivo, devolve valor TIPADO
      |               ... e é o único que abre arquivo
      v
  systems/            a regra: Unit, combate, economia. Sem cena, sem desenho.
      |               ... por isso a suíte roda sem abrir janela
      v
  run/                a tela: desenha o que a regra decidiu
      |               ... e emite um sinal quando o jogador pede algo
      v
  run/main.gd         o roteador: o único que decide qual tela aparece
```

Para ver isso vivo: `data/01-units.csv` tem `attack` e `attacks_per_s`, o `schema.csv` declara
`dps` como fórmula, e a tela de unidades imprime um `dps` que **não existe em arquivo nenhum**.
Mude o `attack` do Archer no CSV e rode `make run` — nenhuma linha de código mudou.

| se você quer... | vá para |
|---|---|
| entender a ideia | [As quatro regras](#as-quatro-regras) |
| achar um arquivo | [O mapa](#o-mapa) |
| saber o que `make check` faz | [Os três portões](#os-três-portões) |
| mexer no projeto | [Como fazer as coisas](#como-fazer-as-coisas) |
| crescer sem quebrar a forma | [O que foi deixado de fora](#o-que-foi-deixado-de-fora-de-propósito) |

---

## As quatro regras

Tudo neste repositório existe para sustentar estas quatro frases. Se você só ler uma seção, leia
esta.

### 1. Um número mora num lugar só, e esse lugar é um CSV

Vida de inimigo, custo de upgrade, cor de botão, margem de tela: tudo em `game/data/*.csv`.
Nenhum número de balanceamento é literal dentro de um `.gd`.

Por quê: o mesmo número em dois lugares **sempre** diverge — um é atualizado, o outro não, e o bug
aparece meses depois no caminho menos usado. E CSV ainda dá de brinde um diff que um humano lê.

### 2. Nenhum sistema lê um CSV

Os sistemas pedem ao `DataTables` e recebem valores **já tipados**. Quem abre arquivo é uma classe
só (`systems/data/`).

Por quê: se cada sistema abrir o arquivo, cada um inventa a sua interpretação do que a coluna
significa, e a regra da primeira linha vira ficção.

### 3. Número derivado é calculado, nunca guardado

`dps` não existe em `01-units.csv`. Ele está no `schema.csv` como fórmula
(`attack * attacks_per_s`) e nasce no carregamento.

Por quê: guardar o derivado é o caso 1 outra vez, disfarçado — a fórmula e o resultado são o mesmo
número em dois lugares.

### 4. Uma tela pede; o roteador decide

Nenhuma tela abre outra tela. Ela emite um sinal (`roster_requested`, `left`) e
`run/main.gd` resolve para onde aquilo leva.

Por quê: tela que abre tela monta um grafo onde todo mundo conhece todo mundo, e nele nenhuma tela
pode ser removida, reutilizada ou testada sozinha.

---

## O mapa

```
Makefile              a porta de entrada: todo comando do projeto tem um alvo aqui
tools/                os scripts que os portões chamam
game/
  project.godot       resolução, renderizador, plugin de teste
  data/
    schema.csv        O CONTRATO: que colunas existem, de que tipo, em que faixa
    01-units.csv      os números do jogo
    02-palette.csv    as cores, pedidas por nome
  systems/            REGRA PURA — sem nó de cena, sem desenho, sem input
    data/             o carregador tipado e o leitor do schema
    ui/               tokens (cor e medida) e chrome (como um controle se parece)
    roster/           exemplo de regra: Unit, construída de uma linha da tabela
  run/                TELAS — tudo que o jogador vê
    main.tscn/.gd     o roteador, e o único lugar que liga e desliga tela
    screen.gd         a forma que toda tela compartilha: chão, cabeçalho, saída
    home_screen.gd    exemplo de tela que só oferece destinos
    roster_screen.gd  exemplo de tela que lê dados
  dev/                ferramenta de linha de comando, fora do build do jogador
  tests/              a suíte GUT
  addons/gut/         o framework de teste (vendorizado)
```

A separação que mais importa é **`systems/` contra `run/`**. Regra pura de um lado, tela do outro.
É ela que deixa a suíte rodar em milissegundos sem abrir janela — e um teste que precisa de janela
é um teste que ninguém roda.

---

## Os três portões

`make check` roda os três **nesta ordem**, e a ordem é parte do desenho:

| portão | o que prova | por que existe |
|---|---|---|
| `make parse` | todo GDScript compila | um script que não compila está **ausente**, e a suíte fica verde porque o teste dele também sumiu |
| `make data` | os CSVs batem com o schema | tipo errado, faixa estourada, coluna a mais, `id` repetido |
| `make test` | a suíte GUT | a regra ainda faz o que dizia fazer |

Dois detalhes que parecem paranoia e não são — os dois já deixaram passar bug de verdade no
projeto de onde isto saiu:

- **`check_scripts.sh` conta o trabalho.** Se ele verificou 11 de 12 scripts, isso é falha, não
  aprovação. Portão que falha em silêncio é o próprio defeito que ele existe para pegar.
- **`run_tests.sh` compara contagens.** O GUT **pula** um arquivo de teste que não compila e mesmo
  assim imprime "All tests passed". Um verde que verificou menos do que afirma é pior que vermelho.

---

## Como fazer as coisas

### Adicionar um número novo

1. Declare a coluna em `data/schema.csv` (arquivo, coluna, tipo, faixa, obrigatória, por quê).
2. Preencha a coluna no CSV.
3. `make data` reclama se algo não bate.

Nenhuma linha de código é necessária para o validador conhecer a coluna nova — ele lê o schema.

### Adicionar uma tabela nova

Mesmo caminho, mais uma linha por coluna no schema. O `DataTables` carrega tudo que o schema
declara; um CSV que o schema não conhece é erro, e um schema que descreve arquivo inexistente
também.

**Uma pegadinha do Godot:** por padrão ele importa `.csv` como *arquivo de tradução* e cospe um
`.translation` por coluna. Todo CSV aqui tem um `.csv.import` ao lado com `importer="keep"`, que
manda o Godot deixar o arquivo em paz. Ao criar um CSV novo, copie um desses `.import`.

### Adicionar uma tela

```gdscript
class_name ShopScreen
extends Screen

signal bought(item_id: String)   # ela PEDE; o roteador decide

func setup(with_tokens: Tokens, tables: DataTables) -> void:
    dress(with_tokens, "LOJA")   # sempre primeiro: chão, cabeçalho e saída
    # ... monte o corpo dentro de body() ...

func _place_body() -> void:
    if _meu_no == null:
        return                   # pode rodar antes de o corpo existir
    var area := body()
```

Depois, em `run/main.gd`: construa, `add_child`, conecte os sinais. É o único arquivo que precisa
saber que a tela nova existe.

### Adicionar um teste

Um arquivo `game/tests/test_*.gd` que `extends GutTest`. A guarda de contagem no `run_tests.sh`
percebe sozinha que ele existe.

---

## O que foi deixado de fora de propósito

Este esqueleto **não** tem: save em disco, áudio, combate, export de Android, servidor,
localização, cena de loading. Todos cabem na forma acima sem quebrá-la:

- **save** → uma classe em `systems/` que serializa um dicionário; o roteador a chama no `_ready`.
- **áudio** → um nó montado uma vez no `main.gd`, com os nomes de som vindo de um CSV.
- **combate** → `systems/combat/`, regra pura, testável sem janela; a tela só desenha o resultado.

A regra para crescer é a mesma que vale aqui: a decisão nova vai num arquivo, com o motivo escrito
ao lado dela, e um portão que a verifique.

---

## Uma palavra sobre os comentários

Os comentários deste projeto dizem **por quê**, não **o quê**. `# incrementa o contador` não vale o
espaço que ocupa; `# o pipe come o status de saída, por isso o $? é guardado antes` vale, porque é
uma hora de depuração que ninguém vai gastar de novo.

Quando um comentário aqui soa exagerado, ele normalmente está descrevendo um bug que já aconteceu.

---

## Licença

Apache 2.0 — veja `LICENSE`. Use, copie, mude, publique.
