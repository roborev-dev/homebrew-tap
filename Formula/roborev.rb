class Roborev < Formula
  desc "Automatic code review daemon for git commits using AI agents"
  homepage "https://roborev.io"
  version "0.18.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_darwin_amd64.tar.gz"
      sha256 "1be75b3d784e0986c3c1f0fcbd3f352ada246b89bb63f373ad5101b1b89c803e"
    end
    if Hardware::CPU.arm?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_darwin_arm64.tar.gz"
      sha256 "f76c6e1e262f78f975d4068b0f9317c79b97b5f8a0f36a7bbbd6b33bb859e238"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_linux_amd64.tar.gz"
      sha256 "a6e3f688000db99c65163590c005b93653ab89983fe77d84bacfce901c91e8cf"
    end
    if Hardware::CPU.arm?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_linux_arm64.tar.gz"
      sha256 "c16d597a698164a2393fdd7218f01fbdde01520786ba32b67dcf77aa7df77934"
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
