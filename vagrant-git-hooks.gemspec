# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "vagrant-git-hooks"
  s.version     = File.read(File.join(__dir__, "lib/vagrant-git-hooks/VERSION")).strip
  s.summary     = "Manage git hooks from your Vagrantfile — a husky replacement with no Node/npm dependency"
  s.description = <<~DESC.strip
    Adds a `vagrant hooks` subcommand and installs declarative git hooks into the
    repository hooks directory on `vagrant up`. Ownership markers and per-hook
    backups make install/uninstall safe. Only Vagrant is required — no Node/npm.
  DESC
  s.authors     = ["Julien Poirou"]
  s.email       = ["julienpoirou@protonmail.com"]
  s.homepage    = "https://github.com/julienpoirou/vagrant-git-hooks"
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.1"

  s.files = Dir[
    "lib/**/*",
    "locales/*.yml",
    "README.md",
    "LICENSE.md",
    "CHANGELOG.md"
  ]
  s.require_paths = ["lib"]

  s.add_dependency "i18n", ">= 1.8"

  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.12"

  s.metadata = {
    "rubygems_mfa_required" => "true",
    "bug_tracker_uri" => "https://github.com/julienpoirou/vagrant-git-hooks/issues",
    "changelog_uri" => "https://github.com/julienpoirou/vagrant-git-hooks/blob/main/CHANGELOG.md",
    "source_code_uri" => "https://github.com/julienpoirou/vagrant-git-hooks",
    "homepage_uri" => "https://github.com/julienpoirou/vagrant-git-hooks"
  }
end
