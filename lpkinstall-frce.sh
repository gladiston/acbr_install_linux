#!/bin/bash
# lpkinstall-fortesreport-ce.sh - Compila e instala o FortesReport-CE no Lazarus (via lazbuild)
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: ./lpkinstall-fortesreport-ce.sh [pasta_lazarus]
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

# -------------------------------------------------
# 1) Pasta do Lazarus (assumida) e lazbuild
# -------------------------------------------------

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
  echo "  lpkinstall-acbr.sh"
  exit 1
fi

FORTES_REPO_URL="https://github.com/fortesinformatica/fortesreport-ce.git"
FORTES_DIR="$LAZARUS_COMPONENTS/fortesreport-ce"

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi

  echo "Erro: não encontrei o executável 'git' no PATH."
  exit 1
}

list_remote_fortes_branches() {
  if [ -e "$FORTES_DIR" ] && [ ! -d "$FORTES_DIR/.git" ]; then
    echo "Erro: já existe uma pasta fortesreport-ce, mas ela não é um repositório git:"
    echo "  $FORTES_DIR"
    exit 1
  fi

  if [ ! -d "$FORTES_DIR/.git" ]; then
    echo
    echo "Repositório FortesReport-CE ainda não existe. Clonando para listar branches remotas..."
    cd "$LAZARUS_COMPONENTS"
    git clone "$FORTES_REPO_URL"
  fi

  cd "$FORTES_DIR"
  git fetch --all --prune
  git branch -r
}

select_fortes_branch() {
  local resp_branch

  echo
  echo "──────────── FORTESREPORT-CE ────────────"
  echo "Qual branch do FortesReport-CE deseja instalar?"
  echo "1) origin/HEAD (padrão)"
  echo "2) outros"
  echo -n "> "
  read -r resp_branch

  case "$resp_branch" in
    ""|1|"origin/HEAD")
      FORTES_BRANCH="origin/HEAD"
      ;;
    2|"outros"|"Outros"|"OUTROS"|"outra"|"Outra"|"OUTRA")
      echo
      echo "Branches remotas disponíveis:"
      list_remote_fortes_branches
      echo
      echo -n "Digite a branch remota desejada, por exemplo origin/master: "
      read -r FORTES_BRANCH
      if [ -z "$FORTES_BRANCH" ]; then
        echo "Erro: branch do FortesReport-CE não informada."
        exit 1
      fi
      ;;
    *)
      FORTES_BRANCH="$resp_branch"
      ;;
  esac
}

switch_fortes_branch() {
  local local_branch

  echo "Selecionando branch do FortesReport-CE: $FORTES_BRANCH"
  if [[ "$FORTES_BRANCH" == origin/* ]]; then
    local_branch="${FORTES_BRANCH#origin/}"

    if [ "$local_branch" = "HEAD" ]; then
      git switch --detach "$FORTES_BRANCH"
    elif git show-ref --verify --quiet "refs/heads/$local_branch"; then
      git switch "$local_branch"
      git branch --set-upstream-to="$FORTES_BRANCH" "$local_branch" >/dev/null 2>&1 || true
      git pull -f
    else
      git switch --track "$FORTES_BRANCH"
      git pull -f
    fi
  elif git switch "$FORTES_BRANCH"; then
    git pull -f || true
  else
    echo "Erro: não foi possível trocar para a branch do FortesReport-CE: $FORTES_BRANCH"
    exit 1
  fi
}

ensure_fortes_repo() {
  if [ -e "$FORTES_DIR" ] && [ ! -d "$FORTES_DIR/.git" ]; then
    echo "Erro: já existe uma pasta fortesreport-ce, mas ela não é um repositório git:"
    echo "  $FORTES_DIR"
    exit 1
  fi

  if [ ! -d "$FORTES_DIR/.git" ]; then
    cd "$LAZARUS_COMPONENTS"
    git clone "$FORTES_REPO_URL"
  else
    cd "$FORTES_DIR"
    if ! git pull -f; then
      echo "Aviso: git pull -f falhou na branch atual. Atualizando referências remotas..."
      git fetch --all --prune
    fi
  fi

  cd "$FORTES_DIR"
  git fetch --all --prune
  switch_fortes_branch
}

# -------------------------------------------------
# 2) Escolha de Widgetset (Interface)
# -------------------------------------------------

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

ensure_git
select_fortes_branch
ensure_fortes_repo

# -------------------------------------------------
# 3) Garantir FPC no PATH (necessário pro fppkg)
# -------------------------------------------------

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

# -------------------------------------------------
# 4) Estrutura do FortesReport-CE
# -------------------------------------------------

FRCE_LPK="$FORTES_DIR/Packages/frce.lpk"

if [ ! -f "$FRCE_LPK" ]; then
  echo
  echo "Erro: estrutura do FortesReport-CE inválida."
  echo "Não encontrei:"
  echo "  $FRCE_LPK"
  echo
  echo "Verifique se o repositório FortesReport-CE foi baixado corretamente."
  exit 1
fi

# -------------------------------------------------
# 5) Instalar pacote design-time
# -------------------------------------------------

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
echo "FortesReport-CE no Lazarus"
echo "Lazarus : $LAZARUS_DIR"
echo "lazbuild: $LAZBUILD"
echo "Comp.   : $LAZARUS_COMPONENTS"
echo "Branch  : $FORTES_BRANCH"
echo "Widget  : ${resp_widget:-padrao}"
echo "FPC     : $(command -v fpc)"
echo "Pacote  : $FRCE_LPK"
echo "=============================================="

[ -f "$LAZ_BIN" ] && lazarus_timestamp_start=$(stat -c %Y "$LAZ_BIN") || lazarus_timestamp_start=0

install_pkg "$FRCE_LPK"
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
echo "IDE Lazarus recompilada. Abra novamente o Lazarus para ver o FortesReport-CE na paleta."
echo "=============================================="
