#!/bin/sh
# PORTAO 1: todo GDScript do projeto tem de compilar.
#
# Por que isto existe, e nao e teoria: um script que nao compila e simplesmente AUSENTE. A
# suite fica verde porque o teste que usaria aquele sistema tambem nao compilou, e some junto.
#
# E `--import` NAO serve aqui: ele percorre o cache de recursos, nao os scripts, e ja deu
# "limpo" em arquivo que imprimia tres erros de parse ao ser carregado. `--check-only` analisa
# o arquivo que recebe, entao este laco entrega cada um deles.
#
# O TRABALHO E CONTADO. Um portao que falha em silencio e o proprio defeito que ele existe
# para pegar: se o numero de scripts verificados nao bate com o numero de scripts em disco,
# isso ja e falha -- nao e aprovacao.
set -u
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
JOBS=${JOBS:-6}
LIST="$WORK/list"
find game -name '*.gd' -not -path 'game/addons/*' | sort > "$LIST"
TOTAL=$(wc -l < "$LIST" | tr -d ' ')

INDEX=0
RUNNING=0
while IFS= read -r FILE; do
  INDEX=$((INDEX + 1))
  (
    RES="res://$(echo "$FILE" | sed 's|^game/||')"
    OUT=$(godot --headless --path game --check-only -s "$RES" 2>&1 \
          | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Parse Error|SCRIPT ERROR" | head -5)
    [ -n "$OUT" ] && printf '  %s\n%s\n' "$FILE" "$OUT" > "$WORK/fail.$INDEX"
    : > "$WORK/done.$INDEX"
  ) &
  RUNNING=$((RUNNING + 1))
  [ "$RUNNING" -ge "$JOBS" ] && { wait; RUNNING=0; }
done < "$LIST"
wait

CHECKED=$(ls "$WORK" | grep -c '^done\.' || true)
if [ "$CHECKED" -ne "$TOTAL" ]; then
  echo "check_scripts: verifiquei $CHECKED de $TOTAL scripts -- BARRANDO pela propria lacuna"
  exit 2
fi
if ls "$WORK" | grep -q '^fail\.'; then
  echo "GDScript nao compila -- BARRANDO:"
  cat "$WORK"/fail.*
  exit 2
fi
exit 0
