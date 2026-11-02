# Outils gérés par mise (https://mise.jdx.dev)
src_available() { (( $+commands[mise] )) }
src_check() {
  local json
  json=$(mise outdated --json) || return 1
  print -r -- "$json" | helper mise
}
