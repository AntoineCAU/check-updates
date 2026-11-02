# Bun installé avec son script officiel (~/.bun) ; installé avec Homebrew ou npm, ces sources s'en chargent
src_available() { [[ -x "${BUN_INSTALL:-$HOME/.bun}/bin/bun" ]] }
src_check() {
  local bun="${BUN_INSTALL:-$HOME/.bun}/bin/bun" version
  version=$("$bun" --version 2>&1) || { print -u2 -r -- "$version"; return 1 }
  print -r -- "$version" | helper bun "$bun"
}
