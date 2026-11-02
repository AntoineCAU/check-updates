# Outils Python installés avec « uv tool » (comparés à PyPI)
src_available() { (( $+commands[uv] )) }
src_check() {
  local liste
  liste=$(uv tool list 2>&1) || { print -u2 -r -- "$liste"; return 1 }
  print -r -- "$liste" | helper uv
}
