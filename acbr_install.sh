#!/bin/bash
# Autor: Gladiston Santana <gladiston.santana[at]gmail[dot]com>
# Criação: 03 de outubro de 2024
# Atualizado em: 21 de Maio de 2025
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

#
# Funcoes
#

log() {
  echo "$*" | tee -a "$vlog"
}

# Função para verificar se o pacote é de runtime
# retorna 0 se $1 é um  pacote de runtime
is_runtime_package() {
  local package=$1
  for runtime_pkg in "${RUNTIME_PACKAGES[@]}"; do
    if [[ "$package" == "$runtime_pkg" ]]; then
      return 0 
    fi
  done
  return 1
}

# Função para verificar se o pacote é um relatorio
# retorna 0 se $1 é um  pacote de relatorio
is_report_package() {
  local package=$1
  if echo "$package" | grep -iq "/EscPos/"; then    
    return 0 # EscPos
  fi
  if echo "$package" | grep -iq "/FPDF/"; then    
    return 0 # FPDF
  fi
  if echo "$package" | grep -iq "/laz/"; then    
    return 0 # LazReport
  fi
  if echo "$package" | grep -iq "/Fortes/"; then    
    return 0 # fortes
  fi
  if echo "$package" | grep -iq "/Fast/"; then    
    return 0 # Fastreport
  fi
  if echo "$package" | grep -iq "ACBrDFeReportRL"; then    
    return 0 # fortes
  fi  
  return 1
}

install_windres() {
  if [ ! -f /usr/bin/windres ]; then
    log "Arquivo /usr/bin/windres não encontrado. Criando link simbólico..."
    if [ -f /usr/bin/x86_64-w64-mingw32-windres ]; then
      sudo ln -s /usr/bin/x86_64-w64-mingw32-windres /usr/bin/windres
    else
      log "Você não possui o arquivo /usr/bin/x86_64-w64-mingw32-windres, normalmente instalado com o 'mingw-w64'."
    fi
  fi
  if [ -f /usr/bin/windres ]; then
    return 0
  else
    return 2
  fi
}

CheckInstalled() {
  local lista_csv="$1"
  local IFS=','

  # Converte string separada por vírgulas em array
  read -ra pacotes <<< "$lista_csv"

  for pacote in "${pacotes[@]}"; do
    if grep -q -i "$pacote" "$arquivo_staticpackages"; then
      return 0  # encontrado
    elif grep -q -i "$pacote" "$arquivo_packagefiles"; then
      return 0  # encontrado
    fi
  done

  return 1  # nenhum encontrado
}

#
# INICIO DO SCRIPT
#

# Lista de pacotes obrigatórios para o Lazarus
# Haverá mais de um nome para o mesmo pacote porque o 
# OPM e fpcupdeluxe divergem no nome
#   
# Stax.lpk(opm) ou Stax(staticpackages)
# laz_synapse.lpk(opm) ou ????(staticpackages)
# pack_powerpdf.lpk(opm) ou pack_powerpdf(staticpackages)
PACKAGES_DEPS=(
  "Stax,Stax.lpk"
  "laz_synapse.lpk,synapse"
  "pack_powerpdf.lpk, pack_powerpdf"
)

# Define o arquivo de log de erros
vlog="$(basename "$0").log"

# Limpa o conteúdo anterior
vinicio=$(date "+%Y-%m-%d %H:%M:%S")
echo "log criado em $vinicio" > "$vlog"

# Lista de pacotes de runtime que devem ser compilados, 
# mas nunca instalados
RUNTIME_PACKAGES=(
  #"trunk2/Pacotes/Lazarus/synapse/laz_synapse.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDiversos/ACBrDiversos.lpk"
  "trunk2/Pacotes/Lazarus/PCNComum/PCNComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrTXTComum.lpk"
)

