class Roborev < Formula
  desc "Automatic code review daemon for git commits using AI agents"
  homepage "https://roborev.io"
  version "0.67.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/kenn-io/roborev/releases/download/v0.67.0/roborev_0.67.0_darwin_amd64.tar.gz"
      sha256 "b10d14f1fada231636e5e76628e0a2a01a85a8f96a7f0352089e69faad935b67"
    end
    if Hardware::CPU.arm?
      url "https://github.com/kenn-io/roborev/releases/download/v0.67.0/roborev_0.67.0_darwin_arm64.tar.gz"
      sha256 "28e3b84eb8e0d6f81a306c7c1f75c953954c192de2d99a47a8fe46c6ee93b090"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/kenn-io/roborev/releases/download/v0.67.0/roborev_0.67.0_linux_amd64.tar.gz"
      sha256 "68ba22c586813bd55797973cb176157fa36936b02db2d4bee46bbd499bffbb87"
    end
    if Hardware::CPU.arm?
      url "https://github.com/kenn-io/roborev/releases/download/v0.67.0/roborev_0.67.0_linux_arm64.tar.gz"
      sha256 "ef5a13f480ece9c3bfdfa070259ba66ad83d72bbd466484fac512c0af0a41a02"
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
