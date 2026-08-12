#!/bin/bash
# Autor: Gladiston Santana <gladiston.santana[at]gmail[dot]com>
# Criação: 03 de outubro de 2024
# Atualizado em: 22 de Maio de 2025
# Modificado em: 09 de Fevereiro de 2026 (Autodetecção de pastas)
# Licença: MIT
#
# Instruções de execução:
# Este script realiza a instalação de pacotes ACBr no Lazarus e recompila o IDE.
#
# O script tentará detectar automaticamente o Lazarus.
# O ACBr será mantido em: <pasta_lazarus>/components/acbr
# Caso queira forçar o Lazarus:
# ./acbr_install.sh [pasta_lazarus]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lpkinstall-common.sh
source "$SCRIPT_DIR/lpkinstall-common.sh"

#
# Funcoes
#

log() {
  echo "$*" | tee -a "$vlog"
}

check_lazarus_closed() {
  local running

  if ! command -v pgrep >/dev/null 2>&1; then
    return 0
  fi

  running="$(pgrep -u "$(id -u)" -af '(^|/)(lazarus|startlazarus)([[:space:]]|$)' || true)"
  if [ -n "$running" ]; then
    log "Erro: a IDE Lazarus parece estar aberta."
    log "Feche o Lazarus antes de instalar pacotes ou recompilar a IDE e execute este script novamente."
    log ""
    log "$running"
    exit 1
  fi
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
  "trunk2/Pacotes/Lazarus/synapse/laz_synapse.lpk"
  "trunk2/Pacotes/Lazarus/ACBrComum/ACBrComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrLibXML2/ACBrLibXML2.lpk"
  "trunk2/Pacotes/Lazarus/ACBrOpenSSL/ACBrOpenSSL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDiversos/ACBrDiversos.lpk"
  "trunk2/Pacotes/Lazarus/PCNComum/PCNComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrTXTComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTCP/ACBrTCP.lpk"
  "trunk2/Pacotes/Lazarus/ACBrIntegrador/ACBr_Integrador.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrDFeComum.lpk"
)

# Lista de pacotes extraída por meio de:
# find trunk2/Pacotes/Lazarus -name "*.lpk" | sort
LPK_FILES=(
  # Essenciais
  "trunk2/Pacotes/Lazarus/synapse/laz_synapse.lpk"
  "trunk2/Pacotes/Lazarus/ACBrComum/ACBrComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrLibXML2/ACBrLibXML2.lpk"
  "trunk2/Pacotes/Lazarus/ACBrOpenSSL/ACBrOpenSSL.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDiversos/ACBrDiversos.lpk"
  "trunk2/Pacotes/Lazarus/PCNComum/PCNComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSerial/ACBrSerial.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrTXTComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTCP/ACBrTCP.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTCP/ACBr_MTER.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTEFD/ACBr_TEFD.lpk"
  "trunk2/Pacotes/Lazarus/ACBrIntegrador/ACBr_Integrador.lpk"
  "trunk2/Pacotes/Lazarus/ACBrPIXCD/ACBr_PIXCD.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrDFeComum.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrDFeReportRL.lpk"
)
LPK_COMERCIO=(
  # Comercio
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrADRCST/ACBr_ADRCST.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrConvenio115/ACBr_Convenio115.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrDeSTDA/ACBR_DeSTDA.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrEDI/acbr_edi.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrLCDPR/ACBr_LCDPR.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrLFD/ACBr_LFD.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrOFX/acbr_ofx.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrPonto/ACBr_Ponto.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSEF2/ACBr_SEF2.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSintegra/ACBr_Sintegra.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrSPED/ACBr_SPED.lpk"
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrPAF/ACBr_PAF.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrSATWS/ACBr_SATWS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/ACBr_SAT.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/ACBrECFVirtualSAT/acbr_sat_ecfvirtual.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/Extrato/EscPos/ACBr_SAT_Extrato_ESCPOS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/Extrato/FPDF/ACBr_SAT_Extrato_FPDF.lpk"
  "trunk2/Pacotes/Lazarus/ACBrSAT/Extrato/Fortes/ACBr_SAT_Extrato_Fortes.lpk"
  "trunk2/Pacotes/Lazarus/ACBrOpenDelivery/ACBr_OpenDelivery.lpk"
)