# Lista de pacotes extraída por meio de:
# find trunk2/Pacotes/Lazarus -name "*.lpk" | sort
LPK_FILES=(
  # Outros
  "trunk2/Pacotes/Lazarus/ACBrComum/ACBrComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDiversos/ACBrDiversos.lpk"
  "trunk2/Pacotes/Lazarus/ACBrIntegrador/ACBr_Integrador.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSerial/ACBrSerial.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrADRCST/ACBr_ADRCST.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrConvenio115/ACBr_Convenio115.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrDeSTDA/ACBR_DeSTDA.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrEDI/acbr_edi.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrLCDPR/ACBr_LCDPR.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrLFD/ACBr_LFD.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrPonto/ACBr_Ponto.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSEF2/ACBr_SEF2.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSPED/ACBr_SPED.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSintegra/ACBr_Sintegra.lpk"
  "trunk2/Pacotes/Lazarus/ACBrBaaS/ACBrBaaS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrOpenDelivery/ACBr_OpenDelivery.lpk"
  "trunk2/Pacotes/Lazarus/ACBrPagFor/ACBr_PagFor.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrOFX/acbr_ofx.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrTXTComum.lpk"
  "trunk2/Pacotes/Lazarus/PCNComum/PCNComum.lpk"
    
  # Comercio
  "trunk2/Pacotes/Lazarus/ACBrTCP/ACBrTCP.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTCP/ACBr_MTER.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrPAF/ACBr_PAF.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFe/ACBrECFVirtualNFCe/acbr_nfce_ecfvirtual.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrSATWS/ACBr_SATWS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/ACBr_SAT.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/ACBrECFVirtualSAT/acbr_sat_ecfvirtual.lpk"  
  "trunk2/Pacotes/Lazarus/ACBrSAT/Extrato/EscPos/ACBr_SAT_Extrato_ESCPOS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/Extrato/FPDF/ACBr_SAT_Extrato_FPDF.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/Extrato/Fortes/ACBr_SAT_Extrato_Fortes.lpk"
  
  # Financeiro
  "trunk2/Pacotes/Lazarus/ACBrTEFD/ACBr_TEFD.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrOFX/acbr_ofx.lpk"    
  "trunk2/Pacotes/Lazarus/ACBrBoleto/ACBr_Boleto.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDebitoAutomatico/ACBr_DebitoAutomatico.lpk"    
  "trunk2/Pacotes/Lazarus/ACBrBoleto/FC/FPDF/ACBr_BoletoFC_FPDF.lpk"
  "trunk2/Pacotes/Lazarus/ACBrBoleto/FC/Fortes/ACBr_BoletoFC_Fortes.lpk"
  "trunk2/Pacotes/Lazarus/ACBrBoleto/FC/Laz/ACBr_BoletoFC_LazReport.lpk"

  # Fiscais
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrBPe/ACBr_BPe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrCTe/ACBr_CTe.lpk"
  #"trunk2/Pacotes/Lazarus/ACBrDFe/ACBrDFeComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrMDFe/ACBr_MDFe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFSe/ACBr_NFSe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFe/ACBr_NFe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrANe/ACBr_ANe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrBPe/DABPE/EscPos/ACBr_BPeDabpeESCPOS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrBlocoX/ACBr_BlocoX.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrCIOT/ACBr_CIOT.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrCTe/DACTE/Fortes/ACBr_CTe_DACTeRL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrDCe/ACBr_DCe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrDCe/DACE/Fortes/ACBr_DCe_DACERL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrDFeReportRL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrGNRE/ACBr_GNRE.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrGNRE/GNRE/Fortes/ACBr_GNREGuiaRL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrGNRE/GNRE/Laz/ACBr_GNREGuiaLazReport.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrGTIN/ACBr_GTIN.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrMDFe/DAMDFE/Fortes/ACBr_MDFe_DAMDFeRL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNF3e/ACBr_NF3e.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNF3e/DANF3e/EscPos/ACBr_NF3e_DANF3eESCPOS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNF3e/DANF3e/Fortes/ACBr_NF3e_DANF3ERL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFCom/ACBr_NFCom.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFCom/DANFCom/Fortes/ACBr_NFCom_DANFComRL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFSe/DANFSE/Fortes/ACBr_NFSe_DanfseRL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFSeX/ACBr_NFSeX.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFSeX/DANFSE/FPDF/ACBr_NFSeXDanfseFPDF.lpk"
  #"trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFSeX/DANFSE/Fast/ACBr_NFSeXDanfseFR.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFSeX/DANFSE/Fortes/ACBr_NFSeXDanfseRL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFe/DANFE/NFCe/EscPos/ACBr_NFe_DanfeESCPOS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFe/DANFE/NFe/FPDF/ACBr_NFe_DanfeFPDF.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFe/DANFE/NFe/Fortes/ACBr_NFe_DanfeRL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFe/DANFE/NFe/Laz/ACBr_NFe_Danfe_LazReport.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrONE/ACBr_ONE.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrPAFNFCe/ACBr_PAFNFCe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrReinf/ACBr_Reinf.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBreSocial/ACBre_Social.lpk"  
  # Seguranca
  "trunk2/Pacotes/Lazarus/ACBrOpenSSL/ACBrOpenSSL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrPIXCD/ACBr_PIXCD.lpk"  
)

