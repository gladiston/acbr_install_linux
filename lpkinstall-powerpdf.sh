#!/bin/bash
# lpkinstall-powerpdf.sh - Baixa, compila e instala o pacote PowerPDF no Lazarus

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lpkinstall-common.sh
source "$SCRIPT_DIR/lpkinstall-common.sh"

POWERPDF_SVN_URL="svn://svn.code.sf.net/p/lazarus-ccr/svn/components/powerpdf"

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

ensure_svn() {
  if command -v svn >/dev/null 2>&1; then
    return 0
  fi

  echo "Erro: não encontrei o executável 'svn' no PATH."
  echo "Instale o Subversion e execute este script novamente."
  exit 1
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
POWERPDF_DIR="$LAZARUS_COMPONENTS/powerpdf"
POWERPDF_LPK="$POWERPDF_DIR/pack_powerpdf.lpk"

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

ensure_svn

if [ -e "$POWERPDF_DIR" ] && ! svn info "$POWERPDF_DIR" >/dev/null 2>&1; then
  echo "Erro: já existe uma pasta powerpdf, mas ela não é uma working copy SVN válida:"
  echo "  $POWERPDF_DIR"
  exit 1
fi

if [ ! -d "$POWERPDF_DIR/.svn" ]; then
  cd "$LAZARUS_COMPONENTS"
  svn checkout "$POWERPDF_SVN_URL" "$POWERPDF_DIR"
else
  svn cleanup "$POWERPDF_DIR" || true
  svn update --accept theirs-full "$POWERPDF_DIR"
fi

clean_component_build_artifacts "PowerPDF" "$LAZARUS_COMPONENTS" "$POWERPDF_DIR" "lib"

if [ ! -f "$POWERPDF_LPK" ]; then
  echo "Erro: pacote PowerPDF não encontrado:"
  echo "  $POWERPDF_LPK"
  echo "Verifique se POWERPDF_SVN_URL aponta para o caminho correto."
  exit 1
fi

echo
echo "=============================================="
echo "PowerPDF no Lazarus"
echo "Lazarus : $LAZARUS_DIR"
echo "Comp.   : $LAZARUS_COMPONENTS"
echo "Widget  : ${resp_widget:-padrao}"
echo "Pacote  : $POWERPDF_LPK"
echo "=============================================="

[ -f "$LAZ_BIN" ] && lazarus_timestamp_start=$(stat -c %Y "$LAZ_BIN") || lazarus_timestamp_start=0

"$LAZBUILD" "${LAZBUILD_WIDGETSET_ARGS[@]}" --add-package "$POWERPDF_LPK"
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
echo "Concluído. Abra novamente o Lazarus para ver o PowerPDF disponível."
echo "=============================================="
