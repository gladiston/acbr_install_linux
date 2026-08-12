#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_script() {
  local script_name="$1"
  local script_path="$SCRIPT_DIR/$script_name"

  if [ ! -f "$script_path" ]; then
    echo "Erro: script não encontrado:"
    echo "  $script_path"
    exit 1
  fi

  if [ ! -x "$script_path" ]; then
    echo "Erro: script sem permissão de execução:"
    echo "  $script_path"
    echo "Execute: chmod +x \"$script_path\""
    exit 1
  fi

  echo
  echo "Executando: $script_name"
  echo "=============================================="
  "$script_path"
}

install_all() {
  run_script "lpkinstall-builtin.sh"
  run_script "lpkinstall-curadoria.sh"
  run_script "lpkinstall-zeos.sh"
  run_script "lpkinstall-frce.sh"
  run_script "lpkinstall-stax.sh"
  run_script "lpkinstall-powerpdf.sh"
  run_script "lpkinstall-acbr.sh"
}

while true; do
  echo
  echo "=============================================="
  echo "Menu de instalação de pacotes do Lazarus"
  echo "=============================================="
  echo "1. Instalar os pacotes basicos"
  echo "2. Instalar Docking"
  echo "3. Instalar o Zeos(banco de dados)"
  echo "4. Instalar o Fortes Community Edition(relatórios)"
  echo "5. Instalar o Stax"
  echo "6. Instalar o PowerPDF"
  echo "7. Instalar o ACBr(inclui Synapse embutido; depende das demais opcoes acima)"
  echo "8. Instalar curadoria do editor"
  echo "9. Instalar tudo"
  echo "X. Sair"
  echo "=============================================="
  echo -n "Escolha uma opção: "
  read -r opcao

  case "$opcao" in
    1) run_script "lpkinstall-builtin.sh" ;;
    2) run_script "lpkinstall-docking.sh" ;;
    3) run_script "lpkinstall-zeos.sh" ;;
    4) run_script "lpkinstall-frce.sh" ;;
    5) run_script "lpkinstall-stax.sh" ;;
    6) run_script "lpkinstall-powerpdf.sh" ;;
    7) run_script "lpkinstall-acbr.sh" ;;
    8) run_script "lpkinstall-curadoria.sh" ;;
    9) install_all ;;
    [Xx])
      echo "Saindo."
      exit 0
      ;;
    *)
      echo "Opção inválida."
      ;;
  esac
done
