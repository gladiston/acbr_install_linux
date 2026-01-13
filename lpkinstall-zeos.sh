#!/bin/bash
# lpkinstall-zeos.sh - Compila (runtime) e instala (design-time) os pacotes Zeos no Lazarus
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: ./lpkinstall-zeos.sh [pasta_lazarus] [pasta_onde_existe_zeoslib]
# Licença: Uso interno. Proibida a reprodução sem autorização prévia por escrito.
# Criado em: 2026-01-13

set -e
set -o pipefail

LAZARUS_DIR="${1:-$HOME/fpcupdeluxe/lazarus}"

if [ ! -d "$LAZARUS_DIR" ]; then
  echo "Erro: pasta do Lazarus não encontrada:"
  echo "  $LAZARUS_DIR"
  exit 1
fi

LAZBUILD="$LAZARUS_DIR/lazbuild"

if [ ! -x "$LAZBUILD" ]; then
  echo "Erro: lazbuild não encontrado dentro da pasta do Lazarus."
  echo "Esperado:"
  echo "  $LAZBUILD"
  exit 1
fi

ensure_fpc() {
  if command -v fpc >/dev/null 2>&1; then
    return 0
  fi

  local v_try=""
  v_try="$(find "$HOME/fpcupdeluxe/fpc/bin" -type f -name fpc 2>/dev/null | head -n 1 || true)"

  if [ -n "$v_try" ] && [ -x "$v_try" ]; then
    export PATH="$(dirname "$v_try"):$PATH"
    if command -v fpc >/dev/null 2>&1; then
      echo "Info: fpc não estava no PATH, adicionado automaticamente:"
      echo "  $(dirname "$v_try")"
      return 0
    fi
  fi

  echo "Erro: não encontrei o executável 'fpc' no PATH."
  exit 1
}

ensure_fpc

ZEOS_PARENT_DIR="${2:-$(pwd)}"

if [ ! -d "$ZEOS_PARENT_DIR" ]; then
  echo "Erro: pasta informada para o Zeos não existe:"
  echo "  $ZEOS_PARENT_DIR"
  exit 1
fi

ZEOS_LAZARUS_DIR="$ZEOS_PARENT_DIR/zeoslib/packages/lazarus"

if [ ! -f "$ZEOS_LAZARUS_DIR/zcomponent.lpk" ]; then
  echo
  echo "Erro: estrutura do Zeos inválida."
  echo "Não encontrei:"
  echo "  $ZEOS_LAZARUS_DIR/zcomponent.lpk"
  echo
  echo "A pasta informada deve CONTER a subpasta 'zeoslib'."
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
  echo "  $LAZBUILD \"$pkgfile\""
  "$LAZBUILD" "$pkgfile"
}

install_pkg() {
  local pkgfile="$1"
  echo
  echo "Instalando pacote (design-time):"
  echo "  $pkgfile"
  echo "Comando:"
  echo "  $LAZBUILD --add-package \"$pkgfile\""
  "$LAZBUILD" --add-package "$pkgfile"
}

echo
echo "=============================================="
echo "Zeos no Lazarus"
echo "Lazarus : $LAZARUS_DIR"
echo "lazbuild: $LAZBUILD"
echo "FPC     : $(command -v fpc)"
echo "Zeos    : $ZEOS_LAZARUS_DIR"
echo "=============================================="

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

echo
echo "=============================================="
echo "Concluído."
echo "Reinicie o Lazarus para aplicar as alterações."
echo "=============================================="
