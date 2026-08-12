#!/bin/bash
# lpkinstall-redockask.sh - Faz o Lazarus perguntar de novo sobre docking no próximo start
# Zera DoneAskUserEnableAnchorDock e DoneAskUserEnableDockedDesigner no PCP.
# Se os pacotes de docking não estiverem na IDE, executa lpkinstall-docking.sh antes.

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "Feche o Lazarus antes de alterar a configuração e execute este script novamente."
    echo
    echo "$running"
    exit 1
  fi
}

set_config_xml_bool() {
  local xml_path="$1"
  local tag_name="$2"
  local bool_text="$3"
  local dir new_tag

  dir="$(dirname "$xml_path")"
  mkdir -p "$dir"

  if [ ! -f "$xml_path" ]; then
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<CONFIG>' '</CONFIG>' >"$xml_path"
  fi

  new_tag="<${tag_name} Value=\"${bool_text}\"/>"
  if grep -Eq "<${tag_name}[[:space:]]+Value=\"[^\"]*\"[[:space:]]*/[[:space:]]*>" "$xml_path"; then
    sed -E -i "s|<${tag_name}[[:space:]]+Value=\"[^\"]*\"[[:space:]]*/[[:space:]]*>|${new_tag}|I" "$xml_path"
  else
    if ! grep -q '</CONFIG>' "$xml_path"; then
      echo "Erro: XML inválido: $xml_path"
      exit 1
    fi
    sed -i "s|</CONFIG>|  ${new_tag}\n</CONFIG>|" "$xml_path"
  fi
}

docking_ask_packages_installed() {
  local content=""
  local f

  f="$PCP_DIR/staticpackages.inc"
  [ -f "$f" ] && content+="$(cat "$f")"
  f="$PCP_DIR/packagefiles.xml"
  [ -f "$f" ] && content+="$(cat "$f")"
  content="$(printf '%s' "$content" | tr '[:upper:]' '[:lower:]')"

  [[ "$content" == *anchordockingdsgn* ]] && [[ "$content" == *dockedformeditor* ]]
}

run_docking_installer() {
  local docking_script="$SCRIPT_DIR/lpkinstall-docking.sh"
  if [ ! -f "$docking_script" ]; then
    echo "Erro: script não encontrado: $docking_script"
    exit 1
  fi
  if [ ! -x "$docking_script" ]; then
    echo "Erro: script sem permissão de execução: $docking_script"
    exit 1
  fi

  export ACBR_PCP="$PCP_DIR"
  if [ "${#PCP_ARGS[@]}" -gt 0 ]; then
    export ACBR_USE_PCP=1
  else
    export ACBR_USE_PCP=0
  fi

  echo
  echo "Executando instalação de docking..."
  "$docking_script" "$LAZARUS_DIR"
}

if [ -n "${1:-}" ] && [ -x "$1/lazbuild" ]; then
  LAZARUS_DIR="${1%/}"
elif [ -x "$HOME/lazarus/lazbuild" ]; then
  LAZARUS_DIR="$HOME/lazarus"
elif [ -x "$HOME/fpcupdeluxe/lazarus/lazbuild" ]; then
  LAZARUS_DIR="$HOME/fpcupdeluxe/lazarus"
else
  read -r -p "Onde o Lazarus está instalado? " LAZARUS_DIR
  LAZARUS_DIR="${LAZARUS_DIR%/}"
  if [ ! -x "$LAZARUS_DIR/lazbuild" ]; then
    echo "Erro: lazbuild não encontrado em $LAZARUS_DIR"
    exit 1
  fi
fi

LAZ_BIN="$LAZARUS_DIR/lazarus"
check_lazarus_closed

suggested_pcp="$HOME/.lazarus"
default_pcp="N"
if [[ "$LAZARUS_DIR" == *fpcupdeluxe* ]]; then
  default_pcp="S"
  parent_cfg="$(dirname "$LAZARUS_DIR")/config_lazarus"
  if [ -d "$parent_cfg" ]; then
    suggested_pcp="$parent_cfg"
  else
    suggested_pcp="$HOME/fpcupdeluxe/config_lazarus"
  fi
