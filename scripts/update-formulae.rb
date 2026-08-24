#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

SEMVER_TAG_PATTERN = /\Av?\d+\.\d+\.\d+\z/
SHA256_PATTERN = /\A[0-9a-f]{64}\z/i

FormulaConfig = Struct.new(
  :name,
  :class_name,
  :path,
  :desc,
  :homepage,
  :repo,
  :artifact_prefix,
  :artifact_infix,
  :minimum_version,
  :version_command,
  :test_lines,
  :caveats,
  keyword_init: true,
)

FORMULAE = [
  FormulaConfig.new(
    name: "agentsview",
    class_name: "Agentsview",
    path: "Formula/agentsview.rb",
    desc: "Local web viewer and analytics for AI coding agent sessions",
    homepage: "https://agentsview.io",
    repo: "kenn-io/agentsview",
    artifact_prefix: "agentsview",
    version_command: "agentsview version",
    caveats: <<~EOS,
      To start the local web UI:
        agentsview serve

      To print token usage summaries:
        agentsview usage daily
    EOS
  ),
  FormulaConfig.new(
    name: "roborev",
    class_name: "Roborev",
    path: "Formula/roborev.rb",
    desc: "Automatic code review daemon for git commits using AI agents",
    homepage: "https://roborev.io",
    repo: "kenn-io/roborev",
    artifact_prefix: "roborev",
    version_command: "roborev version",
    caveats: <<~EOS,
      To initialize roborev in a git repository:
        cd your-repo
        roborev init

      The daemon starts automatically when needed.
      For more info: https://roborev.io/quickstart/
    EOS
  ),
  FormulaConfig.new(
    name: "kata",
    class_name: "Kata",
    path: "Formula/kata.rb",
    desc: "Git-native issue tracking for agentic development",
    homepage: "https://katatracker.com",
    repo: "kenn-io/kata",
    artifact_prefix: "kata",
    artifact_infix: "homebrew",
    minimum_version: "0.14.2",
    test_lines: [
      'info = shell_output("#{bin}/kata version --json")',
      'assert_match %Q("version":"v#{version}"), info',
      %q(assert_match '"distribution":"homebrew"', info),
      'system bin/"kata", "_web-assets-check"',
      'assert_match "brew upgrade kata", shell_output("#{bin}/kata update --yes 2>&1", 2)',
    ],
  ),
].freeze

PLATFORMS = {
  darwin_amd64: { os: "macos", cpu: "intel" },
  darwin_arm64: { os: "macos", cpu: "arm" },
  linux_amd64: { os: "linux", cpu: "intel" },
  linux_arm64: { os: "linux", cpu: "arm" },
}.freeze

def fetch_json(url)
  uri = URI(url)
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github+json"
  request["X-GitHub-Api-Version"] = "2022-11-28"
  request["Authorization"] = "Bearer #{ENV.fetch("GITHUB_TOKEN")}" if ENV["GITHUB_TOKEN"]

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  raise "GET #{url} failed: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

def current_version(path)
  formula = File.read(path)
  match = formula.match(/^\s*version\s+"([^"]+)"/)
  raise "Could not find version in #{path}" unless match

  match[1]
rescue Errno::ENOENT
  nil
end

def asset_sha(asset)
  digest = asset.fetch("digest", "")
  sha256 = digest.delete_prefix("sha256:") if digest.start_with?("sha256:")
  return sha256 if sha256&.match?(SHA256_PATTERN)

  raise "Asset #{asset.fetch("name")} does not include a valid SHA-256 digest"
end

def release_version(tag_name)
  raise "Release tag #{tag_name.inspect} is not a supported semver tag" unless tag_name.match?(SEMVER_TAG_PATTERN)

  tag_name.delete_prefix("v")
end

def validate_asset_url!(config, tag_name, filename, url)
  uri = URI(url)
  expected_path = "/#{config.repo}/releases/download/#{tag_name}/#{filename}"
  return if uri.scheme == "https" && uri.host == "github.com" && uri.path == expected_path && uri.query.nil?

  raise "Asset #{filename} has unexpected download URL #{url.inspect}"
rescue URI::InvalidURIError
  raise "Asset #{filename} has invalid download URL #{url.inspect}"
end

def version_segments(version)
  version.split(".").map(&:to_i)
end

def compare_versions(left, right)
  version_segments(left) <=> version_segments(right)
end

def newer_version?(latest, current)
  compare_versions(latest, current).positive?
end

def release_action(config, release, current)
  return :ignore if release.fetch("draft") || release.fetch("prerelease")

  latest = release_version(release.fetch("tag_name"))
  if current.nil?
    return :ignore if config.minimum_version && compare_versions(latest, config.minimum_version).negative?

    return :update
  end

  comparison = compare_versions(latest, current)
  if comparison.negative?
    raise "refusing to downgrade #{config.name} from #{current} to #{latest}"
  end

  return :current if comparison.zero?

  :update
