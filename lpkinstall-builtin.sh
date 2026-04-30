#!/bin/bash
# lpkinstall-builtin.sh - Instala pacotes nativos e recompila a IDE Lazarus
# Autor: Adaptado conforme modelos de Gladiston Santana
# Baseado em: Debian 13 / Ubuntu (Suporte a GTK2, Qt5, Qt6)
# Criado em: 2026-02-09

set -e
set -o pipefail

log() {
    echo "$*"
}

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
# 1) Detecção Automática de Diretório e PCP
# -------------------------------------------------
# Regra: Prioridade para ~/lazarus, depois ~/fpcupdeluxe/lazarus
if [ -x "$HOME/lazarus/lazbuild" ]; then
    LAZARUS_DIR="$HOME/lazarus"
    LAZBUILD_PCP_ARGS=()
    log "Lazarus detectado automaticamente em: $LAZARUS_DIR"
elif [ -x "$HOME/fpcupdeluxe/lazarus/lazbuild" ]; then
    LAZARUS_DIR="$HOME/fpcupdeluxe/lazarus"
    LAZBUILD_PCP_ARGS=(--pcp="$HOME/fpcupdeluxe/config_lazarus")
    log "Lazarus (fpcupdeluxe) detectado em: $LAZARUS_DIR"
    log "Usando PCP: $HOME/fpcupdeluxe/config_lazarus"
else
    # Só pergunta se não encontrar nos locais padrão
    echo "Lazarus não encontrado nos locais padrão (~/lazarus ou ~/fpcupdeluxe/lazarus)."
    read -r -p "Onde o Lazarus está instalado? " LAZARUS_DIR
    if [ ! -x "$LAZARUS_DIR/lazbuild" ]; then
        echo "Erro: lazbuild não encontrado em $LAZARUS_DIR"
        exit 1
    fi
    echo "Informe o caminho para o PCP (ou ENTER para padrão):"
    read -r resp_pcp
    LAZBUILD_PCP_ARGS=()
    [ -n "$resp_pcp" ] && LAZBUILD_PCP_ARGS=(--pcp="$resp_pcp")
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
log "Componentes do Lazarus em: $LAZARUS_COMPONENTS"

# -------------------------------------------------
# 2) Lista de Pacotes (Built-in) Expandida
# -------------------------------------------------
PACKAGES=(
    "exampleswindow/exampleprojects.lpk"
    "lazreport/source/lazreport.lpk"
    "fpreport/design/lazfpreportdesign.lpk"
    "images/imagesforlazarus.lpk"
    "dbexport/lazdbexport.lpk"
    "multithreadprocs/multithreadprocslaz.lpk"
    "onlinepackagemanager/onlinepackagemanager.lpk"
)

echo ""
echo "────────── OPÇÕES DE DOCKING ─────────"
echo "Deseja ativar o docking na IDE (S/N)?"
echo "Pressione ENTER para manter o padrão (N)"
echo -n "> "
read -r resp_docking
if [[ "$resp_docking" =~ ^[Ss]$ ]]; then
    PACKAGES+=(
        "anchordocking/anchordocking.lpk"
        "anchordocking/design/anchordockingdsgn.lpk"
    )
fi

echo ""
echo "Deseja ativar o docking de formulário na IDE (S/N)?"
echo "Pressione ENTER para manter o padrão (N)"
echo -n "> "
read -r resp_form_docking
if [[ "$resp_form_docking" =~ ^[Ss]$ ]]; then
    PACKAGES+=(
        "dockedformeditor/dockedformeditor.lpk"
    )
fi

show_packages() {
    local pkg

    echo ""
    echo "────────── PACOTES A INSTALAR ─────────"
    for pkg in "${PACKAGES[@]}"; do
        echo "  - $LAZARUS_COMPONENTS/$pkg"
    done
}

show_packages

# -------------------------------------------------
# 3) Escolha de Widgetset (Interface)
# -------------------------------------------------
echo ""
echo "────────── COMPONENTES VISUAIS ─────────"
echo "Deseja reconstruir a IDE Lazarus usando um widgetset específico?"
echo "Pressione ENTER para manter o padrão ou digite: gtk, qt5, qt6"
echo -n "> "
read -r resp_widget
if [[ "$resp_widget" =~ ^[Ss]$ ]]; then
    # Por engano digitou 'S' então apaga, seguindo o comportamento do instalador ACBr.
    echo "Resposta ignorada"
    resp_widget=""
fi

LAZBUILD_WIDGETSET_ARGS=()
[ -n "$resp_widget" ] && LAZBUILD_WIDGETSET_ARGS=(--widgetset="$resp_widget")

# -------------------------------------------------
# 4) Funções de instalação e recompilação
# -------------------------------------------------
install_pkg() {
    local pkgfile="$1"

    log ". Registrando: $pkgfile"
    log "Comando: $LAZBUILD ${LAZBUILD_PCP_ARGS[*]} ${LAZBUILD_WIDGETSET_ARGS[*]} --add-package \"$pkgfile\""
    "$LAZBUILD" "${LAZBUILD_PCP_ARGS[@]}" "${LAZBUILD_WIDGETSET_ARGS[@]}" --add-package "$pkgfile"
}

rebuild_ide() {
    log "----------------------------------------------"
    log "Recompilando a IDE Lazarus para aplicar os pacotes na paleta..."
    log "Comando: $LAZBUILD ${LAZBUILD_PCP_ARGS[*]} ${LAZBUILD_WIDGETSET_ARGS[*]} --build-ide="
    "$LAZBUILD" "${LAZBUILD_PCP_ARGS[@]}" "${LAZBUILD_WIDGETSET_ARGS[@]}" --build-ide=
}

# -------------------------------------------------
# 5) Processamento e Recompilação
# -------------------------------------------------
log "=============================================="
log "Iniciando registro de pacotes..."
log "=============================================="

# Captura timestamp inicial para validar sucesso da compilação
[ -f "$LAZ_BIN" ] && start_ts=$(stat -c %Y "$LAZ_BIN") || start_ts=0

for p in "${PACKAGES[@]}"; do
    FULL_LPK="$LAZARUS_COMPONENTS/$p"
    if [ -f "$FULL_LPK" ]; then
        install_pkg "$FULL_LPK"
    else
        log "Aviso: Pacote não encontrado: $p"
    fi
done

rebuild_ide

# -------------------------------------------------
# 6) Validação Final (Timestamp)
# -------------------------------------------------
if [ -f "$LAZ_BIN" ]; then
    end_ts=$(stat -c %Y "$LAZ_BIN")
    if [ "$start_ts" -eq "$end_ts" ]; then
        log "ERRO: A data/hora do binário 'lazarus' não mudou. A recompilação falhou."
        exit 1
    else
        log "SUCESSO: IDE Lazarus recompilada e pacotes instalados."
        [ -n "$resp_widget" ] && log "Widgetset definido para: $resp_widget"
    fi
else
    log "ERRO: Binário do Lazarus não encontrado após a compilação."
    exit 1
fi