fi

echo
echo "---------- REPERGUNTAR DOCKING ---------"
echo "No primeiro start, o Lazarus pergunta se deseja IDE com docking"
echo "(janela única) ou multi-janela. Essa escolha fica gravada no PCP."
echo "Requer os pacotes AnchorDockingDsgn e DockedFormEditor na IDE."
echo
echo "Sugestão de PCP: $suggested_pcp"
if [ "$default_pcp" = "S" ]; then
  echo -n "Você usa --pcp para carregar o Lazarus? (S/n) "
else
  echo -n "Você usa --pcp para carregar o Lazarus? (s/N) "
fi
read -r use_pcp
use_pcp="${use_pcp:-$default_pcp}"

PCP_DIR="$HOME/.lazarus"
PCP_ARGS=()
if [[ "$use_pcp" =~ ^[Ss]$ ]]; then
  echo -n "Informe o caminho do PCP (ENTER = sugestão): "
  read -r resp_pcp
  resp_pcp="${resp_pcp:-$suggested_pcp}"
  PCP_DIR="${resp_pcp%/}"
  PCP_ARGS=(--pcp="$PCP_DIR")
  log "Usando --pcp=$PCP_DIR"
else
  log "Usando PCP padrão: $PCP_DIR"
fi

echo
echo "Este script zera as flags DoneAskUser* em:"
echo "  $PCP_DIR"
echo "para o Lazarus perguntar de novo na próxima abertura"
echo "(AnchorDocking + DockedFormEditor)."
echo

if docking_ask_packages_installed; then
  log "Pacotes de docking já encontrados no PCP."
  echo -n "Prosseguir e resetar a pergunta de docking (S/n)? "
  read -r resp
  resp="${resp:-S}"
  if [[ ! "$resp" =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
  fi
else
  log "Pacotes de docking NÃO encontrados em staticpackages.inc / packagefiles.xml."
  log "É necessário instalar o docking antes de repergunta."
  echo -n "Instalar docking agora e depois resetar a pergunta (S/n)? "
  read -r resp
  resp="${resp:-S}"
  if [[ ! "$resp" =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
  fi
  run_docking_installer
  if ! docking_ask_packages_installed; then
    echo "Erro: após a instalação, AnchorDockingDsgn e/ou DockedFormEditor ainda não aparecem no PCP."
    echo "Na opção de docking, confirme as duas opções (IDE e formulário) e tente novamente."
    exit 1
  fi
  log "Pacotes de docking confirmados no PCP. Prosseguindo com o reset das flags..."
fi

mkdir -p "$PCP_DIR"
set_config_xml_bool "$PCP_DIR/anchordockingoptions.xml" "DoneAskUserEnableAnchorDock" "False"
log "OK: $PCP_DIR/anchordockingoptions.xml -> DoneAskUserEnableAnchorDock=False"
set_config_xml_bool "$PCP_DIR/dockedformeditoroptions.xml" "DoneAskUserEnableDockedDesigner" "False"
log "OK: $PCP_DIR/dockedformeditoroptions.xml -> DoneAskUserEnableDockedDesigner=False"

echo
echo "Pronto. Abra o Lazarus de novo; o diálogo inicial deve perguntar sobre docking."
echo
echo -n "Deseja abrir o Lazarus agora (S/n)? "
read -r open_now
open_now="${open_now:-S}"
if [[ "$open_now" =~ ^[Ss]$ ]]; then
  if [ -x "$LAZ_BIN" ]; then
    log "Iniciando: $LAZ_BIN ${PCP_ARGS[*]}"
    nohup "$LAZ_BIN" "${PCP_ARGS[@]}" >/dev/null 2>&1 &
  else
    echo "Aviso: binário lazarus não encontrado em $LAZ_BIN"
  fi
fi

echo "SUCESSO."
