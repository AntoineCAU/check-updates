# Binaires Rust installés avec « cargo install » (comparés à crates.io)
src_available() { [[ -f "$HOME/.cargo/.crates2.json" ]] }
src_check() { helper cargo }
