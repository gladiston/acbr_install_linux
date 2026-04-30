#!/bin/bash
# lpkinstall-synapse.sh - Baixa e compila o pacote runtime Synapse no Lazarus

set -e
set -o pipefail

SYNAPSE_GIT_URL="https://github.com/geby/synapse.git"

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

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  echo "Erro: não encontrei o executável 'git' no PATH."
  echo "Instale o Git e execute este script novamente."
  exit 1
}

find_synapse_lpk() {
  local candidate
  local candidates=(
    "$SYNAPSE_DIR/laz_synapse.lpk"
    "$SYNAPSE_DIR/source/lib/laz_synapse.lpk"
    "$SYNAPSE_DIR/packages/lazarus/laz_synapse.lpk"
  )

  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

LAZARUS_DIR="${1:-$HOME/fpcupdeluxe/lazarus}"

if [ ! -d "$LAZARUS_DIR" ]; then
  echo "Erro: pasta do Lazarus não encontrada:"
  echo "  $LAZARUS_DIR"
  exit 1
fi

LAZBUILD="$LAZARUS_DIR/lazbuild"

check_lazarus_closed

if [ ! -x "$LAZBUILD" ]; then
  echo "Erro: lazbuild não encontrado dentro da pasta do Lazarus."
  echo "Esperado:"
  echo "  $LAZBUILD"
  exit 1
fi

LAZARUS_COMPONENTS="$LAZARUS_DIR/components"
SYNAPSE_DIR="$LAZARUS_COMPONENTS/synapse"

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

ensure_git

if [ -e "$SYNAPSE_DIR" ] && [ ! -d "$SYNAPSE_DIR/.git" ]; then
  echo "Erro: já existe uma pasta synapse, mas ela não é um repositório git válido:"
  echo "  $SYNAPSE_DIR"
  exit 1
fi

if [ ! -d "$SYNAPSE_DIR/.git" ]; then
  cd "$LAZARUS_COMPONENTS"
  git clone "$SYNAPSE_GIT_URL" "$SYNAPSE_DIR"
else
  cd "$SYNAPSE_DIR"
  git pull -f
fi

SYNAPSE_LPK="$(find_synapse_lpk || true)"
if [ -z "$SYNAPSE_LPK" ]; then
  echo "Erro: pacote laz_synapse.lpk não encontrado em caminhos conhecidos dentro de:"
  echo "  $SYNAPSE_DIR"
  echo "Verifique se SYNAPSE_GIT_URL aponta para o caminho correto."
  exit 1
fi

echo
echo "=============================================="
echo "Synapse no Lazarus"
echo "Lazarus : $LAZARUS_DIR"
echo "Comp.   : $LAZARUS_COMPONENTS"
echo "Widget  : ${resp_widget:-padrao}"
echo "Pacote  : $SYNAPSE_LPK"
echo "Tipo    : runtime"
echo "=============================================="

"$LAZBUILD" "${LAZBUILD_WIDGETSET_ARGS[@]}" "$SYNAPSE_LPK"

echo
echo "=============================================="
echo "Concluído. Pacote runtime Synapse compilado com sucesso."
echo "=============================================="