LPK_FINANCEIRO=(
  # Financeiro
  "trunk2/Pacotes/Lazarus/ACBrTXT/ACBrOFX/acbr_ofx.lpk"
  "trunk2/Pacotes/Lazarus/ACBrBoleto/ACBr_Boleto.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDebitoAutomatico/ACBr_DebitoAutomatico.lpk"
  "trunk2/Pacotes/Lazarus/ACBrBoleto/FC/FPDF/ACBr_BoletoFC_FPDF.lpk"
  "trunk2/Pacotes/Lazarus/ACBrBoleto/FC/Fortes/ACBr_BoletoFC_Fortes.lpk"
  "trunk2/Pacotes/Lazarus/ACBrBoleto/FC/Laz/ACBr_BoletoFC_LazReport.lpk"
  "trunk2/Pacotes/Lazarus/ACBrPagFor/ACBr_PagFor.lpk"
)

LPK_FISCAL=(
  # Fiscais
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrBPe/ACBr_BPe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrCTe/ACBr_CTe.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrDFeComum.lpk"
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
  "trunk2/Pacotes/Lazarus/ACBrBaaS/ACBrBaaS.lpk"
  "trunk2/Pacotes/Lazarus/ACBrDFe/ACBrNFe/ACBrECFVirtualNFCe/acbr_nfce_ecfvirtual.lpk"
)


# Pacotes que devem ficar por ultimos, geralmente relatorios
# A lista por enquanto começa vazia, e durante a varredura
# incluirá os relatorios, deixando-os por ultimo, acredite
# ou nao, os relatorios do ACBr tem dependencia com as classes
# que precisam ser instaladas primeiro e depois vem os relatorios.
# Mas aquilo que nao é relatorio, mas deve ser jogado por ultimo,
# deve ser incluido na lista abaixo.
LPK_ULTIMOS=(

)

log "──────────────────────────────────────────────"
log " Instalador do ACBr para Linux"
log " Homologado para sistemas Debian-like (Ubuntu, Mint, etc.)"
log " Desenvolvido para facilitar a instalação e integração"
log "──────────────────────────────────────────────"


# Impede que o script seja executado como root ou com sudo
if [ "$EUID" -eq 0 ]; then
  log " Este script não deve ser executado como root ou com sudo."
  log ".  Por favor, execute como usuário normal."
  exit 1
fi

# Verifica se o comando svn ou git está disponível
if ! command -v svn >/dev/null 2>&1 && ! command -v git >/dev/null 2>&1; then
  echo "  Nem 'svn' nem 'git' foram encontrados."
  echo -n "Deseja instalar o Subversion agora? (S/n): "
  read resposta
  resposta="${resposta:-S}"
  if [[ "$resposta" =~ ^[Ss]$ ]]; then
    log " Instalando subversion..."
    sudo apt update && sudo apt install -y subversion
    if [ $? -ne 0 ]; then
      log " Falha ao instalar o Subversion. Verifique sua conexão ou permissões."
      exit 1
    fi
  else
    log " Sem SVN/Git. Encerrando o script."
    exit 1
  fi
fi

# ==============================================================================
# INÍCIO DA LÓGICA DE DETECÇÃO (LAZARUS E ACBR)
# ==============================================================================

# --- 1) Detecção da Pasta do Lazarus (vlaz_dir) ---

vlaz_dir="$1"
# Remove barra final, se houver
vlaz_dir="${vlaz_dir%/}"

# Se o parâmetro 1 está vazio OU o que foi passado não tem lazbuild, tenta detectar
if [ -z "$vlaz_dir" ] || [ ! -x "${vlaz_dir}/lazbuild" ]; then
  if [ -x "$HOME/fpcupdeluxe/lazarus/lazbuild" ]; then
    vlaz_dir="$HOME/fpcupdeluxe/lazarus"
  elif [ -x "$HOME/lazarus/lazbuild" ]; then
    vlaz_dir="$HOME/lazarus"
  fi
fi

# Loop de confirmação caso ainda não tenha encontrado
while [ ! -x "${vlaz_dir}/lazbuild" ]; do
  echo "  A pasta do Lazarus não foi detectada automaticamente ou é inválida."
  echo -n "Por favor, informe onde o Lazarus está instalado (pasta que contém o 'lazbuild'): "
  read vlaz_dir
  vlaz_dir="${vlaz_dir%/}"
done

log " Lazarus detectado em: $vlaz_dir"
LAZARUS_DIR="$vlaz_dir"
LAZARUS_COMPONENTS="$LAZARUS_DIR/components"

if [ ! -d "$LAZARUS_COMPONENTS" ]; then
  log "Erro: diretório de componentes do Lazarus não encontrado:"
  log "  $LAZARUS_COMPONENTS"
  exit 1
