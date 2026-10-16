#!/bin/sh
# PORTAO 3: a suite, sem janela.
#
# A GUARDA DE CONTAGEM existe porque o GUT PULA um script de teste que nao compila e mesmo
# assim imprime "All tests passed". Um verde que verificou menos do que diz e pior que
# vermelho. Entao: quantos arquivos de teste existem em disco contra quantos o GUT coletou.
#
# Sem `set -e`: ele abortaria antes de imprimir quando o godot sai diferente de zero, que e
# justamente o caso que vale a pena ver.
EXPECTED=$(find game/tests -name 'test_*.gd' | wc -l | tr -d ' ')
OUT=$(godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit "$@" 2>&1)
STATUS=$?
echo "$OUT"
COLLECTED=$(echo "$OUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^Scripts +[0-9]+' | awk '{print $2}')
if [ "$COLLECTED" != "$EXPECTED" ]; then
  echo ""
  echo "GUARDA: $EXPECTED scripts de teste em disco, $COLLECTED coletados pelo GUT."
  echo "Um script que nao compila e pulado em silencio -- procure 'Parse Error' acima."
  exit 2
fi
exit $STATUS
