# frozen_string_literal: true

require "spec_helper"
require "vagrant-git-hooks/service"

RSpec.describe VagrantGitHooks::Service do
  let(:cfg_class) { Struct.new(:hooks, :hooks_source, :fail_on_error, keyword_init: true) }

  it "builds inline entries and adopts known hook files, inline winning" do
    Dir.mktmpdir do |root|
      src = File.join(root, "scripts")
      FileUtils.mkdir_p(src)
      File.write(File.join(src, "pre-commit"), "#!/bin/sh\necho fromfile\n")
      File.write(File.join(src, "commit-msg"), "#!/bin/sh\necho msg\n")
      File.write(File.join(src, "README.md"),  "not a hook")

      cfg     = cfg_class.new(hooks: { "pre-commit" => "rubocop" }, hooks_source: "scripts")
      entries = described_class.entries_from_config(cfg, root)

      expect(entries.map { |e| e[:name] }).to contain_exactly("pre-commit", "commit-msg")

      pre = entries.find { |e| e[:name] == "pre-commit" }
      expect(pre[:commands]).to eq("rubocop")
      expect(pre[:content]).to be_nil

      msg = entries.find { |e| e[:name] == "commit-msg" }
      expect(msg[:content]).to include("echo msg")
    end
  end

  it "returns only inline entries when no hooks_source is set" do
    cfg = cfg_class.new(hooks: { "pre-push" => "rake" }, hooks_source: nil)
    entries = described_class.entries_from_config(cfg, "/whatever")
    expect(entries).to eq([{ name: "pre-push", commands: "rake" }])
  end

  it "status lists hooks_source hooks (as missing) even with no inline hooks" do
    Dir.mktmpdir do |root|
      Open3.capture3("git", "init", "-q", root)
      src = File.join(root, "scripts")
      FileUtils.mkdir_p(src)
      File.write(File.join(src, "commit-msg"), "#!/bin/sh\necho msg\n")

      cfg  = cfg_class.new(hooks: {}, hooks_source: "scripts")
      rows = described_class.status(root: root, cfg: cfg)

      commit_msg = rows.find { |r| r[:name] == "commit-msg" }
      expect(commit_msg).not_to be_nil
      expect(commit_msg[:state]).to eq("missing")
    end
  end
end