fi
log " Componentes do Lazarus em: $LAZARUS_COMPONENTS"

vlaz_build="${vlaz_dir}/lazbuild"
check_lazarus_closed

# --- 2) Detecção/Atualização da Pasta do ACBr (vacbr_path) ---

# Função auxiliar para validar estrutura do ACBr
# Critério: deve ter o conteúdo do trunk2 diretamente na pasta raiz do ACBr.
check_acbr_structure() {
  local path="$1"
  if [ -f "$path/Pacotes/Lazarus/ACBrComum/ACBrComum.lpk" ]; then
    return 0
  fi
  return 1
}

ACBR_SVN_URL="https://svn.code.sf.net/p/acbr/code/trunk2"
ACBR_SVN_URL_ALT="svn://svn.code.sf.net/p/acbr/code/trunk2"
ACBR_GIT_URL="https://github.com/MirrorProjetoACBr/ACBr.git"
vacbr_path="$LAZARUS_COMPONENTS/acbr"
ACBR_UPDATE_WANTED=0

migrate_old_acbr_layout() {
  local old_trunk_path="$vacbr_path/trunk2"
  local temp_path
  local backup_path

  if [ ! -d "$old_trunk_path/.svn" ] || [ -d "$vacbr_path/.svn" ]; then
    return 0
  fi

  temp_path="${vacbr_path}.tmp-trunk2-$$"
  backup_path="${vacbr_path}.layout-antigo-$(date +%Y%m%d%H%M%S)"

  log " Detectei a estrutura antiga do ACBr em: $old_trunk_path"
  log " Movendo o conteúdo de trunk2 para ficar diretamente em: $vacbr_path"

  mv "$old_trunk_path" "$temp_path"
  if rmdir "$vacbr_path" 2>/dev/null; then
    mv "$temp_path" "$vacbr_path"
  else
    mv "$vacbr_path" "$backup_path"
    mv "$temp_path" "$vacbr_path"
    log " Conteúdo anterior preservado em: $backup_path"
  fi
}

detect_acbr_repo_kind() {
  if [ ! -e "$vacbr_path" ]; then
    echo ""
    return 0
  fi
  if [ -d "$vacbr_path/.svn" ]; then
    echo "svn"
    return 0
  fi
  if command -v svn >/dev/null 2>&1 && svn info "$vacbr_path" >/dev/null 2>&1; then
    echo "svn"
    return 0
  fi
  if [ -d "$vacbr_path/.git" ]; then
    echo "git"
    return 0
  fi
  echo ""
}

