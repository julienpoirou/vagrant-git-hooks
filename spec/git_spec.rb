# frozen_string_literal: true

require "spec_helper"
require "open3"
require "vagrant-git-hooks/util/git"

RSpec.describe VagrantGitHooks::Util::Git do
  let(:ok)  { instance_double(Process::Status, success?: true) }
  let(:nok) { instance_double(Process::Status, success?: false) }

  it "repo? is true only when inside a work tree" do
    allow(Open3).to receive(:capture3)
      .with("git", "-C", "/repo", "rev-parse", "--is-inside-work-tree")
      .and_return(["true\n", "", ok])
    expect(described_class.repo?("/repo")).to be(true)
  end

  it "hooks_dir resolves git rev-parse output against the repo root" do
    allow(Open3).to receive(:capture3)
      .with("git", "-C", "/repo", "rev-parse", "--git-path", "hooks")
      .and_return([".git/hooks\n", "", ok])
    expect(described_class.hooks_dir("/repo")).to eq(File.expand_path(".git/hooks", "/repo"))
  end

  it "hooks_dir falls back to <toplevel>/.git/hooks when rev-parse fails" do
    allow(Open3).to receive(:capture3)
      .with("git", "-C", "/repo", "rev-parse", "--git-path", "hooks")
      .and_return(["", "boom", nok])
    allow(Open3).to receive(:capture3)
      .with("git", "-C", "/repo", "rev-parse", "--show-toplevel")
      .and_return(["/repo\n", "", ok])
    expect(described_class.hooks_dir("/repo")).to eq(File.join("/repo", ".git", "hooks"))
  end
end
