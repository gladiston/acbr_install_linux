#!/bin/bash
# download-lazideexportsettings.sh
# Baixa (e opcionalmente compila) o utilitário lazIdeExportSettings
# Fonte: https://github.com/DomingoGP/lazIdeExportSettings

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_URL="https://github.com/DomingoGP/lazIdeExportSettings.git"
REPO_NAME="lazIdeExportSettings"
LPI_NAME="lazexportsettings.lpi"
EXE_NAME="lazexportsettings"

log() {
  echo "$*"
}

documents_dir() {
  local d
  if command -v xdg-user-dir >/dev/null 2>&1; then
    d="$(xdg-user-dir DOCUMENTS 2>/dev/null || true)"
  fi
  if [ -z "$d" ] || [ "$d" = "$HOME" ]; then
    if [ -d "$HOME/Documents" ]; then
      d="$HOME/Documents"
    elif [ -d "$HOME/Documentos" ]; then
      d="$HOME/Documentos"
    else
      d="$HOME/Documents"
    fi
  fi
  printf '%s' "$d"
}

desktop_dir() {
  local d
  if command -v xdg-user-dir >/dev/null 2>&1; then
    d="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  fi
  if [ -z "$d" ] || [ "$d" = "$HOME" ]; then
    d="$HOME/Desktop"
  fi
  printf '%s' "$d"
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-N}"
  local hint resp
  if [ "$default" = "S" ] || [ "$default" = "s" ]; then
    hint="S/n"
    default="S"
  else
    hint="s/N"
    default="N"
  fi
  echo -n "$prompt ($hint)? "
  read -r resp
  resp="${resp:-$default}"
  [[ "$resp" =~ ^[Ss]$ ]]
}

create_desktop_shortcut() {
  local exe_path="$1"
  local work_dir="$2"
  local desk desktop_file

  desk="$(desktop_dir)"
  mkdir -p "$desk"
  desktop_file="$desk/lazIdeExportSettings.desktop"
  cat >"$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=lazIdeExportSettings
Comment=Exportar/importar configuracoes do Lazarus IDE
Exec=$exe_path
Path=$work_dir
Icon=application-x-executable
Terminal=false
Categories=Development;
EOF
  chmod +x "$desktop_file" || true
  if command -v gio >/dev/null 2>&1; then
    gio set "$desktop_file" metadata::trusted true 2>/dev/null || true
  fi
  log "Atalho criado: $desktop_file"
}