ensure_acbr_repo() {
  local tentativa
  local max_tentativas
  local ok_svn=0
  local ok_git=0

  migrate_old_acbr_layout

  if [ -e "$vacbr_path" ]; then
    if [ -d "$vacbr_path/.svn" ] || { command -v svn >/dev/null 2>&1 && svn info "$vacbr_path" >/dev/null 2>&1; }; then
      ok_svn=1
    fi
    if [ -d "$vacbr_path/.git" ]; then
      ok_git=1
    fi

    if check_acbr_structure "$vacbr_path" && { [ "$ok_svn" -eq 1 ] || [ "$ok_git" -eq 1 ]; }; then
      log " ACBr já encontrado em: $vacbr_path"
      if [ "${ACBR_UPDATE_WANTED:-0}" -eq 1 ]; then
        if [ "$ok_svn" -eq 1 ]; then
          log " Atualizando ACBr via SVN em: $vacbr_path"
          svn cleanup "$vacbr_path" || true
          svn update --accept theirs-full "$vacbr_path" || true
        else
          log " Atualizando ACBr via Git em: $vacbr_path"
          git -C "$vacbr_path" pull --ff-only || true
        fi
      else
        log " Mantendo ACBr local sem atualizar."
      fi
      if check_acbr_structure "$vacbr_path"; then
        return 0
      fi
    fi

    if [ "$ok_svn" -eq 0 ] && [ "$ok_git" -eq 0 ] && ! check_acbr_structure "$vacbr_path"; then
      log "Erro: já existe pasta ACBr, mas não é SVN/Git válido:"
      log "  $vacbr_path"
      exit 1
    fi

    if check_acbr_structure "$vacbr_path"; then
      log " ACBr local válido em: $vacbr_path (sem metadados SVN/Git para atualizar)"
      return 0
    fi
  fi

  max_tentativas=2
  tentativa=1
  while [ "$tentativa" -le "$max_tentativas" ]; do
    if [ ! -d "$vacbr_path/.svn" ] && [ ! -d "$vacbr_path/.git" ]; then
      log " ACBr não encontrado. Checkout SVN ($tentativa/$max_tentativas)..."
      rm -rf "$vacbr_path"
      if ! svn checkout "$ACBR_SVN_URL" "$vacbr_path"; then
        log " Checkout HTTPS falhou; tentando svn://"
        svn checkout "$ACBR_SVN_URL_ALT" "$vacbr_path" || true
      fi
      if check_acbr_structure "$vacbr_path"; then
        log " ACBr obtido via SVN: $ACBR_SVN_URL"
        return 0
      fi

      log " SVN incompleto/falhou. Tentando mirror Git MirrorProjetoACBr..."
      rm -rf "$vacbr_path"
      if ! command -v git >/dev/null 2>&1; then
        log "Erro: git não encontrado para o fallback do mirror."
        exit 1
      fi
      git clone --depth 1 --single-branch "$ACBR_GIT_URL" "$vacbr_path" || true
      if [ -d "$vacbr_path/.git" ]; then
        git -C "$vacbr_path" config core.longpaths true || true
      fi
      if check_acbr_structure "$vacbr_path"; then
        log " ACBr obtido via Git: $ACBR_GIT_URL"
        return 0
      fi
    elif [ -d "$vacbr_path/.svn" ]; then
      log " ACBr incompleto com .svn; atualizando via SVN..."
      svn cleanup "$vacbr_path" || true
      svn update --accept theirs-full "$vacbr_path" || true
    else
      log " ACBr incompleto com .git; atualizando via Git..."
      git -C "$vacbr_path" pull --ff-only || true
    fi

    if check_acbr_structure "$vacbr_path"; then
      return 0
    fi
    log " Estrutura do ACBr incompleta após tentativa $tentativa/$max_tentativas."
    tentativa=$((tentativa + 1))
  done

  if ! check_acbr_structure "$vacbr_path"; then
    log "Erro: estrutura do ACBr inválida após checkout/update."
    log "Esperado: $vacbr_path/Pacotes/Lazarus/ACBrComum/ACBrComum.lpk"
    exit 1
  fi
}

acbr_package_path() {
  local package="${1#trunk2/}"
  printf '%s/%s\n' "$vacbr_path" "$package"
}

get_lazarus_pcp_dir() {
  if [ -n "$vlaz_build_pcp" ]; then
    echo "$vlaz_build_pcp" | sed -E 's/.*--pcp="([^"]+)".*/\1/'
  else
    echo "$HOME/.lazarus"
  fi
}

detect_lazarus_widgetset() {
  local idemake
  local detected
  local ws="gtk2"

  idemake="$(get_lazarus_pcp_dir)/idemake.cfg"
  if [ -f "$idemake" ]; then
    detected="$(grep -oE '\-dLCL(qt6|qt5|gtk3|gtk2|nogui|win32|custom)' "$idemake" | head -1 | sed 's/-dLCL//')"
    if [ -n "$detected" ]; then
      ws="$detected"
    fi
  fi

  echo "$ws"
}

run_lazbuild() {
  if [ -n "$vlaz_build_pcp" ]; then
    eval "\"$vlaz_build\"$vlaz_build_pcp $(printf '"%s" ' "$@")"
  else
    "$vlaz_build" "$@"
  fi
}

setup_lazarus_pcp() {
  local default_pcp="N"
  local suggested_pcp="$HOME/.lazarus"
  local parent_cfg

  echo "───────  DIRETORIO DE CONFIGURAÇÃO  ──────"

  # Se o Lazarus está dentro do fpcupdeluxe, o padrão de --pcp é Sim.
  case "$vlaz_dir" in
    *fpcupdeluxe*)
      default_pcp="S"
      parent_cfg="$(dirname "$vlaz_dir")/config_lazarus"
      if [ -d "$parent_cfg" ]; then
        suggested_pcp="$parent_cfg"
      elif [ -d "$HOME/fpcupdeluxe/config_lazarus" ]; then
        suggested_pcp="$HOME/fpcupdeluxe/config_lazarus"
      fi
      ;;
  esac

  if [ "$default_pcp" = "S" ]; then
    echo "Você usa --pcp para carregar o Lazarus? (S/n)"
  else
    echo "Você usa --pcp para carregar o Lazarus? (s/N)"
  fi
  echo "Sugestão de PCP: $suggested_pcp"
  echo -n " "
  read resposta
  resposta="${resposta:-$default_pcp}"
  if [[ "$resposta" =~ ^[Ss]$ ]]; then
    echo "Informe o caminho do PCP (ENTER = sugestão):"
    echo -n " "
    read resposta
    if [[ "$resposta" =~ ^[SsNn]$ ]]; then
      echo " Resposta ignorada"
      resposta=""
    fi
    resposta="$(echo "$resposta" | xargs)"
    if [ -z "$resposta" ]; then
      resposta="$suggested_pcp"
    fi
    vlaz_build_pcp=" --pcp=\"$resposta\""
    log " Usando --pcp=$resposta"
  else
    vlaz_build_pcp=""
    log " Usando PCP padrão do Lazarus (~/.lazarus), sem --pcp"
  fi
}