# Pacotes que devem ficar por ultimos, geralmente relatorios
# A lista por enquanto começa vazia, e durante a varredura
# incluirá os relatorios, deixando-os por ultima, acredite 
# ou nao, os relatorios do ACBr tem dependencia com as classes
# que precisam ser instaladas primeiro.
LPK_ULTIMOS=()

log "=============================================="
log "🛠️ Instalador do ACBr para Linux"
log "📦 Homologado para sistemas Debian-like (Ubuntu, Mint, etc.)"
log "🔧 Desenvolvido para facilitar a instalação e integração"
log "=============================================="


# Impede que o script seja executado como root ou com sudo
if [ "$EUID" -eq 0 ]; then
  log "❌ Este script não deve ser executado como root ou com sudo."
  log ".  Por favor, execute como usuário normal."
  exit 1
fi

# Verifica se o comando svn está disponível
if ! command -v svn >/dev/null 2>&1; then
  echo "⚠️  O comando 'svn' não foi encontrado."
  echo -n "Deseja instalar o Subversion agora? (s/N): "
  read resposta
  if [[ "$resposta" =~ ^[Ss]$ ]]; then
    echo "🔧 Instalando subversion..."
    sudo apt update && sudo apt install -y subversion
    if [ $? -ne 0 ]; then
      log "❌ Falha ao instalar o Subversion. Verifique sua conexão ou permissões."
      exit 1
    fi
  else
    log "🚫 Instalação do Subversion cancelada. Encerrando o script."
    exit 1
  fi
fi

# Verifica se o primeiro parâmetro (vlaz_dir) foi fornecido
if [ -z "$1" ]; then
  log "Erro: O caminho para o diretório do Lazarus (vlaz_dir) deve ser fornecido como o primeiro parâmetro. Exemplo:"
  log "$0 $HOME/fpcupdeluxe/lazarus/ $HOME/pascal_lib/ACBr/"
  exit 1
fi

# Verifica se o segundo parâmetro (vacbr_path) foi fornecido
if [ -z "$2" ]; then
  log "Erro: O caminho para os pacotes ACBr (vacbr_path) deve ser fornecido como o segundo parâmetro. Exemplo:"
  log "$0 $HOME/fpcupdeluxe/lazarus/ $HOME/pascal_lib/ACBr/"
  exit 1
fi

# Define vlaz_dir e vacbr_path com base nos parâmetros
vlaz_dir="$1"
vacbr_path="$2"
# Remove barra final, se houver
vlaz_dir="${vlaz_dir%/}"
vacbr_path="${vacbr_path%/}"

# Verifica se o arquivo "lazarus" existe no diretório indicado
if [ ! -f "${vlaz_dir}/lazarus" ]; then
  log "Erro: O arquivo 'lazarus' não foi encontrado no diretório '${vlaz_dir}'."
  exit 1
fi

# Verifica se o segundo parâmetro foi fornecido e se o diretório não existe
if [ ! -d "$vacbr_path/trunk2" ]; then
  log "❌ O diretório '$vacbr_path/trunk2' não existe."
  log "💡 Para clonar o repositório ACBr, execute o seguinte comando:"
  log "."
  log ".   mkdir $vacbr_path/acbr"
  log ".   cd $vacbr_path/acbr"
  log ".   svn checkout https://svn.code.sf.net/p/acbr/code/trunk2"
  log ""
  exit 1
