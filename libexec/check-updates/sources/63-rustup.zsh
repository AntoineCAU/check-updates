# Chaînes d'outils Rust et rustup lui-même
src_available() { (( $+commands[rustup] )) }
src_check() {
  local sortie
  sortie=$(rustup check 2>&1) || { print -u2 -r -- "$sortie"; return 1 }
  # « stable-aarch64-apple-darwin - Update available : 1.80.0 (…) -> 1.81.0 (…) »
  print -r -- "$sortie" | sed -nE "s/^(rustup) - Update available : ([^ ]+).* -> ([^ ]+).*/\1 \2 → \3${T}rustup self update/p; s/^([^ ]+) - Update available : ([^ ]+).* -> ([^ ]+).*/\1 \2 → \3${T}rustup update \1/p"
  return 0
}
