class Roborev < Formula
  desc "Automatic code review daemon for git commits using AI agents"
  homepage "https://roborev.io"
  version "0.66.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/kenn-io/roborev/releases/download/v0.66.0/roborev_0.66.0_darwin_amd64.tar.gz"
      sha256 "99a1a4c4a9782426cf64810beaf8929281541fc574825849233015e2dcf09f45"
    end
    if Hardware::CPU.arm?
      url "https://github.com/kenn-io/roborev/releases/download/v0.66.0/roborev_0.66.0_darwin_arm64.tar.gz"
      sha256 "eb6e68b2a1a86343f6147045ab124b7b49496c3c17afbea4b70990280b9817d7"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/kenn-io/roborev/releases/download/v0.66.0/roborev_0.66.0_linux_amd64.tar.gz"
      sha256 "3a57bda163559cf9b9062a3808c0979c4b46853ff712681d2160d676e2ea098a"
    end
    if Hardware::CPU.arm?
      url "https://github.com/kenn-io/roborev/releases/download/v0.66.0/roborev_0.66.0_linux_arm64.tar.gz"
      sha256 "371accc17a7afa1e38f10ac7e2e0540681cdcd5d73bdfb670e51cc24d225862f"
    end
  end

  def install
    bin.install "roborev"
  end

  def caveats
    <<~EOS
      To initialize roborev in a git repository:
        cd your-repo
        roborev init

      The daemon starts automatically when needed.
      For more info: https://roborev.io/quickstart/
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/roborev version")
  end
end
