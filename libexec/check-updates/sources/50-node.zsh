# Node.js installé avec nvm : correctifs de la majeure par défaut et nouvelle LTS
src_available() { [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]] }
src_check() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  source "$NVM_DIR/nvm.sh" --no-use
  nvm use default >/dev/null 2>&1 || { print -u2 "nvm: no default version (nvm alias default <version>)"; return 1 }
  local courant=$(node --version) meme lts
  meme=$(nvm version-remote "${${courant#v}%%.*}" 2>&1)
  lts=$(nvm version-remote --lts 2>&1)
  [[ "$meme" == v<->.<->.<-> && "$lts" == v<->.<->.<-> ]] || { print -u2 -r -- "nvm version-remote: unexpected answer ($meme / $lts)"; return 3 }
  [[ "$meme" != "$courant" ]] && \
    print -r -- "Node $courant → $meme (${M[node_same]})${T}nvm install $meme --reinstall-packages-from=$courant && nvm alias default $meme"
  [[ "$lts" != "$courant" && "$lts" != "$meme" && ! -d "$NVM_DIR/versions/node/$lts" ]] && \
    print -r -- "Node LTS $lts (${M[node_lts]})${T}nvm install $lts && nvm use default"
  return 0
}
