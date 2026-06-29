# frozen_string_literal: true

require "spec_helper"
require "vagrant-git-hooks/util/installer"
require "vagrant-git-hooks/util/manifest"

RSpec.describe VagrantGitHooks::Util::Installer do
  around do |example|
    Dir.mktmpdir do |dir|
      @hooks    = File.join(dir, "hooks")
      @manifest = VagrantGitHooks::Util::Manifest.new(File.join(dir, "manifest.json"))
      example.run
    end
  end

  def installer
    described_class.new(hooks_dir: @hooks, manifest: @manifest)
  end

  def hook_path(name)
    File.join(@hooks, name)
  end

  it "installs a hook carrying our marker" do
    res = installer.install([{ name: "pre-commit", commands: "rubocop" }])
    expect(res[:installed]).to eq(["pre-commit"])
    expect(File.read(hook_path("pre-commit"))).to include(VagrantGitHooks::HookBuilder::BLOCK_START)
  end

  it "backs up a foreign hook before replacing it, and restores it on uninstall" do
    FileUtils.mkdir_p(@hooks)
    File.write(hook_path("pre-commit"), "#!/bin/sh\necho original\n")

    res = installer.install([{ name: "pre-commit", commands: "rubocop" }])
    expect(res[:backed_up]).to eq(["pre-commit"])
    expect(File.exist?("#{hook_path("pre-commit")}.bak")).to be(true)
    expect(File.read(hook_path("pre-commit"))).to include("rubocop")

    installer.uninstall
    expect(File.read(hook_path("pre-commit"))).to include("echo original")
    expect(File.exist?("#{hook_path("pre-commit")}.bak")).to be(false)
  end

  it "updates an already-managed hook in place without a second backup" do
    installer.install([{ name: "pre-commit", commands: "a" }])
    res = installer.install([{ name: "pre-commit", commands: "b" }])
    expect(res[:updated]).to eq(["pre-commit"])
    expect(res[:backed_up]).to be_empty
    expect(File.exist?("#{hook_path("pre-commit")}.bak")).to be(false)
    expect(File.read(hook_path("pre-commit"))).to include("b")
  end

  it "reports status: installed/modified, foreign and missing" do
    installer.install([{ name: "pre-commit", commands: "a" }])
    File.write(hook_path("pre-commit"), "#{File.read(hook_path("pre-commit"))}\n# tampered")
    File.write(hook_path("pre-push"), "#!/bin/sh\necho x\n")

    rows  = installer.status(%w[pre-push commit-msg])
    state = rows.each_with_object({}) { |r, h| h[r[:name]] = r[:state] }
    expect(state["pre-commit"]).to eq("modified")
    expect(state["pre-push"]).to eq("foreign")
    expect(state["commit-msg"]).to eq("missing")
  end

  it "dry_run changes nothing on disk or in the manifest" do
    installer.install([{ name: "pre-commit", commands: "a" }], dry_run: true)
    expect(File.exist?(hook_path("pre-commit"))).to be(false)
    expect(@manifest.load["managed"]).to be_empty
  end
end