fi

# Armazena a data/hora do arquivo "lazarus" no início
lazarus_timestamp_start=$(stat -c %Y "${vlaz_dir}/lazarus")

# Caminho do lazbuild derivado de vlaz_dir
vlaz_build="${vlaz_dir}/lazbuild"

# Opções para recompilar o Lazarus IDE
vlaz_build_ide="--build-ide= "
vlaz_build_widgetset=""
# Descomente se quiser recompilar para usar qt5
#vlaz_build_widgetset="--widgetset=qt5 "
vlaz_build_mode="--build-mode='Normal IDE'"
vlaz_build_pcp=""

echo "Você deseja incluir suporte ao FortesReport Comunity Edition(s/n)?"
echo "Em caso positivo, poderei instalar os relatorios que utilizam ele."
read frce_sn
if [[ "$frce_sn" =~ ^[Ss]$ ]]; then
  # usuário confirmou com S ou s
  PACKAGES_DEPS+=("frce")
fi

echo "Você deseja incluir suporte ao "LazReport" (s/n)?"
echo "Em caso positivo, poderei instalar os relatorios que utilizam ele."
read lazreport_sn
if [[ "$lazreport_sn" =~ ^[Ss]$ ]]; then
  # usuário confirmou com S ou s
  PACKAGES_DEPS+=("lazfpreportdesign")
fi

echo "Você deseja incluir suporte ao "FPDF" (s/n)?"
echo "Em caso positivo, poderei instalar os relatorios que utilizam ele."
read fpdf_sn
if [[ "$fpdf_sn" =~ ^[Ss]$ ]]; then
  # usuário confirmou com S ou s
  PACKAGES_DEPS+=("fpdf")
fi

echo "Você deseja incluir suporte ao "EscPos" (s/n)?"
echo "Em caso positivo, poderei instalar os relatorios que utilizam ele."
read escpos_sn
#if [[ "$escpos_sn" =~ ^[Ss]$ ]]; then
  # usuário confirmou com S ou s
  #PACKAGES_DEPS+=("fpdf")
#fi

echo "Você faz uso do parametro --pcp para carregar o Lazarus(s/n)?"
echo "Caso esteja usando o fpcupdeluxe, a resposta deve ser "S" para sim"
read resposta
if [[ "$resposta" =~ ^[Ss]$ ]]; then
  # usuário confirmou com S ou s
  vlaz_build_pcp=" --pcp=\"$HOME/fpcupdeluxe/config_lazarus\""
  echo "Informe o caminho para --pcp, se deixar em branco, assumirá:"
  echo "$vlaz_build_pcp"
  echo -n "Caminho: "
  read resposta

  # Remove espaços à esquerda e à direita
  resposta="$(echo "$resposta" | xargs)"  

  if [ -n "$resposta" ]; then
    vlaz_build_pcp=" --pcp=\"$resposta\""
  fi
fi

# Verificar se o arquivo /usr/bin/windres existe
# Aqui tá uma coisa que eu não gosto, instalar suporte
# a 32bits por causa de apenas um componente.
# Ignore a instalação deste tipo de suporte e alguns 
# componentes não serão instalados.
install_windres

if [ ! -f /usr/bin/windres ]; then
  echo "Você deseja incluir suporte a componentes ligados ao windres(s/n)?"
  echo "windres é um utilitario que ajuda converter os arquivos de recursos(geralmente .rc) tipico de Windows/Delphi para Lazarus"
  echo "Acho sua instalação detestável porque ele requeirerá o pacote 'mingw-w64' que permite ao Linux 64bits executar programas de 32bits e isso vai poluir seu sistema, porém sem ele, alguns componentes do ACBr não compilam."
  read windres_sn
  if [[ "$windres_sn" =~ ^[Ss]$ ]]; then
    echo "🔧 Instalando mingw-w64..."
    sudo apt update && sudo apt install -y mingw-w64
    if [ $? -ne 0 ]; then
      log "❌ Falha ao instalar o pacote mingw-w64. Verifique sua conexão ou permissões."
      exit 1
    else
      install_windres
      if [ $? -ne 0 ]; then
        log "❌ Falha ao criar link simbolico para /usr/bin/windres. Verifique permissões."
        exit 2
      fi  
    fi
  fi
