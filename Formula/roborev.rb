class Roborev < Formula
  desc "Automatic code review daemon for git commits using AI agents"
  homepage "https://roborev.io"
  version "0.22.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_darwin_amd64.tar.gz"
      sha256 "0e937a64c9d7c5d4b7e258bf0e91b505a9cb06aa44c4d107d83c3c632f8d06f1"
    end
    if Hardware::CPU.arm?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_darwin_arm64.tar.gz"
      sha256 "a4cb6a2c9bac458d74e9d33f27df4dc502618683911f6bfe4f4bcf7eb81fc929"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_linux_amd64.tar.gz"
      sha256 "431f0078d3ffc218b3136caea6f75e64039faaf2acc679e15d11d26b80a55aef"
    end
    if Hardware::CPU.arm?
      url "https://github.com/roborev-dev/roborev/releases/download/v#{version}/roborev_#{version}_linux_arm64.tar.gz"
      sha256 "5f9ec412d6ab00d8767d1c417405cf7c3506602a99d722c3839562bd5fbbf025"
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
