class Roborev < Formula
  desc "Automatic code review daemon for git commits using AI agents"
  homepage "https://github.com/wesm/roborev"
  version "0.10.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/wesm/roborev/releases/download/v#{version}/roborev_#{version}_darwin_amd64.tar.gz"
      sha256 "INTEL_SHA256_PLACEHOLDER"
    end
    if Hardware::CPU.arm?
      url "https://github.com/wesm/roborev/releases/download/v#{version}/roborev_#{version}_darwin_arm64.tar.gz"
      sha256 "ARM64_SHA256_PLACEHOLDER"
    end
  end

  def install
    bin.install "roborev"
    bin.install "roborevd"
  end

  def caveats
    <<~EOS
      The roborev daemon (roborevd) starts automatically when needed.
      To initialize roborev in a git repository:
        roborev init
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/roborev version")
    assert_match version.to_s, shell_output("#{bin}/roborevd version")
  end
end
