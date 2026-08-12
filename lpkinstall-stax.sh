#!/bin/bash
# lpkinstall-stax.sh - Baixa e instala o pacote fpStax no Lazarus (OPM)

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lpkinstall-common.sh
source "$SCRIPT_DIR/lpkinstall-common.sh"

STAX_OPM_ZIP="FpStax.zip"
STAX_LPK_REL="Stax-package/Stax.lpk"

check_lazarus_closed() {
  local running
  if ! command -v pgrep >/dev/null 2>&1; then
    return 0
  fi
  running="$(pgrep -u "$(id -u)" -af '(^|/)(lazarus|startlazarus)([[:space:]]|$)' || true)"
  if [ -n "$running" ]; then
    echo "Erro: a IDE Lazarus parece estar aberta."
    echo "Feche o Lazarus antes de instalar pacotes ou recompilar a IDE e execute este script novamente."
    echo
    echo "$running"
    exit 1
  fi
}

LAZARUS_DIR="${1:-$HOME/fpcupdeluxe/lazarus}"
if [ ! -d "$LAZARUS_DIR" ]; then
  echo "Erro: pasta do Lazarus não encontrada:"
  echo "  $LAZARUS_DIR"
  exit 1
fi

LAZBUILD="$LAZARUS_DIR/lazbuild"
LAZ_BIN="$LAZARUS_DIR/lazarus"
check_lazarus_closed

if [ ! -x "$LAZBUILD" ]; then
  echo "Erro: lazbuild não encontrado dentro da pasta do Lazarus."
  echo "Esperado:"
  echo "  $LAZBUILD"
  exit 1
fi

LAZARUS_COMPONENTS="$LAZARUS_DIR/components"
STAX_DIR="$LAZARUS_COMPONENTS/stax"
STAX_LPK="$STAX_DIR/$STAX_LPK_REL"

if [ ! -d "$LAZARUS_COMPONENTS" ]; then
  echo "Erro: diretório de componentes do Lazarus não encontrado:"
  echo "  $LAZARUS_COMPONENTS"
  exit 1
fi

echo
echo "────────── COMPONENTES VISUAIS ─────────"
echo "Você deseja usar um widgetset específico ao chamar o lazbuild?"
echo "Pressione ENTER para manter o padrão ou digite: gtk, qt5, qt6"
echo -n "> "
read -r resp_widget
if [[ "$resp_widget" =~ ^[Ss]$ ]]; then
  echo "Resposta ignorada"
  resp_widget=""
fi

LAZBUILD_WIDGETSET_ARGS=()
if [ -n "$resp_widget" ]; then
  LAZBUILD_WIDGETSET_ARGS=(--widgetset="$resp_widget")
fi

if ! ensure_opm_zip "$STAX_OPM_ZIP" "$STAX_DIR" "$STAX_LPK_REL"; then
  echo "Erro: não foi possível obter Stax de ${OPM_BASE_URL}${STAX_OPM_ZIP}"
  exit 1
fi

clean_component_build_artifacts "Stax" "$LAZARUS_COMPONENTS" "$STAX_DIR" "Stax-package/lib"

if [ ! -f "$STAX_LPK" ]; then
  echo "Erro: pacote Stax não encontrado:"
  echo "  $STAX_LPK"
  exit 1
fi

echo
echo "=============================================="
echo "Stax no Lazarus"
echo "Lazarus : $LAZARUS_DIR"
echo "Fonte   : ${OPM_BASE_URL}${STAX_OPM_ZIP}"
echo "Widget  : ${resp_widget:-padrao}"
echo "Pacote  : $STAX_LPK"
echo "=============================================="

[ -f "$LAZ_BIN" ] && lazarus_timestamp_start=$(stat -c %Y "$LAZ_BIN") || lazarus_timestamp_start=0

"$LAZBUILD" "${LAZBUILD_WIDGETSET_ARGS[@]}" --add-package "$STAX_LPK"
"$LAZBUILD" "${LAZBUILD_WIDGETSET_ARGS[@]}" --build-ide=

if [ -f "$LAZ_BIN" ]; then
  lazarus_timestamp_end=$(stat -c %Y "$LAZ_BIN")
  if [ "$lazarus_timestamp_start" -eq "$lazarus_timestamp_end" ]; then
    echo "ERRO: a data/hora do binário 'lazarus' não mudou. A recompilação da IDE pode ter falhado."
    exit 1
  fi
fi

echo
echo "=============================================="
echo "Concluído. Abra novamente o Lazarus para ver o Stax disponível."
echo "=============================================="
