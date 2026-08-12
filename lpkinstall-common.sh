#!/bin/bash
# lpkinstall-common.sh - Funções compartilhadas pelos instaladores Lazarus

_lpi_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$@"
  else
    echo "$@"
  fi
}

_lpi_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

_lpi_abspath() {
  local path="$1"

  if [ -z "$path" ]; then
    return 1
  fi

  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
    return $?
  fi

  (
    cd "$(dirname "$path")" || exit 1
    printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")"
  )
}

_lpi_is_subpath() {
  local parent="$1"
  local child="$2"

  case "$child" in
    "$parent"|"$parent"/*) return 0 ;;
    *) return 1 ;;
  esac
}

_lpi_is_forbidden_root() {
  local path="$1"

  [ -z "$path" ] && return 0
  [ "$path" = "/" ] && return 0
  [ -n "${HOME:-}" ] && [ "$path" = "$HOME" ] && return 0

  return 1
}

_lpi_validate_rel_build_path() {
  local rel="$1"

  rel="$(_lpi_trim "$rel")"

  [ -z "$rel" ] && return 1
  [ "$rel" = "." ] && return 1
  [ "$rel" = ".." ] && return 1
  [[ "$rel" == /* ]] && return 1
  [[ "$rel" == *".."* ]] && return 1

  case "$rel" in
    lib|lib/*|Lib|Lib/*|Binary|Binary/*|packages/lazarus/lib|packages/lazarus/lib/*|Stax-package/lib|Stax-package/lib/*|source/lib|source/lib/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Remove com segurança uma pasta de artefatos de compilação (.ppu, .o, etc.).
# Parâmetros: nome_componente anchor_dir component_dir caminho_relativo
safe_remove_build_dir() {
  local component_name="$1"
  local anchor_dir="$2"
  local component_dir="$3"
  local rel_path="$4"
  local target abs_anchor abs_component abs_target rel_from_component

  anchor_dir="$(_lpi_trim "$anchor_dir")"
  component_dir="$(_lpi_trim "$component_dir")"
  rel_path="$(_lpi_trim "$rel_path")"
  component_name="$(_lpi_trim "$component_name")"

  if [ -z "$anchor_dir" ] || [ -z "$component_dir" ] || [ -z "$rel_path" ]; then
    _lpi_log " Aviso: limpeza de build ignorada para ${component_name:-?} (parâmetro em branco)."
    return 0
  fi

  if ! _lpi_validate_rel_build_path "$rel_path"; then
    _lpi_log " Erro: limpeza recusada para $component_name — caminho relativo não permitido: '$rel_path'"
    return 1
  fi

  if [ ! -d "$anchor_dir" ]; then
    _lpi_log " Aviso: limpeza ignorada para $component_name — pasta anchor inexistente: $anchor_dir"
    return 0
  fi

  if [ ! -d "$component_dir" ]; then
    _lpi_log " Aviso: limpeza ignorada para $component_name — pasta do componente inexistente: $component_dir"
    return 0
  fi

  abs_anchor="$(_lpi_abspath "$anchor_dir")" || {
    _lpi_log " Erro: limpeza recusada para $component_name — falha ao resolver anchor: $anchor_dir"
    return 1
  }
  abs_component="$(_lpi_abspath "$component_dir")" || {
    _lpi_log " Erro: limpeza recusada para $component_name — falha ao resolver componente: $component_dir"
    return 1
  }

  target="$component_dir/$rel_path"
  if [ ! -e "$target" ]; then
    return 0
  fi

  abs_target="$(_lpi_abspath "$target")" || {
    _lpi_log " Erro: limpeza recusada para $component_name — falha ao resolver alvo: $target"
    return 1
  }

  if _lpi_is_forbidden_root "$abs_target"; then
    _lpi_log " Erro: limpeza recusada para $component_name — destino proibido: $abs_target"
    return 1
  fi

  if ! _lpi_is_subpath "$abs_anchor" "$abs_component"; then
    _lpi_log " Erro: limpeza recusada para $component_name — componente fora de components: $abs_component"
    return 1
  fi

  if ! _lpi_is_subpath "$abs_component" "$abs_target"; then
    _lpi_log " Erro: limpeza recusada para $component_name — alvo fora do componente: $abs_target"
    return 1
  fi

  if [ "$abs_target" = "$abs_component" ] || [ "$abs_target" = "$abs_anchor" ]; then
    _lpi_log " Erro: limpeza recusada para $component_name — não é permitido apagar a raiz do componente."
    return 1
  fi

  rel_from_component="${abs_target#$abs_component/}"
  if [ "$rel_from_component" = "$abs_target" ] || [ -z "$rel_from_component" ]; then
    _lpi_log " Erro: limpeza recusada para $component_name — alvo inválido: $abs_target"
    return 1
  fi

  _lpi_log " Limpando artefatos de compilação ($component_name): $abs_target"
  _lpi_log ".  Evita conflitos com .ppu obsoletos após atualizações do repositório."
  rm -rf -- "$abs_target"
}

# Limpa uma ou mais pastas de build relativas à raiz do componente.
clean_component_build_artifacts() {
  local component_name="$1"
  local anchor_dir="$2"
  local component_dir="$3"
  local rel

  component_name="$(_lpi_trim "$component_name")"
  anchor_dir="$(_lpi_trim "$anchor_dir")"
  component_dir="$(_lpi_trim "$component_dir")"

  if [ -z "$component_name" ] || [ -z "$anchor_dir" ] || [ -z "$component_dir" ]; then
    _lpi_log " Aviso: limpeza de build ignorada — nome, anchor ou pasta do componente em branco."
    return 0
  fi

  shift 3
  if [ "$#" -eq 0 ]; then
    _lpi_log " Aviso: limpeza de build ignorada para $component_name — nenhuma subpasta informada."
    return 0
  fi

  for rel in "$@"; do
    safe_remove_build_dir "$component_name" "$anchor_dir" "$component_dir" "$rel"
  done
}
# --- OPM (packages.lazarus-ide.org) ---

OPM_BASE_URL="https://packages.lazarus-ide.org/"

opm_marker_path() {
  printf '%s/.acbr_opm_source\n' "$1"
}

opm_package_ready() {
  local dest_dir="$1"
  local zip_name="$2"
  local relative_lpk="$3"
  local marker lpk

  marker="$(opm_marker_path "$dest_dir")"
  lpk="$dest_dir/${relative_lpk}"
  [ -f "$marker" ] && [ -f "$lpk" ] || return 1
  grep -qiF "$zip_name" "$marker"
}

find_file_recursive() {
  local root_dir="$1"
  local file_name="$2"
  find "$root_dir" -type f -iname "$file_name" 2>/dev/null | head -n 1
}

collect_lpk_files() {
  local root_dir="$1"
  find "$root_dir" -type f -iname '*.lpk' \
    ! -path '*/lib/*' ! -path '*/units/*' ! -path '*/.*/*' 2>/dev/null | sort
}

is_design_lpk() {
  local lpk_path="$1"
  local name
  name="$(basename "$lpk_path" | tr '[:upper:]' '[:lower:]')"
  local path_lc
  path_lc="$(printf '%s' "$lpk_path" | tr '[:upper:]' '[:lower:]')"
  [[ "$name" == *design* || "$name" == *dsgn* || "$name" == *_des.* ]] && return 0
  [[ "$path_lc" == */ide/* ]] && return 0
  return 1
}

# Imprime caminhos absolutos: preferred (csv ;) primeiro, depois demais descobertos (runtime antes de design).
resolve_lpks_to_install() {
  local dest_dir="$1"
  local preferred_csv="${2:-}"
  local -a preferred discovered runtime design out
  local rel abs name p seen_key
  declare -A seen=()

  preferred=()
  if [ -n "$preferred_csv" ]; then
    IFS=';' read -ra preferred <<< "$preferred_csv"
  fi

  for rel in "${preferred[@]}"; do
    rel="${rel//\\//}"
    rel="$(_lpi_trim "$rel")"
    [ -z "$rel" ] && continue
    abs="$dest_dir/$rel"
    if [ ! -f "$abs" ]; then
      name="$(basename "$rel")"
      abs="$(find_file_recursive "$dest_dir" "$name" || true)"
    fi
    if [ -n "$abs" ] && [ -f "$abs" ]; then
      seen_key="$(printf '%s' "$abs" | tr '[:upper:]' '[:lower:]')"
      if [ -z "${seen[$seen_key]:-}" ]; then
        seen[$seen_key]=1
        out+=("$abs")
      fi
    fi
  done

  mapfile -t discovered < <(collect_lpk_files "$dest_dir")
  runtime=()
  design=()
  for p in "${discovered[@]}"; do
    [ -z "$p" ] && continue
    if is_design_lpk "$p"; then
      design+=("$p")
    else
      runtime+=("$p")
    fi
  done
  for p in "${runtime[@]}" "${design[@]}"; do
    seen_key="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')"
    if [ -z "${seen[$seen_key]:-}" ]; then
      seen[$seen_key]=1
      out+=("$p")
    fi
  done

  printf '%s\n' "${out[@]}"
}

# Usa LAZBUILD / LAZBUILD_PCP_ARGS / LAZBUILD_WIDGETSET_ARGS se existirem; senao so LAZBUILD.
_lpi_run_lazbuild() {
  local -a cmd
  cmd=("$LAZBUILD")
  if declare -p LAZBUILD_PCP_ARGS >/dev/null 2>&1; then
    cmd+=("${LAZBUILD_PCP_ARGS[@]}")
  fi
  if declare -p LAZBUILD_WIDGETSET_ARGS >/dev/null 2>&1; then
    cmd+=("${LAZBUILD_WIDGETSET_ARGS[@]}")
  fi
  cmd+=("$@")
  _lpi_log "Comando: ${cmd[*]}"
  "${cmd[@]}"
}

# Retorna 0=ok, 1=falha, 2=aviso
install_lpk_file() {
  local lpk_path="$1"

  if [ ! -f "$lpk_path" ]; then
    _lpi_log "Aviso: lpk ausente: $lpk_path"
    return 1
  fi

  _lpi_log "Instalando: $lpk_path"
  if _lpi_run_lazbuild --add-package "$lpk_path"; then
    return 0
  fi

  _lpi_log "Aviso: --add-package falhou; compilando..."
  if ! _lpi_run_lazbuild "$lpk_path"; then
    _lpi_log "ERRO: falha ao compilar: $lpk_path"
    return 1
  fi

  if _lpi_run_lazbuild --add-package "$lpk_path"; then
    return 0
  fi

  _lpi_log "Tentando --add-package-link (pacote runtime)..."
  if _lpi_run_lazbuild --add-package-link "$lpk_path"; then
    return 0
  fi

  _lpi_log "Aviso: compilou, mas nao registrou: $lpk_path"
  return 2
}

package_root_from_found_lpk() {
  local found_lpk_abs="$1"
  local relative_lpk="$2"
  local rel parts depth p i

  rel="${relative_lpk//'\'/'/'}"
  IFS='/' read -ra parts <<< "$rel"
  depth="${#parts[@]}"
  p="$found_lpk_abs"
  for ((i = 0; i < depth; i++)); do
    p="$(dirname "$p")"
  done
  printf '%s\n' "$p"
}

# Baixa zip do OPM e instala em dest_dir. relative_lpk relativo a raiz do pacote.
ensure_opm_zip() {
  local zip_file_name="$1"
  local dest_dir="$2"
  local relative_lpk="$3"
  local url tmp_root archive extract_dir found_lpk pkg_root leaf marker

  relative_lpk="${relative_lpk//'\'/'/'}"

  if opm_package_ready "$dest_dir" "$zip_file_name" "$relative_lpk"; then
    _lpi_log "OPM ja presente ($zip_file_name): $dest_dir"
    return 0
  fi

  url="${OPM_BASE_URL}${zip_file_name}"
  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/acbr_opm.XXXXXX")"
  archive="$tmp_root/$zip_file_name"
  extract_dir="$tmp_root/extract"
  mkdir -p "$extract_dir"

  _lpi_log "Baixando: $url"
  if ! curl -L --fail --retry 3 --connect-timeout 30 -o "$archive" "$url"; then
    _lpi_log "Aviso: download OPM falhou: $url"
    rm -rf "$tmp_root"
    return 1
  fi

  if ! unzip -q -o "$archive" -d "$extract_dir"; then
    _lpi_log "Aviso: extracao OPM falhou: $archive"
    rm -rf "$tmp_root"
    return 1
  fi

  leaf="$(basename "$relative_lpk")"
  found_lpk="$(find_file_recursive "$extract_dir" "$leaf" || true)"
  if [ -z "$found_lpk" ]; then
    _lpi_log "Aviso: $leaf nao encontrado em $zip_file_name"
    rm -rf "$tmp_root"
    return 1
  fi

  pkg_root="$(package_root_from_found_lpk "$found_lpk" "$relative_lpk")"
  if [ -z "$pkg_root" ] || [ ! -d "$pkg_root" ]; then
    _lpi_log "Aviso: raiz do pacote OPM invalida para $zip_file_name"
    rm -rf "$tmp_root"
    return 1
  fi

  if [ -e "$dest_dir" ]; then
    _lpi_log "Substituindo pasta existente por OPM $zip_file_name..."
    rm -rf "$dest_dir"
  fi
  mv "$pkg_root" "$dest_dir"

  marker="$(opm_marker_path "$dest_dir")"
  {
    echo "$url"
    echo "instalado em $(date)"
  } >"$marker"

  if [ -f "$dest_dir/$relative_lpk" ]; then
    _lpi_log "OPM instalado: $url -> $dest_dir"
    rm -rf "$tmp_root"
    return 0
  fi

  _lpi_log "Aviso: apos extrair OPM, nao achei $dest_dir/$relative_lpk"
  rm -rf "$tmp_root"
  return 1
}
