#!/bin/bash
# Autor: Gladiston Santana <gladiston.santana[at]gmail[dot]com>
# Data: 03 de outubro de 2024
# Licença: MIT
#
# Instruções de execução:
# Este script realiza a instalação de pacotes ACBr no Lazarus e recompila o IDE.
# Ele deve ser executado fornecendo o caminho para o diretório base do Lazarus
# (vlaz_dir) como o primeiro parâmetro e o caminho para os pacotes ACBr (vacbr_path)
# como o segundo parâmetro.
#
# Exemplo de execução:
# ./acbr_install.sh /onde/esta/o/lazarus /onde/esta/acbr/pacotes
#
# O script irá:
# 1. Verificar se o diretório fornecido contém o binário "lazarus".
# 2. Instalar os pacotes especificados, ignorando os pacotes de runtime.
# 3. Recompilar o Lazarus IDE.
# 4. Verificar se o arquivo "lazarus" foi modificado após a recompilação.
#    Se a data/hora não tiver mudado, o script reportará uma falha na recompilação.
# 5. Depois de rodar o script e ele completar com sucesso, basta ir em 
#    Packages->Install/Uninstall Packages e no painel da direita selecionar os pacotes
#    ACBr para instalação.
#
# TODO: Melhorar a função is_runtime_package para detectar se um pacote é de runtime ou não
# sem depender de uma lista pré-definida porque isso é POG.

# Verificar se o pacote mingw-w64 está instalado
if ! dpkg -l | grep -q mingw-w64; then
  echo "Pacote mingw-w64 não encontrado. Instalando..."
  sudo apt-get -y install mingw-w64
fi

# Verificar se o arquivo /usr/bin/windres existe
if [ ! -f /usr/bin/windres ]; then
  echo "Arquivo /usr/bin/windres não encontrado. Criando link simbólico..."
  sudo ln -s /usr/bin/x86_64-w64-mingw32-windres /usr/bin/windres
fi

# Função para verificar se o pacote é de runtime
is_runtime_package() {
  local package=$1
  for runtime_pkg in "${RUNTIME_PACKAGES[@]}"; do
    if [[ "$package" == "$runtime_pkg" ]]; then
      return 0  # É um pacote de runtime
    fi
  done
  return 1  # Não é um pacote de runtime
}

#
# INICIO DO SCRIPT
#

# Verifica se o primeiro parâmetro (vlaz_dir) foi fornecido
if [ -z "$1" ]; then
  echo "Erro: O caminho para o diretório do Lazarus (vlaz_dir) deve ser fornecido como o primeiro parâmetro."
  exit 1
fi

# Verifica se o segundo parâmetro (vacbr_path) foi fornecido
if [ -z "$2" ]; then
  echo "Erro: O caminho para os pacotes ACBr (vacbr_path) deve ser fornecido como o segundo parâmetro."
  exit 1
fi

# Define vlaz_dir e vacbr_path com base nos parâmetros
vlaz_dir="$1"
vacbr_path="$2"

# Verifica se o arquivo "lazarus" existe no diretório indicado
if [ ! -f "${vlaz_dir}/lazarus" ]; then
  echo "Erro: O arquivo 'lazarus' não foi encontrado no diretório '${vlaz_dir}'."
  exit 1
fi

# Armazena a data/hora do arquivo "lazarus" no início
lazarus_timestamp_start=$(stat -c %Y "${vlaz_dir}/lazarus")

# Caminho do lazbuild derivado de vlaz_dir
vlaz_build="${vlaz_dir}/lazbuild"

# Opções para recompilar o Lazarus IDE, incluindo o uso de qt5
vlaz_build_ide="--build-ide= "
vlaz_build_widgetset="--widgetset=qt5 "
vlaz_build_mode="--build-mode='Normal IDE'"

# Lista de pacotes de runtime que devem ser ignorados
RUNTIME_PACKAGES=(
  "trunk2/Pacotes/Lazarus/synapse/laz_synapse.lpk"
  "trunk2/Pacotes/Lazarus/PCNComum/PCNComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrTXTComum.lpk"
)

# Lista de pacotes extraída do arquivo de configuração
LPK_FILES=(
  "trunk2/Pacotes/Lazarus/ACBrComum/ACBrComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrOpenSSL/ACBrOpenSSL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDiversos/ACBrDiversos.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSerial/ACBrSerial.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrADRCST/ACBr_ADRCST.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrConvenio115/ACBr_Convenio115.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrDeSTDA/ACBR_DeSTDA.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrEDI/acbr_edi.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrLCDPR/ACBr_LCDPR.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrLFD/ACBr_LFD.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrOFX/acbr_ofx.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrPAF/ACBr_PAF.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrPonto/ACBr_Ponto.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSEF2/ACBr_SEF2.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSintegra/ACBr_Sintegra.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSPED/ACBr_SPED.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTCP/ACBrTCP.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTCP/ACBr_MTER.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTEFD/ACBr_TEFD.lpk"
  "trunk2/Pacotes/Lazarus/ACBrIntegrador/ACBr_Integrador.lpk"
  "trunk2/Pacotes/Lazarus/ACBrPIXCD/ACBr_PIXCD.lpk"
)

# Instala os pacotes um por um
for LPK in "${LPK_FILES[@]}"; do
  full_path="${vacbr_path}/${LPK}"

  # Verifica se o pacote é de runtime
  if is_runtime_package "$LPK"; then
    echo "Ignorando pacote de runtime: $full_path"
    continue
  fi

  echo "Instalando pacote: $full_path"
  "$vlaz_build" --add-package "$full_path"
  if [ $? -ne 0 ]; then
    echo "Erro ao instalar o pacote: $full_path"
    exit 1
  fi
done

# Limpeza antes de recompilar o Lazarus IDE
echo "Limpando Lazarus IDE..."
"$vlaz_build" --clean

# Após a limpeza, recompilar o Lazarus IDE
echo "Recompilando o Lazarus IDE..."

# Executa o comando de compilação com o uso de eval para garantir que as aspas sejam tratadas corretamente
cmd_exec="$vlaz_build $vlaz_build_ide $vlaz_build_widgetset $vlaz_build_mode"
echo "========"
echo "$cmd_exec"
echo "========"
eval "$cmd_exec"

if [ $? -ne 0 ]; then
  echo "Erro na recompilação da IDE."
  exit 1
fi

# Armazena a data/hora do arquivo "lazarus" no final
lazarus_timestamp_end=$(stat -c %Y "${vlaz_dir}/lazarus")

# Verifica se a data/hora do arquivo mudou
if [ "$lazarus_timestamp_start" -eq "$lazarus_timestamp_end" ]; then
  echo "Erro: A data/hora do arquivo 'lazarus' não foi modificada. Recompilação falhou."
  exit 1
else
  echo "Recompilação da IDE concluída com sucesso."
fi
