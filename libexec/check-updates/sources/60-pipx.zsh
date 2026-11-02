# Outils Python installés avec pipx (comparés à PyPI)
src_available() { (( $+commands[pipx] )) }
src_check() {
  local json
  json=$(pipx list --json) || return 1
  print -r -- "$json" | helper pipx
}