find_built_exe() {
  local project_dir="$1"
  local c
  for c in \
    "$project_dir/$EXE_NAME" \
    "$project_dir/lazexportsettings" \
    "$project_dir/bin/$EXE_NAME"
  do
    if [ -x "$c" ]; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

DOCS_DIR="$(documents_dir)"
DEST_DIR="$DOCS_DIR/$REPO_NAME"

echo
echo "---------- lazIdeExportSettings ----------"
echo "Utilitário standalone para exportar e importar algumas"
echo "configurações do Lazarus IDE (https://www.lazarus-ide.org/)."
echo
echo "Exporta / importa, entre outros:"
echo "  - Opções do editor (templates, esquemas de cores)"
echo "  - Macros do editor"
echo "  - Editor de formulários"
echo "  - Object Inspector"
echo "  - Code Tools (incl. arquivo de amostra de indentação)"
echo "  - Debugger"
echo "  - Jedi Code Format"
echo "  - Conversor Delphi"
echo "  - Desktop(s)"
echo
echo "NÃO exporta/importa pacotes instalados."
echo "Feche o Lazarus antes de exportar/importar."
echo "AVISO: importar pode quebrar a instalação (config incompatível"
echo "entre versões). Faça backup da pasta de configuração (--pcp) antes."
echo
echo "Projeto: https://github.com/DomingoGP/lazIdeExportSettings"
echo "O código será baixado em: $DEST_DIR"
echo

INSTALL_AFTER=0
if ask_yes_no "Deseja instalar (compilar) após o download" "N"; then
  INSTALL_AFTER=1
fi

echo
echo "Resumo:"
echo "  Destino : $DEST_DIR"
if [ "$INSTALL_AFTER" -eq 1 ]; then
  echo "  Após download: compilar e criar atalho na Área de Trabalho"
else
  echo "  Após download: apenas clonar (sem instalar)"
fi
echo

if ! ask_yes_no "Prosseguir com o download" "S"; then
  echo "Cancelado."
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Erro: não encontrei o executável 'git' no PATH."
  exit 1
fi

if [ -e "$DEST_DIR" ] && [ ! -d "$DEST_DIR/.git" ]; then
  echo "Erro: já existe a pasta, mas não é um repositório git:"
  echo "  $DEST_DIR"
  exit 1
fi

mkdir -p "$DOCS_DIR"
if [ ! -d "$DEST_DIR/.git" ]; then
  log "Clonando repositório..."
  git clone "$REPO_URL" "$DEST_DIR"
else
  log "Repositório já existe. Atualizando (git pull)..."
  if ! git -C "$DEST_DIR" pull -f; then
    log "Aviso: git pull falhou; tentando fetch..."
    git -C "$DEST_DIR" fetch --all --prune || true
  fi
fi

LPI_PATH="$DEST_DIR/$LPI_NAME"
if [ ! -f "$LPI_PATH" ]; then
  echo "Erro: clone incompleto; não encontrei $LPI_PATH"
  exit 1
fi
log "Download concluído: $DEST_DIR"

if [ "$INSTALL_AFTER" -ne 1 ]; then
  log "Instalação/compilação não solicitada."
  log "Para compilar depois: lazbuild \"$LPI_PATH\""
  echo "SUCESSO."
  exit 0
fi

echo
echo "---------- COMPILAÇÃO ----------"

# Detecta Lazarus (mesmo padrão dos demais scripts)
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

LAZBUILD="$LAZARUS_DIR/lazbuild"
LAZBUILD_PCP_ARGS=()
case "$LAZARUS_DIR" in
  *fpcupdeluxe*)
    if [ -d "$(dirname "$LAZARUS_DIR")/config_lazarus" ]; then
      LAZBUILD_PCP_ARGS=(--pcp="$(dirname "$LAZARUS_DIR")/config_lazarus")
    elif [ -d "$HOME/fpcupdeluxe/config_lazarus" ]; then
      LAZBUILD_PCP_ARGS=(--pcp="$HOME/fpcupdeluxe/config_lazarus")
    fi
    ;;
esac

if ! command -v fpc >/dev/null 2>&1; then
  v_try="$(find "$HOME/fpcupdeluxe/fpc/bin" -type f -name fpc 2>/dev/null | head -n 1 || true)"
  if [ -n "$v_try" ] && [ -x "$v_try" ]; then
    export PATH="$(dirname "$v_try"):$PATH"
  fi
fi
if ! command -v fpc >/dev/null 2>&1; then
  echo "Erro: não encontrei o executável 'fpc' no PATH."
  exit 1
fi

echo
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

EXE_PATH=""
if EXE_PATH="$(find_built_exe "$DEST_DIR")"; then
  TS_BEFORE=$(stat -c %Y "$EXE_PATH" 2>/dev/null || echo 0)
else
  EXE_PATH=""
  TS_BEFORE=0
fi

log "Compilando: $LPI_PATH"
"$LAZBUILD" "${LAZBUILD_PCP_ARGS[@]}" "${LAZBUILD_WIDGETSET_ARGS[@]}" "$LPI_PATH"

if ! EXE_PATH="$(find_built_exe "$DEST_DIR")"; then
  echo "Erro: compilação terminou, mas o executável não foi encontrado."
  echo "Esperado: $DEST_DIR/$EXE_NAME"
  exit 1
fi
TS_AFTER=$(stat -c %Y "$EXE_PATH" 2>/dev/null || echo 0)
if [ "$TS_BEFORE" -gt 0 ] && [ "$TS_AFTER" -le "$TS_BEFORE" ]; then
  log "Aviso: a data/hora do executável não mudou; usando o binário existente."
fi
log "Executável: $EXE_PATH"

create_desktop_shortcut "$EXE_PATH" "$DEST_DIR"
log "SUCESSO: lazIdeExportSettings baixado, compilado e atalho criado."