end

def artifact_filename(config, version, platform)
  [config.artifact_prefix, version, config.artifact_infix, platform].compact.join("_") + ".tar.gz"
end

def release_assets_by_platform(config, release, version)
  tag_name = release.fetch("tag_name")
  assets = release.fetch("assets").group_by { |asset| asset.fetch("name") }

  PLATFORMS.to_h do |platform, _metadata|
    filename = artifact_filename(config, version, platform)
    matching_assets = assets.fetch(filename, [])
    unless matching_assets.one?
      raise "Release #{tag_name} must include exactly one #{filename}; found #{matching_assets.length}"
    end

    asset = matching_assets.first
    url = asset.fetch("browser_download_url")
    validate_asset_url!(config, tag_name, filename, url)
    [platform, { url: url, sha256: asset_sha(asset) }]
  end
end

def ruby_string(value)
  value.dump
end

def render_formula(config, version, assets)
  macos_intel = assets.fetch(:darwin_amd64)
  macos_arm = assets.fetch(:darwin_arm64)
  linux_intel = assets.fetch(:linux_amd64)
  linux_arm = assets.fetch(:linux_arm64)
  caveats_block = if config.caveats
    caveats = config.caveats.lines(chomp: true).map { |line| line.empty? ? "" : "      #{line}" }.join("\n")
    <<~RUBY
      def caveats
        <<~EOS
    #{caveats}
        EOS
      end
    RUBY
  end
  test_lines = config.test_lines || [
    %(assert_match version.to_s, shell_output("\#{bin}/#{config.version_command}")),
  ]
  test_body = test_lines.map { |line| "    #{line}" }.join("\n")

  formula = <<~RUBY
    class #{config.class_name} < Formula
      desc #{ruby_string(config.desc)}
      homepage #{ruby_string(config.homepage)}
      version #{ruby_string(version)}
      license "MIT"

      on_macos do
        if Hardware::CPU.intel?
          url #{ruby_string(macos_intel.fetch(:url))}
          sha256 #{ruby_string(macos_intel.fetch(:sha256))}
        end
        if Hardware::CPU.arm?
          url #{ruby_string(macos_arm.fetch(:url))}
          sha256 #{ruby_string(macos_arm.fetch(:sha256))}
        end
      end

      on_linux do
        if Hardware::CPU.intel?
          url #{ruby_string(linux_intel.fetch(:url))}
          sha256 #{ruby_string(linux_intel.fetch(:sha256))}
        end
        if Hardware::CPU.arm?
          url #{ruby_string(linux_arm.fetch(:url))}
          sha256 #{ruby_string(linux_arm.fetch(:sha256))}
        end
      end

      def install
        bin.install #{ruby_string(config.name)}
      end
  RUBY
  formula << "\n#{caveats_block}" if caveats_block
  formula << <<~RUBY

      test do
    #{test_body}
      end
    end
  RUBY
  formula
end

def current_formula_asset_digests(config, path, version)
  expected_filenames = PLATFORMS.to_h do |platform, _metadata|
    [artifact_filename(config, version, platform), platform]
  end
  digests = {}
  formula = File.read(path)
  formula.scan(/^\s*url\s+"([^"]+)"\s*$\n^\s*sha256\s+"([0-9a-fA-F]{64})"\s*$/) do |url, sha256|
    filename = File.basename(URI(url).path)
    platform = expected_filenames[filename]
    next unless platform

    raise "Formula #{path} contains duplicate #{platform} assets" if digests.key?(platform)

    digests[platform] = sha256.downcase
  end
  digests
end

def verify_current_formula_assets!(config, path, version, release_assets)
  actual = current_formula_asset_digests(config, path, version)
  changed = PLATFORMS.keys.select do |platform|
    actual[platform] != release_assets.fetch(platform).fetch(:sha256).downcase
  end
  return if changed.empty?

  raise "#{config.name} #{version} assets changed after the formula was recorded: #{changed.join(", ")}; " \
        "refusing to rewrite an existing version"
end

def run
  updated = []

  FORMULAE.each do |config|
    release = fetch_json("https://api.github.com/repos/#{config.repo}/releases/latest")
    installed_version = current_version(config.path)
    action = release_action(config, release, installed_version)
    next if action == :ignore

    latest_version = release_version(release.fetch("tag_name"))
    assets = release_assets_by_platform(config, release, latest_version)
    if action == :current
      verify_current_formula_assets!(config, config.path, latest_version, assets)
      next
    end

    File.write(config.path, render_formula(config, latest_version, assets))
    updated << "#{config.name} #{installed_version || "not installed"} -> #{latest_version}"
  end

  if updated.empty?
    puts "No formula updates available."
  else
    puts "Updated formulae:"
    updated.each { |line| puts "  #{line}" }
  end
end

run if $PROGRAM_NAME == __FILE__
