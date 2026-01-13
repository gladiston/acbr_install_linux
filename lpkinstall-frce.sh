#!/bin/bash
# lpkinstall-fortesreport-ce.sh - Compila e instala o FortesReport-CE no Lazarus (via lazbuild)
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: ./lpkinstall-fortesreport-ce.sh [pasta_lazarus] [pasta_onde_existe_fortesreport-ce]
# Licença: Uso interno. Proibida a reprodução sem autorização prévia por escrito.
# Criado em: 2026-01-13
#
# Observação:
# - O 2º parâmetro deve apontar para uma pasta que CONTENHA a subpasta "fortesreport-ce".
#   O script validará: <pasta>/fortesreport-ce/Packages/frce.lpk

set -e
set -o pipefail

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

if [ ! -x "$LAZBUILD" ]; then
  echo "Erro: lazbuild não encontrado dentro da pasta do Lazarus."
  echo "Esperado:"
  echo "  $LAZBUILD"
  exit 1
fi

# -------------------------------------------------
# 2) Garantir FPC no PATH (necessário pro fppkg)
# -------------------------------------------------

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

# -------------------------------------------------
# 3) Pasta onde EXISTE a subpasta fortesreport-ce
# -------------------------------------------------

FORTES_PARENT_DIR="${2:-$(pwd)}"

if [ ! -d "$FORTES_PARENT_DIR" ]; then
  echo "Erro: pasta informada para o FortesReport-CE não existe:"
  echo "  $FORTES_PARENT_DIR"
  exit 1
fi

FRCE_LPK="$FORTES_PARENT_DIR/fortesreport-ce/Packages/frce.lpk"

if [ ! -f "$FRCE_LPK" ]; then
  echo
  echo "Erro: estrutura do FortesReport-CE inválida."
  echo "Não encontrei:"
  echo "  $FRCE_LPK"
  echo
  echo "A pasta informada deve CONTER a subpasta 'fortesreport-ce'."
  exit 1
fi

# -------------------------------------------------
# 4) Instalar pacote design-time
# -------------------------------------------------

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
echo "FortesReport-CE no Lazarus"
echo "Lazarus : $LAZARUS_DIR"
echo "lazbuild: $LAZBUILD"
echo "FPC     : $(command -v fpc)"
echo "Pacote  : $FRCE_LPK"
echo "=============================================="

install_pkg "$FRCE_LPK"

echo
echo "=============================================="
echo "Concluído."
echo "Reinicie o Lazarus para aplicar as alterações."
echo "=============================================="
