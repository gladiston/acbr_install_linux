#!/bin/bash
# lpkinstall-curadoria.sh - Curadoria do editor via OPM + nativos Lazarus
# Fonte OPM: https://packages.lazarus-ide.org/

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lpkinstall-common.sh
source "$SCRIPT_DIR/lpkinstall-common.sh"

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

# Nome|ZipOPM|PastaDestino|LpkMarcador[|OrdemPreferencial(;)]
CURADORIA=(
  "ATFileNotif|ATFileNotif-Lazarus.zip|ATFileNotif|src/atfilenotif_pkg.lpk"
  "CmdLine|CmdLine.zip|CmdLine|cmdbox.lpk"
  "CryptINI|cryptini.zip|CryptINI|cryptini.lpk"
  "CryptoLib|CryptoLib.zip|CryptoLib|src/Packages/FPC/CryptoLib4PascalPackage.lpk"
  "DCPcrypt|DCPcrypt.zip|DCPcrypt|dcpcrypt.lpk|dcpcrypt.lpk;dcpcrypt_laz.lpk"
  "FPSpreadsheet|FPSpreadsheet.zip|FPSpreadsheet|laz_fpspreadsheet.lpk|laz_fpspreadsheet.lpk;laz_fpspreadsheet_crypto.lpk;laz_fpspreadsheet_dataset.lpk;laz_fpspreadsheet_visual.lpk;laz_fpspreadsheetexport_visual.lpk;laz_fpspreadsheet_visual_dsgn.lpk"
  "HashLib|HashLib.zip|HashLib|src/Packages/FPC/HashLib4PascalPackage.lpk"
  "HtmlViewer|HtmlViewer.zip|HtmlViewer|package/FrameViewer09.lpk"
  "LazRichView|LazRichView.zip|LazRichView|lazrichview.lpk"
  "MultithreadProcs|MultithreadProcs.zip|MultithreadProcs|multithreadprocslaz.lpk"
  "RichMemo|RichMemo.zip|RichMemo|richmemopackage.lpk|richmemopackage.lpk;ide/richmemo_design.lpk"
  "TDINoteBook|TDINoteBook.zip|TDINoteBook|tdi.lpk"
  "UTF8Tools|UTF8Tools.zip|UTF8Tools|utf8tools.lpk"
  "XMailer|XMailer.zip|XMailer|pkg/xmailerpkg.lpk"
)

# Nome|caminho relativo a components/
NATIVOS=(
  "memdslaz|memds/memdslaz.lpk"
  "datetimectrls|datetimectrls/datetimectrls.lpk"
  "datetimectrlsdsgn|datetimectrls/design/datetimectrlsdsgn.lpk"
)

LAZARUS_DIR="${1:-}"
if [ -z "$LAZARUS_DIR" ]; then
  if [ -x "$HOME/fpcupdeluxe/lazarus/lazbuild" ]; then
    LAZARUS_DIR="$HOME/fpcupdeluxe/lazarus"
  elif [ -x "$HOME/lazarus/lazbuild" ]; then
    LAZARUS_DIR="$HOME/lazarus"
  else
    read -r -p "Onde o Lazarus está instalado? " LAZARUS_DIR
  fi
fi
LAZARUS_DIR="${LAZARUS_DIR%/}"

if [ ! -x "$LAZARUS_DIR/lazbuild" ]; then
  echo "Erro: lazbuild não encontrado em: $LAZARUS_DIR"
  exit 1
fi

LAZBUILD="$LAZARUS_DIR/lazbuild"
LAZ_BIN="$LAZARUS_DIR/lazarus"
LAZARUS_COMPONENTS="$LAZARUS_DIR/components"
check_lazarus_closed

if [ ! -d "$LAZARUS_COMPONENTS" ]; then
  echo "Erro: diretório de componentes do Lazarus não encontrado:"
  echo "  $LAZARUS_COMPONENTS"
  exit 1
fi

LAZBUILD_PCP_ARGS=()
if [ -d "$HOME/fpcupdeluxe/config_lazarus" ] && [ "$LAZARUS_DIR" = "$HOME/fpcupdeluxe/lazarus" ]; then
  LAZBUILD_PCP_ARGS=(--pcp="$HOME/fpcupdeluxe/config_lazarus")
fi

echo
echo "────────── COMPONENTES VISUAIS ─────────"
echo "Pressione ENTER para manter o padrão ou digite: gtk, qt5, qt6"
echo -n "> "
read -r resp_widget
LAZBUILD_WIDGETSET_ARGS=()
if [ -n "$resp_widget" ] && [[ ! "$resp_widget" =~ ^[Ss]$ ]]; then
  LAZBUILD_WIDGETSET_ARGS=(--widgetset="$resp_widget")
