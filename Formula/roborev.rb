class Roborev < Formula
  desc "Automatic code review daemon for git commits using AI agents"
  homepage "https://roborev.io"
  version "0.19.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_darwin_amd64.tar.gz"
      sha256 "cc21cde9e5347534ca3fc9590970fc2ade1024c7d5f937178fc472a33ab2c634"
    end
    if Hardware::CPU.arm?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_darwin_arm64.tar.gz"
      sha256 "3b7fa7b5f0e5d0aa15cbb9542f26012928fe90fde41c8d460b495a9e521602aa"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_linux_amd64.tar.gz"
      sha256 "7fe7ef5151242cd427d2fb7010fa17db15a3a86ca1659788fa470fe30134d633"
    end
    if Hardware::CPU.arm?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_linux_arm64.tar.gz"
      sha256 "930843944d68d10513d3f54695555a6cd29bee46f2d00bdc5f67ae3baaba6bdf"
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
