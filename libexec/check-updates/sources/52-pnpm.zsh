# Paquets pnpm globaux
src_available() { (( $+commands[pnpm] )) }
src_check() {
  local json
  json=$(pnpm outdated -g --format json 2>&1) # code 1 dès qu'un paquet est en retard : seul le JSON compte
  print -r -- "$json" | helper pnpm
}