fi

#
# INICIO DO PROCESSAMENTO
#

# Extrai o caminho do --pcp de vlaz_build_pcp
pcp_dir=$(echo "$vlaz_build_pcp" | sed -E 's/.*--pcp="([^"]+)".*/\1/')
arquivo_staticpackages="$pcp_dir/staticpackages.inc"
arquivo_packagefiles="$pcp_dir/packagefiles.xml"
# Confere se o arquivo staticpackages.inc existe
if [ ! -f "$arquivo_staticpackages" ]; then
  log "❌ Arquivo $arquivo_staticpackages não encontrado."
  log ".   O Lazarus parece não ter sido iniciado ou configurado ainda."
  exit 1
fi

# Verifica se os pacotes estão listados
for pacote in "${PACKAGES_DEPS[@]}"; do
  CheckInstalled "$pacote"
  if [ $? -ne 0 ]; then
    log "❌ Pacote obrigatório ausente no Lazarus: $pacote"
    log ".   Verifique se está instalado e visível no Gerenciador de Pacotes do Lazarus."
    log ".   Eu confiro se esta instalado olhando estes arquivos:"
    log ".   $arquivo_staticpackages"
    log ".   $arquivo_packagefiles"
    exit 1
  fi  
done
echo "✅ Todos os pacotes obrigatórios estão instalados."

echo "🔍 Verificando se todos os pacotes .lpk existem..."
for LPK in "${LPK_FILES[@]}"; do
  full_path="${vacbr_path}/${LPK}"
  if [  -f "$full_path" ]; then
    if is_report_package "$full_path"; then
      LPK_ULTIMOS+=($full_path)
    fi    
  else
    log "❌ Pacote não encontrado: $full_path"
    log ".  Verifique se o repositório ACBr foi baixado corretamente."
    exit 1
  fi
done
echo "✅ Todos os pacotes .lpk foram encontrados com sucesso."

# Limpeza antes de recompilar o Lazarus IDE
#cd "$vlaz_dir"
#echo "🗑️ Limpando Lazarus IDE..."
#make clean bigide

log "🗂️ Compilando pacotes de runtime..."
vcaptura_erro=""
for runtime_pkg in "${RUNTIME_PACKAGES[@]}"; do
  full_path="${vacbr_path}/${runtime_pkg}"
  echo "🛠️  Compilando: $full_path"
  "$vlaz_build" "$full_path"
  if [ $? -ne 0 ]; then
    vcaptura_erro="$full_path"
    log "❌ Falha ao compilar o pacote de runtime: $full_path"
    log "\"$vlaz_build\" \"$full_path\""
  fi
done
if [ -z "$vcaptura_erro" ]; then
  echo "✅ Pacotes de runtime compilados com sucesso."
fi

# Compila todos os pacotes
log "⚙️ Compilando todos pacotes..."
for LPK in "${LPK_FILES[@]}"; do
  full_path="${vacbr_path}/${LPK}"
  vpode_compilar=true
  if is_report_package "$full_path"; then
    vpode_compilar=false
  fi  
  if [ "$vpode_compilar" == "true" ] ; then
    echo "Compilando pacote: $full_path"  
    "$vlaz_build" "$full_path"
    if [ $? -ne 0 ]; then
      vcaptura_erro="$full_path"  
      log "Erro ao comilar o pacote: $full_path"
      log "\"$vlaz_build\" \"$full_path\""
    fi
  fi  
done
if [ -z "$vcaptura_erro" ]; then
  echo "✅ Pacotes compilados com sucesso."
else
  log "Erro ao comilar o pacote: $vcaptura_erro"
  exit 1
fi