fi

echo
echo "=============================================="
echo "Curadoria do editor (OPM + nativos Lazarus)"
echo "Fonte OPM: $OPM_BASE_URL"
echo "Após extrair, todos os .lpk (runtime e design) serão instalados."
echo "=============================================="
echo "Pacotes OPM:"
for spec in "${CURADORIA[@]}"; do
  IFS='|' read -r nome zip_name _rest <<<"$spec"
  echo "  - $nome  ($zip_name)"
done
echo "Pacotes nativos do Lazarus:"
for spec in "${NATIVOS[@]}"; do
  IFS='|' read -r nome rel <<<"$spec"
  echo "  - $nome  ($rel)"
done
echo "Total OPM: ${#CURADORIA[@]} | Nativos: ${#NATIVOS[@]}"
echo
echo -n "Prosseguir com a instalação da curadoria do editor (S/n)? "
read -r resp
resp="${resp:-S}"
if [[ ! "$resp" =~ ^[Ss]$ ]]; then
  echo "Instalação da curadoria cancelada."
  exit 0
fi

ok_count=0
fail_count=0
skip_count=0
[ -f "$LAZ_BIN" ] && start_ts=$(stat -c %Y "$LAZ_BIN") || start_ts=0

for spec in "${CURADORIA[@]}"; do
  IFS='|' read -r nome zip_name dest_name marker_lpk preferred_list <<<"$spec"
  dest_dir="$LAZARUS_COMPONENTS/$dest_name"
  echo
  echo "---------- $nome ----------"
  echo "Zip: ${OPM_BASE_URL}${zip_name}"
  echo "Destino: $dest_dir"

  if ! ensure_opm_zip "$zip_name" "$dest_dir" "$marker_lpk"; then
    echo "ERRO: falha ao obter $nome via OPM."
    fail_count=$((fail_count + 1))
    continue
  fi

  mapfile -t lpks < <(resolve_lpks_to_install "$dest_dir" "${preferred_list:-}")
  if [ "${#lpks[@]}" -eq 0 ]; then
    echo "ERRO: nenhum .lpk encontrado em $dest_dir"
    fail_count=$((fail_count + 1))
    continue
  fi

  echo "LPKs a instalar (${#lpks[@]}):"
  for lpk in "${lpks[@]}"; do
    if is_design_lpk "$lpk"; then
      echo "  [design ] $lpk"
    else
      echo "  [runtime] $lpk"
    fi
  done

  for lpk in "${lpks[@]}"; do
    set +e
    install_lpk_file "$lpk"
    st=$?
    set -e
    if [ "$st" -eq 0 ]; then
      ok_count=$((ok_count + 1))
    elif [ "$st" -eq 2 ]; then
      skip_count=$((skip_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
  done
done

echo
echo "=============================================="
echo "Pacotes nativos do Lazarus"
echo "=============================================="
for spec in "${NATIVOS[@]}"; do
  IFS='|' read -r nome rel <<<"$spec"
  lpk_path="$LAZARUS_COMPONENTS/$rel"
  echo
  echo "---------- $nome (nativo) ----------"
  if [ ! -f "$lpk_path" ]; then
    echo "ERRO: pacote nativo não encontrado: $lpk_path"
    fail_count=$((fail_count + 1))
    continue
  fi
  set +e
  install_lpk_file "$lpk_path"
  st=$?
  set -e
  if [ "$st" -eq 0 ]; then
    ok_count=$((ok_count + 1))
  elif [ "$st" -eq 2 ]; then
    skip_count=$((skip_count + 1))
  else
    fail_count=$((fail_count + 1))
  fi
done

echo
echo "=============================================="
echo "Resumo curadoria: ok=$ok_count avisos=$skip_count falhas=$fail_count"
echo "=============================================="

if [ "$ok_count" -eq 0 ] && [ "$fail_count" -gt 0 ]; then
  echo "Erro: nenhum pacote da curadoria foi instalado com sucesso."
  exit 1
fi

echo "Recompilando a IDE Lazarus..."
"$LAZBUILD" "${LAZBUILD_PCP_ARGS[@]}" "${LAZBUILD_WIDGETSET_ARGS[@]}" --build-ide=

if [ -f "$LAZ_BIN" ]; then
  end_ts=$(stat -c %Y "$LAZ_BIN")
  if [ "$start_ts" -eq "$end_ts" ]; then
    echo "ERRO: a data/hora do binário 'lazarus' não mudou. A recompilação pode ter falhado."
    exit 1
  fi
fi

echo "Concluído. Abra o Lazarus e confira os pacotes da curadoria."
