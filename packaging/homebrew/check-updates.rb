# Formule à copier dans le dépôt du tap (github.com/AntoineCAU/homebrew-tap, dossier Formula/).
# À chaque version : mettre à jour url et sha256 (shasum -a 256 sur l'archive du tag).
class CheckUpdates < Formula
  desc "Find what is out of date on your Mac and update it from a checklist"
  homepage "https://github.com/AntoineCAU/check-updates"
  url "https://github.com/AntoineCAU/check-updates/archive/refs/tags/v0.1.4.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on :macos

  def install
    bin.install "bin/check-updates"
    prefix.install "libexec"
  end

  def caveats
    <<~EOS
      Check now:
        check-updates

      Check every day (off by default):
        check-updates schedule on [HH:MM]
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/check-updates --version")
    system "zsh", "-n", bin/"check-updates"
  end
end
