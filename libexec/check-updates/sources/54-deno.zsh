# Deno installé avec son script officiel (~/.deno) ; installé avec Homebrew, la source brew s'en charge
src_available() { [[ -x "${DENO_INSTALL:-$HOME/.deno}/bin/deno" ]] }
src_check() {
  local deno="${DENO_INSTALL:-$HOME/.deno}/bin/deno" version
  version=$("$deno" --version 2>&1) || { print -u2 -r -- "$version"; return 1 }
  print -r -- "$version" | helper deno "$deno"
}
