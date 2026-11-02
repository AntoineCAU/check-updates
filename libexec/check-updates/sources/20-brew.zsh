# Homebrew : formules et casks installés par brew
src_available() { (( $+commands[brew] )) }
src_check() {
  local json erreur
  if ! erreur=$(brew update --quiet 2>&1 >/dev/null); then
    print -r -- "#$T${M[brew_update_failed]} $(print -r -- "$erreur" | grep -m1 '^Error:')"
  fi
  json=$(brew outdated --json=v2) || return 1
  print -r -- "$json" | helper brew
}
