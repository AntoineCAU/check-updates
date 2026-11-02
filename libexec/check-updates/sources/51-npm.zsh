# Paquets npm globaux (de la version de Node par défaut si nvm est utilisé)
src_available() {
  if [[ -s "${NVM_DIR:=$HOME/.nvm}/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh" --no-use
    nvm use default >/dev/null 2>&1
  fi
  (( $+commands[npm] ))
}
src_check() {
  local prefixe="" json
  [[ -w "$(npm prefix -g)/lib/node_modules" ]] || prefixe="sudo "
  json=$(npm outdated -g --json 2>/dev/null) # code 1 dès qu'un paquet est en retard : seul le JSON compte
  print -r -- "$json" | CU_PREFIX=$prefixe helper npm
}