# Instala os pacotes um por um, mas apenas os que nao forem de runtime
log "⚙️ Instala os pacotes um por um, mas apenas os que nao forem de runtime..."
vcaptura_erro=""
for LPK in "${LPK_FILES[@]}"; do
  full_path="${vacbr_path}/${LPK}"
  vpode_instalar=true
  # Verifica se o pacote é de runtime
  if is_runtime_package "$LPK"; then
    vpode_instalar=false
  fi
  if is_report_package "$full_path"; then
    pode_instalar=false
  fi
  if [ "$vpode_instalar" == "true" ] ; then
    echo "Instalando pacote: $full_path"
    "$vlaz_build" --add-package "$full_path"
    if [ $? -ne 0 ]; then
      log "Erro ao instalar o pacote: $full_path"
      log "$vlaz_build" --add-package "$full_path"
      exit 1
    fi
  else
    log "⏭️ Ignorando pacote de runtime/relatorio: $full_path"
    continue  
  fi
done
if [ -z "$vcaptura_erro" ]; then
  echo "📦 Pacotes instalados com sucesso."
else
  log "❌ Alguns pacotes podem não ter sidos instalados, ex: $vcaptura_erro"
  exit 1
fi

# Instala os pacotes que foram deixados por ultimo, geralmente relatorios
log "⚙️ Instalando os pacotes que precisam ser deixados por ultimo, geralmente relatorios..."
vcaptura_erro=""
for LPK in "${LPK_ULTIMOS[@]}"; do
  full_path="${LPK}"
  log ".  $full_path"
  vpode_instalar=true
  # Verifica se o pacote é de runtime
  if is_runtime_package "$LPK"; then
    vpode_instalar=false
  fi
  if [ "$vpode_instalar" == "true" ]; then
    # Conferindo se é relatório do Fortes
    if echo "$full_path" | grep -iq "/fortes/"; then    
      if [[ ! "$frce_sn" =~ ^[Ss]$ ]]; then
        vpode_instalar=false  
      fi
    fi
  fi
  if [ "$vpode_instalar" == "true" ]; then
    # Conferindo se é relatório do Lazreport
    if echo "$full_path" | grep -iq "/laz/"; then    
      if [[ ! "$lazreport_sn" =~ ^[Ss]$ ]]; then
        vpode_instalar=false  
      fi
    fi
  fi
  if [ "$vpode_instalar" == "true" ]; then
    # Conferindo se é relatório do FPDF
    if echo "$full_path" | grep -iq "/fpdf/"; then    
      if [[ ! "$fpdf_sn" =~ ^[Ss]$ ]]; then
        vpode_instalar=false  
      fi
    fi
  fi
  if [ "$vpode_instalar" == "true" ]; then
    # Conferindo se é relatório do FPDF
    if echo "$full_path" | grep -iq "/escpos/"; then    
      if [[ ! "$escpos_sn" =~ ^[Ss]$ ]]; then
        vpode_instalar=false  
      fi
    fi
  fi
  if [ "$vpode_instalar" == "true" ] ; then
    echo "Instalando pacote: $full_path"
    "$vlaz_build" --add-package "$full_path"
    if [ $? -ne 0 ]; then
      log "Erro ao instalar o pacote: $full_path"
      log "$vlaz_build" --add-package "$full_path"
      exit 1
    fi
  else
    log "⏭️ Ignorando pacote: $full_path"
    continue  
  fi
done

# Após a limpeza, recompilar o Lazarus IDE
log "⚙️ Recompilando o Lazarus IDE..."

# Executa o comando de compilação com o uso de eval para garantir que as aspas sejam tratadas corretamente
cmd_exec="$vlaz_build $vlaz_build_ide $vlaz_build_widgetset $vlaz_build_mode"
log "========"
log "$cmd_exec"
log "========"
eval "$cmd_exec"

if [ $? -ne 0 ]; then
  log "Erro na recompilação da IDE."
  exit 1
fi

# Armazena a data/hora do arquivo "lazarus" no final
lazarus_timestamp_end=$(stat -c %Y "${vlaz_dir}/lazarus")

# Verifica se a data/hora do arquivo mudou
if [ "$lazarus_timestamp_start" -eq "$lazarus_timestamp_end" ]; then
  log "Erro: A data/hora do arquivo 'lazarus' não foi modificada. Recompilação falhou."
  exit 1
else
  echo "Recompilação da IDE concluída com sucesso."
fi
