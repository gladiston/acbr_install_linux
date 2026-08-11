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
