#!/bin/bash
# lpkinstall-zeos.sh - Compila (runtime) e instala (design-time) os pacotes Zeos no Lazarus
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: ./lpkinstall-zeos.sh [pasta_lazarus]
# Licença: Uso interno. Proibida a reprodução sem autorização prévia por escrito.
# Criado em: 2026-01-13

set -e
set -o pipefail

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

if [ ! -d "$LAZARUS_COMPONENTS" ]; then
  echo "Erro: diretório de componentes do Lazarus não encontrado:"
  echo "  $LAZARUS_COMPONENTS"
  exit 1
fi

ZEOS_REPO_URL="https://github.com/marsupilami79/zeoslib.git"
ZEOS_DIR="$LAZARUS_COMPONENTS/zeoslib"

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  echo "Erro: não encontrei o executável 'git' no PATH."
  exit 1
}

list_remote_zeos_branches() {
  if [ -e "$ZEOS_DIR" ] && [ ! -d "$ZEOS_DIR/.git" ]; then
    echo "Erro: já existe uma pasta zeoslib, mas ela não é um repositório git:"
    echo "  $ZEOS_DIR"
    exit 1
  fi

  if [ ! -d "$ZEOS_DIR/.git" ]; then
    echo
    echo "Repositório Zeos ainda não existe. Clonando para listar branches remotas..."
    cd "$LAZARUS_COMPONENTS"
    git clone "$ZEOS_REPO_URL"
  fi

  cd "$ZEOS_DIR"
  git fetch --all --prune
  git branch -r
}

select_zeos_branch() {
  local resp_branch

  echo
  echo "─────────────── ZEOS ───────────────"
  echo "Qual branch do Zeos deseja instalar?"
  echo "1) origin/HEAD"
  echo "2) origin/8.0.0-stable"
  echo "3) origin/8.0-patches (padrão)"
  echo "4) outra"
  echo -n "> "
  read -r resp_branch

  case "$resp_branch" in
    ""|3|"origin/8.0-patches")
      ZEOS_BRANCH="origin/8.0-patches"
      ;;
    1|"origin/HEAD")
      ZEOS_BRANCH="origin/HEAD"
      ;;
    2|"origin/8.0.0-stable")
      ZEOS_BRANCH="origin/8.0.0-stable"
      ;;
    4|"outra"|"Outra"|"OUTRA")
      echo
      echo "Branches remotas disponíveis:"
      list_remote_zeos_branches
      echo
      echo -n "Digite a branch remota desejada, por exemplo origin/8.0-patches: "
      read -r ZEOS_BRANCH
      if [ -z "$ZEOS_BRANCH" ]; then
        echo "Erro: branch do Zeos não informada."
        exit 1
      fi
      ;;
    *)
      ZEOS_BRANCH="$resp_branch"
      ;;
  esac
}

