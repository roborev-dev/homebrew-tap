# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../scripts/update-formulae"

class UpdateFormulaeTest < Minitest::Test
  KATA_ARCHIVES = %w[
    kata_0.14.2_homebrew_darwin_amd64.tar.gz
    kata_0.14.2_homebrew_darwin_arm64.tar.gz
    kata_0.14.2_homebrew_linux_amd64.tar.gz
    kata_0.14.2_homebrew_linux_arm64.tar.gz
  ].freeze

  def test_updater_can_be_loaded_without_network_access
    script = File.expand_path("../scripts/update-formulae.rb", __dir__)
    program = <<~RUBY
      require "net/http"
      class << Net::HTTP
        def start(...)
          raise "unexpected network access"
        end
      end
      require #{script.dump}
      puts "loaded"
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", program)

    assert status.success?, stderr
    assert_equal "loaded\n", stdout
  end

  def test_formula_patch_includes_a_new_untracked_formula
    Dir.mktmpdir("formula-patch-test") do |repo|
      FileUtils.mkdir_p(File.join(repo, "Formula"))
      File.write(File.join(repo, "Formula", "agentsview.rb"), "class Agentsview < Formula\nend\n")
      run_git(repo, "init")
      run_git(repo, "config", "user.name", "Test User")
      run_git(repo, "config", "user.email", "test@example.com")
      run_git(repo, "add", "Formula/agentsview.rb")
      run_git(repo, "commit", "-m", "Initial formula")

      File.write(File.join(repo, "Formula", "kata.rb"), "class Kata < Formula\nend\n")
      patch_path = File.join(repo, "formula.patch")
      script = File.expand_path("../scripts/create-formula-patch.sh", __dir__)

      _stdout, stderr, status = Open3.capture3("bash", script, patch_path, chdir: repo)

      assert status.success?, stderr
      patch = File.read(patch_path)
      assert_includes patch, "diff --git a/Formula/kata.rb b/Formula/kata.rb"
      assert_includes patch, "+class Kata < Formula"
    end
  end

  def test_kata_configuration_uses_the_documented_archive_contract
    assert_equal %w[agentsview roborev kata], FORMULAE.map(&:name)
    assert_equal "0.14.2", kata_config.minimum_version

    filenames = PLATFORMS.keys.map { |platform| artifact_filename(kata_config, "0.14.2", platform) }

    assert_equal KATA_ARCHIVES, filenames
  end

  def test_existing_formula_archive_names_are_unchanged
    agentsview = FORMULAE.find { |config| config.name == "agentsview" }
    roborev = FORMULAE.find { |config| config.name == "roborev" }

    assert_equal "agentsview_0.31.1_darwin_arm64.tar.gz",
                 artifact_filename(agentsview, "0.31.1", :darwin_arm64)
    assert_equal "roborev_0.64.0_linux_amd64.tar.gz",
                 artifact_filename(roborev, "0.64.0", :linux_amd64)
  end

  def test_kata_bootstrap_ignores_old_releases_and_accepts_the_floor
    assert_equal :ignore, release_action(kata_config, release("v0.14.1"), nil)
    assert_equal :update, release_action(kata_config, release("v0.14.2"), nil)
  end

  def test_installed_kata_rejects_a_release_below_the_bootstrap_floor
    error = assert_raises(RuntimeError) do
      release_action(kata_config, release("v0.14.1"), "0.14.2")
    end

    assert_match "refusing to downgrade kata from 0.14.2 to 0.14.1", error.message
  end

  def test_equal_release_is_current_and_older_release_is_rejected
    assert_equal :current, release_action(kata_config, release("v0.14.2"), "0.14.2")

    error = assert_raises(RuntimeError) do
      release_action(kata_config, release("v0.14.2"), "0.14.3")
    end

    assert_match "refusing to downgrade kata from 0.14.3 to 0.14.2", error.message
  end

  def test_draft_and_prerelease_are_ignored
    assert_equal :ignore, release_action(kata_config, release("v0.14.2", draft: true), nil)
    assert_equal :ignore, release_action(kata_config, release("v0.14.2", prerelease: true), nil)
  end

  def test_kata_assets_require_exactly_one_canonical_archive_per_platform
    candidate = release("v0.14.2", assets: kata_assets)
    assets = release_assets_by_platform(kata_config, candidate, "0.14.2")

    assert_equal KATA_ARCHIVES, assets.values.map { |asset| File.basename(asset.fetch(:url)) }

    candidate.fetch("assets") << candidate.fetch("assets").first.dup
    error = assert_raises(RuntimeError) do
      release_assets_by_platform(kata_config, candidate, "0.14.2")
    end
    assert_match "must include exactly one kata_0.14.2_homebrew_darwin_amd64.tar.gz", error.message
  end

  def test_kata_assets_reject_a_missing_canonical_archive
    assets = kata_assets.drop(1)

    error = assert_raises(RuntimeError) do
      release_assets_by_platform(kata_config, release("v0.14.2", assets: assets), "0.14.2")
    end

    assert_match "must include exactly one kata_0.14.2_homebrew_darwin_amd64.tar.gz; found 0", error.message
  end

  def test_kata_assets_require_github_sha256_digest
    assets = kata_assets
    assets.first.delete("digest")

    error = assert_raises(RuntimeError) do
      release_assets_by_platform(kata_config, release("v0.14.2", assets: assets), "0.14.2")
    end

    assert_match "does not include a valid SHA-256 digest", error.message
  end

  def test_kata_asset_urls_are_pinned_to_the_release
    assets = kata_assets
    assets.first["browser_download_url"] = "https://example.com/kata.tar.gz"

    error = assert_raises(RuntimeError) do
      release_assets_by_platform(kata_config, release("v0.14.2", assets: assets), "0.14.2")
    end

    assert_match "has unexpected download URL", error.message
  end

  def test_kata_formula_renders_its_package_contract
    assets = release_assets_by_platform(kata_config, release("v0.14.2", assets: kata_assets), "0.14.2")
    formula = render_formula(kata_config, "0.14.2", assets)

    assert_includes formula, 'bin.install "kata"'
    assert_includes formula, 'info = shell_output("#{bin}/kata version --json")'
    assert_includes formula, 'assert_match %Q("version":"v#{version}"), info'
    assert_includes formula, %q(assert_match '"distribution":"homebrew"', info)
    refute_includes formula, '%Q("distribution":"homebrew")'
    assert_includes formula, 'system bin/"kata", "_web-assets-check"'
    assert_includes formula, 'assert_match "brew upgrade kata", shell_output("#{bin}/kata update --yes 2>&1", 2)'
    refute_includes formula, "def caveats"
  end

  def test_existing_formula_output_contract_is_preserved
    agentsview = FORMULAE.find { |config| config.name == "agentsview" }
    assets = synthetic_assets(agentsview, "0.31.1")
    formula = render_formula(agentsview, "0.31.1", assets)

    assert_includes formula, "def caveats"
    assert_includes formula, "agentsview serve"
    assert_includes formula, 'assert_match version.to_s, shell_output("#{bin}/agentsview version")'

    roborev = FORMULAE.find { |config| config.name == "roborev" }
    formula = render_formula(roborev, "0.64.0", synthetic_assets(roborev, "0.64.0"))

    assert_includes formula, "roborev init"
    assert_includes formula, 'assert_match version.to_s, shell_output("#{bin}/roborev version")'
  end

  def test_same_version_asset_drift_is_rejected_instead_of_rewritten
    agentsview = FORMULAE.find { |config| config.name == "agentsview" }
    assets = synthetic_assets(agentsview, "0.31.1")

    Dir.mktmpdir("formula-drift-test") do |directory|
      formula_path = File.join(directory, "agentsview.rb")
      File.write(formula_path, render_formula(agentsview, "0.31.1", assets))

      verify_current_formula_assets!(agentsview, formula_path, "0.31.1", assets)

      drifted = assets.transform_values(&:dup)
      drifted.fetch(:darwin_arm64)[:sha256] = "b" * 64
      error = assert_raises(RuntimeError) do
        verify_current_formula_assets!(agentsview, formula_path, "0.31.1", drifted)
      end

      assert_match "agentsview 0.31.1 assets changed after the formula was recorded", error.message
      assert_match "darwin_arm64", error.message
    end
  end

  private

  def kata_config
    FORMULAE.find { |config| config.name == "kata" }
  end

  def release(tag_name, draft: false, prerelease: false, assets: [])
    {
      "tag_name" => tag_name,
      "draft" => draft,
      "prerelease" => prerelease,
      "assets" => assets,
    }
  end

  def kata_assets
    KATA_ARCHIVES.map do |filename|
      {
        "name" => filename,
        "browser_download_url" => "https://github.com/kenn-io/kata/releases/download/v0.14.2/#{filename}",
        "digest" => "sha256:#{'a' * 64}",
      }
    end
  end

  def synthetic_assets(config, version)
    PLATFORMS.to_h do |platform, _metadata|
      filename = artifact_filename(config, version, platform)
      [platform, {
        url: "https://github.com/#{config.repo}/releases/download/v#{version}/#{filename}",
        sha256: "a" * 64,
      }]
    end
  end

  def run_git(repo, *args)
    _stdout, stderr, status = Open3.capture3("git", *args, chdir: repo)
    assert status.success?, stderr
  end
end
