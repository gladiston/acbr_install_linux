#!/bin/bash
# lpkinstall-ideajustes.sh
# Aplica o perfil ide-ajustes-editor (ajustes pessoais da IDE) no PCP do Lazarus.

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_ROOT="$SCRIPT_DIR/ide-ajustes-editor"
PROFILE_FILES="$PROFILE_ROOT/files"

log() { echo "$*"; }

ask_yes_no() {
  local prompt="$1"
  local default="${2:-S}"
  local hint resp
  if [ "$default" = "S" ] || [ "$default" = "s" ]; then
    hint="S/n"; default="S"
  else
    hint="s/N"; default="N"
  fi
  echo -n "$prompt ($hint)? "
  read -r resp
  resp="${resp:-$default}"
  [[ "$resp" =~ ^[Ss]$ ]]
}

check_lazarus_closed() {
  local running
  if ! command -v pgrep >/dev/null 2>&1; then
    return 0
  fi
  running="$(pgrep -u "$(id -u)" -af '(^|/)(lazarus|startlazarus)([[:space:]]|$)' || true)"
  if [ -n "$running" ]; then
    echo "Erro: a IDE Lazarus parece estar aberta."
    echo "Feche o Lazarus antes de aplicar os ajustes."
    echo
    echo "$running"
    exit 1
  fi
}

expand_profile_text() {
  local text="$1"
  text="${text//__PCP_DIR__/$PCP_DIR}"
  text="${text//__LAZARUS_DIR__/$LAZARUS_DIR}"
  text="${text//__TEMP_DIR__/${TMPDIR:-/tmp}}"
  printf '%s' "$text"
}

write_expanded_file() {
  local src_name="$1"
  local dest_path="$2"
  local src="$PROFILE_FILES/$src_name"
  local text
  if [ ! -f "$src" ]; then
    echo "Erro: arquivo do perfil ausente: $src"
    exit 1
  fi
  text="$(expand_profile_text "$(cat "$src")")"
  printf '%s' "$text" >"$dest_path"
  log "Aplicado: $dest_path"
}

merge_environment_options() {
  local live_path="$PCP_DIR/environmentoptions.xml"
  local src="$PROFILE_FILES/environmentoptions.xml"
  local tmp_prof tmp_out

  if [ ! -f "$src" ]; then
    log "Aviso: environmentoptions.xml ausente no perfil; pulando merge."
    return 0
  fi

  if [ ! -f "$live_path" ]; then
    write_expanded_file "environmentoptions.xml" "$live_path"
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    log "Aviso: python3 nao encontrado; gravando environmentoptions.xml completo do perfil."
    write_expanded_file "environmentoptions.xml" "$live_path"
    return 0
  fi

  tmp_prof="$(mktemp)"
  tmp_out="$(mktemp)"
  expand_profile_text "$(cat "$src")" >"$tmp_prof"

  python3 - "$live_path" "$tmp_prof" "$tmp_out" <<'PY'
import sys
import xml.etree.ElementTree as ET

live_path, prof_path, out_path = sys.argv[1:4]
live = ET.parse(live_path)
prof = ET.parse(prof_path)
live_root = live.getroot()
prof_root = prof.getroot()

def child(parent, name):
    if parent is None:
        return None
    for c in list(parent):
        if c.tag == name:
            return c
    return None

def merge_named(live_parent, prof_parent, name):
    if live_parent is None or prof_parent is None:
        return
    src = child(prof_parent, name)
    if src is None:
        return
    old = child(live_parent, name)
    # deepcopy via fromstring/tostring
    imported = ET.fromstring(ET.tostring(src, encoding="utf-8"))
    if old is not None:
        idx = list(live_parent).index(old)
        live_parent.remove(old)
        live_parent.insert(idx, imported)
    else:
        live_parent.append(imported)

live_env = child(live_root, "EnvironmentOptions")
prof_env = child(prof_root, "EnvironmentOptions")
if live_env is None:
    raise SystemExit("environmentoptions.xml ao vivo sem EnvironmentOptions")

for name in ("FormEditor", "Language", "BackupOtherFiles", "CompilerMessagesFilename", "OptionDialog"):
    merge_named(live_env, prof_env, name)

for name in ("Desktops", "AnchorDocking"):
    merge_named(live_root, prof_root, name)

live.write(out_path, encoding="UTF-8", xml_declaration=True)
PY

  mv -f "$tmp_out" "$live_path"
  rm -f "$tmp_prof"
  log "Aplicado (merge): $live_path"
}

if [ ! -d "$PROFILE_FILES" ]; then
  echo "Erro: perfil nao encontrado:"
  echo "  $PROFILE_FILES"
  exit 1
fi

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
echo "---------- AJUSTES DO CURADOR NA IDE ----------"
echo "Reaplica preferências pessoais capturadas da IDE:"
echo "  - Editor (fonte, margem, atalhos, folding, highlight)"
echo "  - Code Tools / Help / IconFinder"
echo "  - FormEditor, idioma, backup, OptionDialog"
echo "  - Desktops / AnchorDocking"
echo
echo "Perfil : $PROFILE_ROOT"
echo "Sugestão de PCP: $suggested_pcp"
if [ "$default_pcp" = "S" ]; then
  echo -n "Você usa --pcp para carregar o Lazarus? (S/n) "
else
  echo -n "Você usa --pcp para carregar o Lazarus? (s/N) "
fi
read -r use_pcp
use_pcp="${use_pcp:-$default_pcp}"

PCP_DIR="$HOME/.lazarus"
if [[ "$use_pcp" =~ ^[Ss]$ ]]; then
  echo -n "Informe o caminho do PCP (ENTER = sugestão): "
  read -r resp_pcp
  PCP_DIR="${resp_pcp:-$suggested_pcp}"
  PCP_DIR="${PCP_DIR%/}"
  log "Usando --pcp=$PCP_DIR"
else
  log "Usando PCP padrão: $PCP_DIR"
fi

echo
if ! ask_yes_no "Aplicar os ajustes do curador na IDE neste PCP" "S"; then
  echo "Cancelado."
  exit 0
fi

mkdir -p "$PCP_DIR"
write_expanded_file "editoroptions.xml" "$PCP_DIR/editoroptions.xml"
write_expanded_file "codetoolsoptions.xml" "$PCP_DIR/codetoolsoptions.xml"
write_expanded_file "helpoptions.xml" "$PCP_DIR/helpoptions.xml"
write_expanded_file "iconfindercfg.xml" "$PCP_DIR/iconfindercfg.xml"
merge_environment_options

echo
log "SUCESSO: ajustes aplicados."
log "Abra o Lazarus para conferir fonte, desktops e demais preferências."