switch_zeos_branch() {
  local local_branch

  echo "Selecionando branch do Zeos: $ZEOS_BRANCH"
  if [[ "$ZEOS_BRANCH" == origin/* ]]; then
    local_branch="${ZEOS_BRANCH#origin/}"

    if [ "$local_branch" = "HEAD" ]; then
      git switch --detach "$ZEOS_BRANCH"
    elif git show-ref --verify --quiet "refs/heads/$local_branch"; then
      git switch "$local_branch"
      git branch --set-upstream-to="$ZEOS_BRANCH" "$local_branch" >/dev/null 2>&1 || true
      git pull -f
    else
      git switch --track "$ZEOS_BRANCH"
      git pull -f
    fi
  elif git switch "$ZEOS_BRANCH"; then
    git pull -f || true
  else
    echo "Erro: não foi possível trocar para a branch do Zeos: $ZEOS_BRANCH"
    exit 1
  fi
}

ensure_zeos_repo() {
  if [ -e "$ZEOS_DIR" ] && [ ! -d "$ZEOS_DIR/.git" ]; then
    echo "Erro: já existe uma pasta zeoslib, mas ela não é um repositório git:"
    echo "  $ZEOS_DIR"
    exit 1
  fi

  if [ ! -d "$ZEOS_DIR/.git" ]; then
    cd "$LAZARUS_COMPONENTS"
    git clone "$ZEOS_REPO_URL"
  else
    cd "$ZEOS_DIR"
    if ! git pull -f; then
      echo "Aviso: git pull -f falhou na branch atual. Atualizando referências remotas..."
      git fetch --all --prune
    fi
  fi

  cd "$ZEOS_DIR"
  git fetch --all --prune
  switch_zeos_branch
}

ensure_git
select_zeos_branch
ensure_zeos_repo

echo
echo "────────── COMPONENTES VISUAIS ─────────"
echo "Você deseja usar um widgetset específico ao chamar o lazbuild?"
echo "Pressione ENTER para manter o padrão ou digite: gtk, qt5, qt6"
echo -n "> "
read resp_widget
if [[ "$resp_widget" =~ ^[Ss]$ ]]; then
  # Por engano digitou 'S' então apaga, seguindo o comportamento do instalador ACBr.
  echo "Resposta ignorada"
  resp_widget=""
fi

LAZBUILD_WIDGETSET_ARGS=()
if [ -n "$resp_widget" ]; then
  LAZBUILD_WIDGETSET_ARGS=(--widgetset="$resp_widget")
fi

ensure_fpc() {
  if command -v fpc >/dev/null 2>&1; then
    return 0
  fi

  local v_try
  local v_dir
  v_try="$(find "$HOME/fpcupdeluxe/fpc/bin" -type f -name fpc 2>/dev/null | head -n 1 || true)"

  if [ -n "$v_try" ] && [ -x "$v_try" ]; then
    v_dir="$(dirname "$v_try")"
    export PATH="$v_dir:$PATH"
    if command -v fpc >/dev/null 2>&1; then
      echo "Info: fpc não estava no PATH, adicionado automaticamente:"
      echo "  $v_dir"
      return 0
    fi
  fi

  echo "Erro: não encontrei o executável 'fpc' no PATH."
  exit 1
}

ensure_fpc

ZEOS_LAZARUS_DIR="$ZEOS_DIR/packages/lazarus"

if [ ! -f "$ZEOS_LAZARUS_DIR/zcomponent.lpk" ]; then
  echo
  echo "Erro: estrutura do Zeos inválida."
  echo "Não encontrei:"
  echo "  $ZEOS_LAZARUS_DIR/zcomponent.lpk"
  echo
  echo "Verifique se o repositório Zeos foi baixado corretamente."
  exit 1
fi

RUNTIME_PACKAGES=(
  "zcomponent.lpk"
  "zcore.lpk"
  "zdbc.lpk"
  "zparsesql.lpk"
  "zplain.lpk"
)

DESIGN_PACKAGES=(
  "zcomponentdesign.lpk"
)

build_pkg() {
  local pkgfile="$1"
  echo
  echo "Compilando pacote (runtime):"
  echo "  $pkgfile"
  echo "Comando:"
  echo "  $LAZBUILD ${LAZBUILD_WIDGETSET_ARGS[*]} \"$pkgfile\""
  "$LAZBUILD" "${LAZBUILD_WIDGETSET_ARGS[@]}" "$pkgfile"
}

install_pkg() {
  local pkgfile="$1"
  echo
  echo "Instalando pacote (design-time):"
  echo "  $pkgfile"
  echo "Comando:"
  echo "  $LAZBUILD ${LAZBUILD_WIDGETSET_ARGS[*]} --add-package \"$pkgfile\""
  "$LAZBUILD" "${LAZBUILD_WIDGETSET_ARGS[@]}" --add-package "$pkgfile"
}

rebuild_ide() {
  echo
  echo "Recompilando a IDE Lazarus para aplicar o pacote na paleta..."
  echo "Comando:"
  echo "  $LAZBUILD ${LAZBUILD_WIDGETSET_ARGS[*]} --build-ide="
  "$LAZBUILD" "${LAZBUILD_WIDGETSET_ARGS[@]}" --build-ide=
}

echo
echo "=============================================="
echo "Zeos no Lazarus"
echo "Lazarus : $LAZARUS_DIR"
echo "lazbuild: $LAZBUILD"
echo "Comp.   : $LAZARUS_COMPONENTS"
echo "Branch  : $ZEOS_BRANCH"
echo "Widget  : ${resp_widget:-padrao}"
echo "FPC     : $(command -v fpc)"
echo "Zeos    : $ZEOS_LAZARUS_DIR"
echo "=============================================="

[ -f "$LAZ_BIN" ] && lazarus_timestamp_start=$(stat -c %Y "$LAZ_BIN") || lazarus_timestamp_start=0

for p in "${RUNTIME_PACKAGES[@]}"; do
  if [ ! -f "$ZEOS_LAZARUS_DIR/$p" ]; then
    echo "Erro: pacote não encontrado: $ZEOS_LAZARUS_DIR/$p"
    exit 1
  fi
  build_pkg "$ZEOS_LAZARUS_DIR/$p"
done

for p in "${DESIGN_PACKAGES[@]}"; do
  if [ ! -f "$ZEOS_LAZARUS_DIR/$p" ]; then
    echo "Erro: pacote não encontrado: $ZEOS_LAZARUS_DIR/$p"
    exit 1
  fi
  install_pkg "$ZEOS_LAZARUS_DIR/$p"
done

rebuild_ide

if [ -f "$LAZ_BIN" ]; then
  lazarus_timestamp_end=$(stat -c %Y "$LAZ_BIN")
  if [ "$lazarus_timestamp_start" -eq "$lazarus_timestamp_end" ]; then
    echo "ERRO: a data/hora do binário 'lazarus' não mudou. A recompilação da IDE pode ter falhado."
    exit 1
  fi
else
  echo "ERRO: binário do Lazarus não encontrado após a recompilação:"
  echo "  $LAZ_BIN"
  exit 1
fi

echo
echo "=============================================="
echo "Concluído."
echo "IDE Lazarus recompilada. Abra novamente o Lazarus para ver o Zeos na paleta."
echo "=============================================="