configure_lazarus_package_files() {
  pcp_dir="$(get_lazarus_pcp_dir)"

  arquivo_staticpackages="$pcp_dir/staticpackages.inc"
  arquivo_packagefiles="$pcp_dir/packagefiles.xml"

  if [ ! -f "$arquivo_staticpackages" ]; then
    log " Arquivo $arquivo_staticpackages não encontrado."
    log ".   O Lazarus parece não ter sido iniciado ou configurado ainda."
    return 1
  fi

  return 0
}

precheck_acbr_dependencies() {
  local pacote
  local missing_count=0
  local resposta

  log " Verificando dependências antes de baixar/atualizar o ACBr..."
  if ! configure_lazarus_package_files; then
    echo -n "Deseja continuar mesmo assim e baixar/atualizar o ACBr (S/N)? "
    read resposta
    if [[ ! "$resposta" =~ ^[Ss]$ ]]; then
      log " Instalação cancelada antes do download/update do ACBr."
      exit 1
    fi
    return 0
  fi

  for pacote in "${PACKAGES_DEPS[@]}"; do
    CheckInstalled "$pacote"
    if [ $? -ne 0 ]; then
      missing_count=$((missing_count + 1))
      log " Aviso: pacote não encontrado previamente no Lazarus: $pacote"
    fi
  done

  if [ "$missing_count" -gt 0 ]; then
    log ".   Esta conferência olha estes arquivos:"
    log ".   $arquivo_staticpackages"
    log ".   $arquivo_packagefiles"
    echo -n "Deseja continuar mesmo assim e baixar/atualizar o ACBr (S/N)? "
    read resposta
    if [[ ! "$resposta" =~ ^[Ss]$ ]]; then
      log " Instalação cancelada antes do download/update do ACBr."
      exit 1
    fi
  else
    log " Dependências base encontradas antes do download/update do ACBr."
  fi
}

vlaz_build_pcp=""
vlaz_build_widgetset=""
setup_lazarus_pcp

# Perguntas primeiro; depois confirmação; então download/instalação sem novas perguntas.
want_comercio=0
want_financeiro=0
want_fiscal=0
ACBR_UPDATE_WANTED=0
windres_sn="N"
repo_kind=""

echo ""
echo "=============================================="
echo "Perguntas iniciais (depois disso não haverá novas perguntas)"
echo "=============================================="

echo "───────────────  COMERCIO  ───────────────"
echo "Você deseja incluir os componentes categorizados como comercio?"
echo "(digite 'n' para não ou ENTER para sim)"
echo -n " "
read resposta
resposta="${resposta:-S}"
[[ "$resposta" =~ ^[Ss]$ ]] && want_comercio=1

echo "──────────────  FINANCEIRO  ──────────────"
echo "Você deseja incluir os componentes categorizados como financeiro?"
echo "(digite 'n' para não ou ENTER para sim)"
echo -n " "
read resposta
resposta="${resposta:-S}"
[[ "$resposta" =~ ^[Ss]$ ]] && want_financeiro=1

echo "────────────────  FISCAL  ────────────────"
echo "Você deseja incluir os componentes categorizados como fiscal?"
echo "(digite 'n' para não ou ENTER para sim)"
echo -n " "
read resposta
resposta="${resposta:-S}"
[[ "$resposta" =~ ^[Ss]$ ]] && want_fiscal=1

echo "────────────  FORTES REPORT  ─────────────"
echo "Você deseja incluir os formularios/impressos que usam o 'FortesReport Comunity Edition?'"
echo "(digite 'n' para não ou ENTER para sim)"
echo -n " "
read frce_sn
frce_sn="${frce_sn:-S}"

