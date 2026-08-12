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
  echo "2. Instalar o Zeos(banco de dados)"
  echo "3. Instalar o Fortes Community Edition(relatórios)"
  echo "4. Instalar o Stax"
  echo "5. Instalar o PowerPDF"
  echo "6. Instalar o ACBr(inclui Synapse embutido; depende das demais opcoes acima)"
  echo "7. Instalar curadoria do editor"
  echo "8. Instalar tudo"
  echo
  echo "9. Instalar Docking"
  echo "A. Reperguntar docking no próximo start do Lazarus"
  echo "B. Download do lazIdeExportSettings"
  echo "X. Sair"
  echo "=============================================="
  echo -n "Escolha uma opção: "
  read -r opcao

  case "$opcao" in
    1) run_script "lpkinstall-builtin.sh" ;;
    2) run_script "lpkinstall-zeos.sh" ;;
    3) run_script "lpkinstall-frce.sh" ;;
    4) run_script "lpkinstall-stax.sh" ;;
    5) run_script "lpkinstall-powerpdf.sh" ;;
    6) run_script "lpkinstall-acbr.sh" ;;
    7) run_script "lpkinstall-curadoria.sh" ;;
    8) install_all ;;
    9) run_script "lpkinstall-docking.sh" ;;
    [Aa]) run_script "lpkinstall-redockask.sh" ;;
    [Bb]) run_script "download-lazideexportsettings.sh" ;;
    [Xx])
      echo "Saindo."
      exit 0
      ;;
    *)
      echo "Opção inválida."
      ;;
  esac
done
