# A PORTA DE ENTRADA DO PROJETO. Tudo que se faz aqui tem um alvo, e o alvo e a documentacao:
# um comando que so existe no historico do terminal de uma pessoa nao existe.
#
# `make` sozinho lista o que da para fazer.

GODOT ?= godot
RES   ?= 1152x648

# O CACHE DE CLASSES, e ele e a razao de metade deste arquivo ter `| $(CACHE)` na frente.
#
# Num clone limpo a pasta `.godot/` nao existe -- ela e derivada e esta no .gitignore. Sem ela
# o Godot nao sabe que `class_name Tokens` existe, e `--check-only` reprova TODO script que
# cita uma classe de outro arquivo. O primeiro `make check` de quem clonou falhava com trinta
# "Could not find type", e a causa nao era o codigo: era a pasta ausente.
#
# Entao o cache virou um alvo, e nao um recado no README. Ele e gerado na primeira vez que
# alguem precisa dele, e depois disso ninguem pensa nisso de novo.
CACHE := game/.godot/global_script_class_cache.cfg

.DEFAULT_GOAL := help
.PHONY: help run editor check parse data test import clean doctor

help:
	@echo ""
	@echo "  JOGAR"
	@echo "    make run        abre o jogo             [RES=LxA]"
	@echo "    make editor     abre o editor do Godot"
	@echo ""
	@echo "  VERIFICAR  (rode 'make check' antes de cada commit)"
	@echo "    make check      os tres portoes, nesta ordem"
	@echo "      make parse      todo GDScript compila"
	@echo "      make data       os CSVs batem com o schema"
	@echo "      make test       a suite GUT, sem janela"
	@echo ""
	@echo "  MANUTENCAO"
	@echo "    make import     reimporta os assets (depois de clonar ou de por arte nova)"
	@echo "    make doctor     o que esta instalado e o que falta"
	@echo ""

# --- jogar -------------------------------------------------------------------------------

run: | _godot $(CACHE)
	$(GODOT) --path game --resolution $(RES)

editor: | _godot $(CACHE)
	$(GODOT) --path game

# --- verificar ---------------------------------------------------------------------------

# NESTA ORDEM, e a ordem importa. Primeiro o que e barato e o que invalida o resto: se um
# script nao compila, ele esta AUSENTE, e uma suite verde depois disso nao afirma nada.
check: parse data test
	@echo ""
	@echo "  ok, os portoes passaram"

parse: | _godot $(CACHE)
	@echo "==> todo GDScript compila"
	@sh tools/check_scripts.sh && echo "    ok"

data: | _godot $(CACHE)
	@echo "==> os CSVs batem com o schema"
	@$(GODOT) --headless --path game -s dev/validate_data.gd 2>&1 \
		| sed 's/\x1b\[[0-9;]*m//g' | tail -2

# O PIPE COME O STATUS: num pipe, o codigo de saida e o do ULTIMO comando. Sem o `status=$$?`
# guardado antes do `sed`, este alvo imprimiria "os portoes passaram" com testes falhando --
# e um portao que relata sem barrar e pior que portao nenhum, porque ensina a confiar nele.
test: | _godot $(CACHE)
	@echo "==> suite"
	@mkdir -p build
	@sh tools/run_tests.sh > build/test.log 2>&1; status=$$?; \
		sed 's/\x1b\[[0-9;]*m//g' build/test.log \
		| grep -E "^(Scripts|Tests|Passing|Failing|Risky|Asserts)|All tests|GUARDA|\[Failed\]" || true; \
		exit $$status

# --- manutencao --------------------------------------------------------------------------

# Depois de clonar, e depois de por arte nova em game/. Sem isto o Godot nao conhece o arquivo
# e a tela desenha o retangulo de reserva sem dizer por que.
import: | _godot
	@echo "==> reimportando assets"
	@$(GODOT) --headless --path game --import >/dev/null 2>&1 || true
	@echo "    ok"

# A primeira importacao, feita sozinha quando falta. `|| true` porque o import imprime avisos
# e sai diferente de zero por motivos que nao impedem nada -- o que decide e o arquivo existir,
# e e isso que a linha seguinte verifica.
$(CACHE): | _godot
	@echo "==> primeira vez neste clone: importando"
	@$(GODOT) --headless --path game --import >/dev/null 2>&1 || true
	@test -f $@ || { echo "o import nao gerou o cache de classes -- rode 'make import'"; exit 2; }
	@echo "    ok"

clean:
	@rm -rf build game/.godot
	@echo "    limpo (o proximo 'make run' reimporta)"

doctor:
	@printf "  godot   "; command -v $(GODOT) >/dev/null && $(GODOT) --version || echo "FALTA -- brew install godot"
	@printf "  make    "; command -v make >/dev/null && echo ok || echo FALTA

_godot:
	@command -v $(GODOT) >/dev/null || { echo "godot nao esta no PATH -- brew install godot"; exit 2; }