echo "───────────────  LAZREPORT  ──────────────"
echo "Você deseja incluir os formularios/impressos que usam o 'LazReport'?"
echo "(digite 'n' para não ou ENTER para sim)"
echo -n " "
read lazreport_sn
lazreport_sn="${lazreport_sn:-S}"

echo "─────────────────  FPDF  ─────────────────"
echo "Você deseja incluir os formularios/impressos que usam 'FPDF'?"
echo "(digite 'n' para não ou ENTER para sim)"
echo -n " "
read fpdf_sn
fpdf_sn="${fpdf_sn:-S}"

echo "───────────  MATRICIAL ESC-POS  ──────────"
echo "Você deseja incluir suporte EscPos (matricial)?"
echo "(digite 's' para sim ou ENTER para não)"
echo -n " "
read escpos_sn
escpos_sn="${escpos_sn:-N}"

echo "──────────  COMPONENTES VISUAIS  ─────────"
detected_widget="$(detect_lazarus_widgetset)"
echo "Qual widgetset usar na recompilação da IDE do Lazarus?"
echo "(ENTER para usar o detectado: $detected_widget, ou digite gtk2, qt5 ou qt6)"
echo -n " "
read resp_widget
if [[ "$resp_widget" =~ ^[Ss]$ ]]; then
  echo " Resposta ignorada"
  resp_widget=""
fi
if [ -z "$resp_widget" ]; then
  resp_widget="$detected_widget"
fi
if [ "$resp_widget" = "gtk" ]; then
  resp_widget="gtk2"
fi
if [ -n "$resp_widget" ]; then
  log " Widgetset da IDE: $resp_widget"
  vlaz_build_widgetset="--widgetset=$resp_widget "
fi

if [ ! -f /usr/bin/windres ]; then
  echo " Você deseja incluir suporte a componentes ligados ao windres(S/n)?"
  echo " Requer mingw-w64. Sem ele, alguns componentes do ACBr não compilam."
  echo "(digite 'n' para não ou ENTER para sim)"
  read windres_sn
  windres_sn="${windres_sn:-S}"
fi

if [ -e "$vacbr_path" ] && check_acbr_structure "$vacbr_path"; then
  repo_kind="$(detect_acbr_repo_kind)"
  echo "────────────  ACBR LOCAL  ────────────"
  log " ACBr já encontrado em: $vacbr_path"
  if [ "$repo_kind" = "svn" ]; then
    echo "Repositório: SVN"
    echo -n "Deseja atualizar o ACBr via SVN antes de instalar (S/n)? "
    read resposta
    resposta="${resposta:-S}"
    [[ "$resposta" =~ ^[Ss]$ ]] && ACBR_UPDATE_WANTED=1
  elif [ "$repo_kind" = "git" ]; then
    echo "Repositório: Git"
    echo -n "Deseja atualizar o ACBr via Git antes de instalar (S/n)? "
    read resposta
    resposta="${resposta:-S}"
    [[ "$resposta" =~ ^[Ss]$ ]] && ACBR_UPDATE_WANTED=1
  else
    echo "Pasta local sem .svn/.git; não haverá atualização remota."
    ACBR_UPDATE_WANTED=0
  fi
else
  echo "────────────  ACBR  ────────────"
  echo "ACBr ainda não está em: $vacbr_path"
  echo "Após confirmar, será feito checkout (SVN; fallback Git)."
  ACBR_UPDATE_WANTED=1
fi

precheck_acbr_dependencies

echo ""
echo "=============================================="
echo "Resumo das opções"
echo "=============================================="
echo "Comercio     : $want_comercio"
echo "Financeiro   : $want_financeiro"
echo "Fiscal       : $want_fiscal"
echo "Fortes CE    : $frce_sn"
echo "LazReport    : $lazreport_sn"
echo "FPDF         : $fpdf_sn"
echo "EscPos       : $escpos_sn"
echo "Widgetset    : $resp_widget"
echo "windres      : $windres_sn"
if [ -e "$vacbr_path" ] && check_acbr_structure "$vacbr_path"; then
  if [ "$ACBR_UPDATE_WANTED" -eq 1 ]; then
    echo "ACBr local   : atualizar (${repo_kind:-?})"
  else
    echo "ACBr local   : manter sem atualizar"
  fi
else
  echo "ACBr local   : baixar (SVN/Git)"
fi
echo "=============================================="
echo -n "Confirmar e iniciar download/instalação (sem mais perguntas) (S/n)? "
read resposta
resposta="${resposta:-S}"
if [[ ! "$resposta" =~ ^[Ss]$ ]]; then
  log " Instalação cancelada pelo usuário."
  exit 1
