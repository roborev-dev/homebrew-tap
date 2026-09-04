class Kata < Formula
  desc "Git-native issue tracking for agentic development"
  homepage "https://katatracker.com"
  version "0.16.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/kenn-io/kata/releases/download/v0.16.0/kata_0.16.0_homebrew_darwin_amd64.tar.gz"
      sha256 "38cf9650723b883b1772636cc526b19a6eb21f41503928159d4457d4e49dab47"
    end
    if Hardware::CPU.arm?
      url "https://github.com/kenn-io/kata/releases/download/v0.16.0/kata_0.16.0_homebrew_darwin_arm64.tar.gz"
      sha256 "a23f177cadb78311b45d3753d2ad16cf553b906872b90f47982dd05c628ce0d8"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/kenn-io/kata/releases/download/v0.16.0/kata_0.16.0_homebrew_linux_amd64.tar.gz"
      sha256 "9355e098d07b349898af0d6a9039a7bd1bf9e50afe0c37805442bc5dc1891181"
    end
    if Hardware::CPU.arm?
      url "https://github.com/kenn-io/kata/releases/download/v0.16.0/kata_0.16.0_homebrew_linux_arm64.tar.gz"
      sha256 "01bb2f5872160b7c98ef8f84bdac80f2c821d04d4b24c71abe141274fae6fc46"
    end
  end

  def install
    bin.install "kata"
  end

  test do
    info = shell_output("#{bin}/kata version --json")
    assert_match %Q("version":"v#{version}"), info
    assert_match '"distribution":"homebrew"', info
    system bin/"kata", "_web-assets-check"
    assert_match "brew upgrade kata", shell_output("#{bin}/kata update --yes 2>&1", 2)
  end
end
