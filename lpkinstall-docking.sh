#!/bin/bash
# lpkinstall-docking.sh - Ativa docking na IDE Lazarus

set -e
set -o pipefail

log() {
  echo "$*"
}

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

if [ -n "${1:-}" ] && [ -x "$1/lazbuild" ]; then
  LAZARUS_DIR="${1%/}"
  LAZBUILD_PCP_ARGS=()
  case "$LAZARUS_DIR" in
    *fpcupdeluxe*)
      if [ -d "$(dirname "$LAZARUS_DIR")/config_lazarus" ]; then
        LAZBUILD_PCP_ARGS=(--pcp="$(dirname "$LAZARUS_DIR")/config_lazarus")
      fi
      ;;
  esac
elif [ -x "$HOME/lazarus/lazbuild" ]; then
  LAZARUS_DIR="$HOME/lazarus"
  LAZBUILD_PCP_ARGS=()
elif [ -x "$HOME/fpcupdeluxe/lazarus/lazbuild" ]; then
  LAZARUS_DIR="$HOME/fpcupdeluxe/lazarus"
  LAZBUILD_PCP_ARGS=(--pcp="$HOME/fpcupdeluxe/config_lazarus")
else
  read -r -p "Onde o Lazarus está instalado? " LAZARUS_DIR
  LAZARUS_DIR="${LAZARUS_DIR%/}"
  if [ ! -x "$LAZARUS_DIR/lazbuild" ]; then
    echo "Erro: lazbuild não encontrado em $LAZARUS_DIR"
    exit 1
  fi
  LAZBUILD_PCP_ARGS=()
fi

LAZBUILD="$LAZARUS_DIR/lazbuild"
LAZ_BIN="$LAZARUS_DIR/lazarus"
LAZARUS_COMPONENTS="$LAZARUS_DIR/components"
check_lazarus_closed

if [ ! -d "$LAZARUS_COMPONENTS" ]; then
  echo "Erro: diretório de componentes do Lazarus não encontrado:"
  echo "  $LAZARUS_COMPONENTS"
  exit 1
fi

PACKAGES=()

echo ""
echo "────────── DOCKING ─────────"
echo "Deseja ativar o docking na IDE (S/n)?"
echo -n "> "
read -r resp_docking
resp_docking="${resp_docking:-S}"
if [[ "$resp_docking" =~ ^[Ss]$ ]]; then
  PACKAGES+=(
    "anchordocking/anchordocking.lpk"
    "anchordocking/design/anchordockingdsgn.lpk"
  )
fi

echo ""
echo "Deseja ativar o docking de formulário na IDE (S/n)?"
echo -n "> "
read -r resp_form_docking
resp_form_docking="${resp_form_docking:-S}"
if [[ "$resp_form_docking" =~ ^[Ss]$ ]]; then
  PACKAGES+=("dockedformeditor/dockedformeditor.lpk")
fi

if [ "${#PACKAGES[@]}" -eq 0 ]; then
  echo "Nenhuma opção de docking selecionada."
  exit 0
fi

echo ""
echo "────────── PACOTES A INSTALAR ─────────"
for pkg in "${PACKAGES[@]}"; do
  echo "  - $LAZARUS_COMPONENTS/$pkg"
done
echo
echo -n "Prosseguir com a instalação do docking (S/n)? "
read -r resp
resp="${resp:-S}"
if [[ ! "$resp" =~ ^[Ss]$ ]]; then
  echo "Instalação do docking cancelada."
  exit 0
fi

echo ""
echo "────────── COMPONENTES VISUAIS ─────────"
echo "Pressione ENTER para manter o padrão ou digite: gtk, qt5, qt6"
echo -n "> "
read -r resp_widget
if [[ "$resp_widget" =~ ^[Ss]$ ]]; then
  echo "Resposta ignorada"
  resp_widget=""
fi
LAZBUILD_WIDGETSET_ARGS=()
[ -n "$resp_widget" ] && LAZBUILD_WIDGETSET_ARGS=(--widgetset="$resp_widget")

[ -f "$LAZ_BIN" ] && start_ts=$(stat -c %Y "$LAZ_BIN") || start_ts=0

for p in "${PACKAGES[@]}"; do
  FULL_LPK="$LAZARUS_COMPONENTS/$p"
  if [ ! -f "$FULL_LPK" ]; then
    echo "Erro: pacote não encontrado: $FULL_LPK"
    exit 1
  fi
  log "Registrando: $FULL_LPK"
  "$LAZBUILD" "${LAZBUILD_PCP_ARGS[@]}" "${LAZBUILD_WIDGETSET_ARGS[@]}" --add-package "$FULL_LPK"
done

log "Recompilando a IDE Lazarus..."
"$LAZBUILD" "${LAZBUILD_PCP_ARGS[@]}" "${LAZBUILD_WIDGETSET_ARGS[@]}" --build-ide=

if [ -f "$LAZ_BIN" ]; then
  end_ts=$(stat -c %Y "$LAZ_BIN")
  if [ "$start_ts" -eq "$end_ts" ]; then
    echo "ERRO: a data/hora do binário 'lazarus' não mudou. A recompilação falhou."
    exit 1
  fi
fi

echo "SUCESSO: docking instalado e IDE recompilada."