fi

# Aplica escolhas
if [ "$want_comercio" -eq 1 ]; then
  log "Foi adicionado o pacote de componentes para: Comercio"
  LPK_FILES+=("${LPK_COMERCIO[@]}")
fi
if [ "$want_financeiro" -eq 1 ]; then
  log "Foi adicionado o pacote de componentes para: Financeiro"
  LPK_FILES+=("${LPK_FINANCEIRO[@]}")
fi
if [ "$want_fiscal" -eq 1 ]; then
  log "Foi adicionado o pacote de componentes para: Fiscal"
  LPK_FILES+=("${LPK_FISCAL[@]}")
fi
if [[ "$frce_sn" =~ ^[Ss]$ ]]; then
  log "Foi requerido o suporte a relatorios/impressos do fortes-ce"
  PACKAGES_DEPS+=("frce")
fi
if [[ "$lazreport_sn" =~ ^[Ss]$ ]]; then
  log "Foi requerido o suporte a relatorios/impressos do lazreport"
  PACKAGES_DEPS+=("lazfpreportdesign")
fi
if [[ "$fpdf_sn" =~ ^[Ss]$ ]]; then
  log "Foi requerido o suporte a relatorios/impressos do fpdf"
fi
if [[ "$escpos_sn" =~ ^[Ss]$ ]]; then
  log "Foi requerido o suporte a relatorios/impressos que usam escpos"
fi

install_windres
if [ ! -f /usr/bin/windres ] && [[ "$windres_sn" =~ ^[Ss]$ ]]; then
  echo " Instalando mingw-w64..."
  sudo apt update && sudo apt install -y mingw-w64
  if [ $? -ne 0 ]; then
    log " Falha ao instalar o pacote mingw-w64. Verifique sua conexão ou permissões."
    exit 1
  fi
  install_windres || {
    log " Falha ao criar link simbolico para /usr/bin/windres. Verifique permissões."
    exit 2
  }
fi

log " Iniciando download/atualização e instalação..."
ensure_acbr_repo
clean_component_build_artifacts "ACBr" "$LAZARUS_COMPONENTS" "$vacbr_path" "Lib"
log " ACBr detectado em: $vacbr_path"

# ==============================================================================
# FIM DA LÓGICA DE DETECÇÃO
# ==============================================================================

# Armazena a data/hora do arquivo "lazarus" no início
if [ -f "${vlaz_dir}/lazarus" ] ; then
  lazarus_timestamp_start=$(stat -c %Y "${vlaz_dir}/lazarus")
else
  lazarus_timestamp_start=$(stat -c %Y "${vlaz_build}")
fi

# Opções para recompilar o Lazarus IDE
vlaz_build_ide="--build-ide= "
vlaz_build_mode="--build-mode='Normal IDE'"

#
# INICIO DO PROCESSAMENTO
#

log " Verificando se todos os pacotes .lpk existem..."
for LPK in "${LPK_FILES[@]}"; do
  full_path="$(acbr_package_path "$LPK")"
  if [  -f "$full_path" ]; then
    if is_report_package "$full_path"; then
      LPK_ULTIMOS+=("$full_path")
    fi
  else
    log " Pacote não encontrado: $full_path"
    log ".  Verifique se o repositório ACBr foi baixado corretamente."
    exit 1
  fi
done
log " Todos os pacotes .lpk foram encontrados com sucesso."

# Limpeza antes de recompilar o Lazarus IDE
#cd "$vlaz_dir"
#echo " Limpando Lazarus IDE..."
#make clean bigide

log " Compilando pacotes de runtime..."
vcaptura_erro=""
for runtime_pkg in "${RUNTIME_PACKAGES[@]}"; do
  full_path="$(acbr_package_path "$runtime_pkg")"
  log ".  Compilando: $full_path"
  run_lazbuild "$full_path"
  if [ $? -ne 0 ]; then
    vcaptura_erro="$full_path"
    log " Falha ao compilar o pacote de runtime: $full_path"
    if [ -n "$vlaz_build_pcp" ]; then
      log "\"$vlaz_build\"$vlaz_build_pcp \"$full_path\""
    else
      log "\"$vlaz_build\" \"$full_path\""
    fi
    exit 1
  fi
  # Synapse e demais runtime: registra via link (nao aceitam --add-package)
  run_lazbuild --add-package-link "$full_path" || log " Aviso: --add-package-link falhou para $full_path"
