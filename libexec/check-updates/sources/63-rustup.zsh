
# Chaînes d'outils Rust et rustup lui-même
src_available() { (( $+commands[rustup] )) }
src_check() {
  local sortie code=0 lignes
  # Les versions récentes de rustup check sortent en erreur quand il y a une mise à jour :
  # c'est la sortie qui tranche, pas le code
  sortie=$(rustup check 2>&1) || code=$?
  # « stable-aarch64-apple-darwin - update available: 1.99.1 (…) -> 1.100.0 (…) »
  # (anciennes versions : « Update available : »)
  lignes=$(print -r -- "$sortie" | sed -nE "s/^(rustup) - [Uu]pdate available ?: ([^ ]+).* -> ([^ ]+).*/\1 \2 → \3${T}rustup self update/p; s/^([^ ]+) - [Uu]pdate available ?: ([^ ]+).* -> ([^ ]+).*/\1 \2 → \3${T}rustup update \1/p")
  if (( code )) && [[ -z "$lignes" ]]; then print -u2 -r -- "$sortie"; return 1; fi
  # Format inconnu : une ligne qui n'annonce ni une mise à jour ni « à jour »
  if print -r -- "$sortie" | grep -vE '^$|^(info|warn|warning): | - ([Uu]pdate available|[Uu]p to date) ?:' | grep -q .; then
    print -u2 -r -- "$sortie"; return 3
  fi
  [[ -n "$lignes" ]] && print -r -- "$lignes"
  return 0
}
