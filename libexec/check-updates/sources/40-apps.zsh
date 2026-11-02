# Applications installées hors Homebrew et hors App Store :
# comparées au catalogue public des casks Homebrew, sinon à leur flux Sparkle
src_available() { true }
src_check() { CU_OPEN_APP=${M[open_app]} CU_OPEN_SITE=${M[open_site]} helper apps }