done
if [ -z "$vcaptura_erro" ]; then
  log " Pacotes de runtime compilados com sucesso."
fi

# Compila todos os pacotes
log " Compilando todos pacotes..."
for LPK in "${LPK_FILES[@]}"; do
  full_path="$(acbr_package_path "$LPK")"
  vpode_compilar=true
  if is_report_package "$full_path"; then
    vpode_compilar=false
  fi
  if [ "$vpode_compilar" == "true" ] ; then
    log ".  Compilando pacote: $full_path"
    run_lazbuild "$full_path"
    if [ $? -ne 0 ]; then
      vcaptura_erro="$full_path"
      log " Erro ao compilar o pacote: $full_path"
      if [ -n "$vlaz_build_pcp" ]; then
        log "\"$vlaz_build\"$vlaz_build_pcp \"$full_path\""
      else
        log "\"$vlaz_build\" \"$full_path\""
      fi
      exit 1
    fi
  fi
done
if [ -z "$vcaptura_erro" ]; then
  log " Pacotes compilados com sucesso."
else
  log " Erro ao compilar o pacote: $vcaptura_erro"
  exit 1
fi

# Instala os pacotes um por um, mas apenas os que nao forem de runtime
log " Instala os pacotes um por um, mas apenas os que nao forem de runtime..."
vcaptura_erro=""
for LPK in "${LPK_FILES[@]}"; do
  full_path="$(acbr_package_path "$LPK")"
  vpode_instalar=true
  # Verifica se o pacote é de runtime
  if is_runtime_package "$LPK"; then
    vpode_instalar=false
  fi
  if is_report_package "$full_path"; then
    vpode_instalar=false
  fi
  if [ "$vpode_instalar" == "true" ] ; then
    log ".  Instalando pacote: $full_path"
    run_lazbuild --add-package "$full_path"
    if [ $? -ne 0 ]; then
      log "Erro ao instalar o pacote: $full_path"
      if [ -n "$vlaz_build_pcp" ]; then
        log "$vlaz_build$vlaz_build_pcp --add-package \"$full_path\""
      else
        log "$vlaz_build --add-package \"$full_path\""
      fi
      exit 1
    fi
  else
    log ".  Ignorando pacote de runtime/relatorio: $full_path"
    continue
  fi
done
if [ -z "$vcaptura_erro" ]; then
  log " Pacotes instalados com sucesso."
else
  log " Alguns pacotes podem não ter sidos instalados, ex: $vcaptura_erro"
  exit 1
fi

# Instala os pacotes que foram deixados por ultimo, geralmente relatorios
log " Instalando os pacotes que precisam ser deixados por ultimo, geralmente relatorios..."
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
    echo ".  Instalando pacote: $full_path"
    run_lazbuild --add-package "$full_path"
    if [ $? -ne 0 ]; then
      log "Erro ao instalar o pacote: $full_path"
      if [ -n "$vlaz_build_pcp" ]; then
        log "$vlaz_build$vlaz_build_pcp --add-package \"$full_path\""
      else
        log "$vlaz_build --add-package \"$full_path\""
      fi
      exit 1
    fi
  else
    log ".  Ignorando pacote: $full_path"
    continue
  fi
done

# Após a limpeza, recompilar o Lazarus IDE
log " Recompilando o Lazarus IDE..."

# Executa o comando de compilação com o uso de eval para garantir que as aspas sejam tratadas corretamente
cmd_exec="$vlaz_build"
if [ -n "$vlaz_build_pcp" ]; then
  cmd_exec="$cmd_exec $vlaz_build_pcp"
fi
cmd_exec="$cmd_exec $vlaz_build_ide $vlaz_build_widgetset $vlaz_build_mode"
log ".  $cmd_exec"
eval "$cmd_exec"

if [ $? -ne 0 ]; then
  log "Erro na recompilação da IDE."
  exit 1
fi

# Armazena a data/hora do arquivo "lazarus" no final
if [ -f "${vlaz_dir}/lazarus" ] ; then
  lazarus_timestamp_end=$(stat -c %Y "${vlaz_dir}/lazarus")
  # Verifica se a data/hora do arquivo mudou
  if [ "$lazarus_timestamp_start" -eq "$lazarus_timestamp_end" ]; then
    log "Erro: A data/hora do arquivo 'lazarus' não foi modificada. Recompilação falhou."
    exit 1
  else
    log " Recompilação da IDE concluída com sucesso."
  fi
fi
