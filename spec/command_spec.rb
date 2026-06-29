# frozen_string_literal: true

require "spec_helper"
require "vagrant-git-hooks/command"

RSpec.describe VagrantGitHooks::Command do
  let(:ui)  { double("ui", info: nil, warn: nil, error: nil) }
  let(:env) { double("env", ui: ui) }

  def run(argv)
    described_class.new(argv, env).execute
  end

  it "version --json prints a normalized payload" do
    out  = capture_stdout { @code = run(%w[version --json]) }
    json = JSON.parse(out)
    expect(@code).to eq(0)
    expect(json["status"]).to eq("success")
    expect(json["version"]).to eq(VagrantGitHooks::VERSION)
  end

  it "an unknown command returns 1" do
    expect(run(%w[bogus])).to eq(1)
  end

  describe "#do_install (Service delegation)" do
    subject(:cmd) { described_class.allocate }

    before do
      cmd.instance_variable_set(:@opts, { json: true, dry_run: false, no_emoji: true })
      allow(VagrantGitHooks::Util::Git).to receive_messages(available?: true, repo?: true)
    end

    it "reports installed counts as JSON" do
      allow(VagrantGitHooks::Service).to receive(:install!)
        .and_return({ installed: ["pre-commit"], updated: [], backed_up: [] })

      out  = capture_stdout { @code = cmd.send(:do_install, "/repo", double("cfg")) }
      json = JSON.parse(out)
      expect(@code).to eq(0)
      expect(json["action"]).to eq("install")
      expect(json["installed"]).to eq(["pre-commit"])
    end

    it "fails cleanly when the directory is not a git repo" do
      allow(VagrantGitHooks::Util::Git).to receive(:repo?).and_return(false)
      out = capture_stdout { @code = cmd.send(:do_install, "/repo", double("cfg")) }
      expect(@code).to eq(1)
      expect(JSON.parse(out)["status"]).to eq("error")
    end
  end

  describe "#do_uninstall (confirmation)" do
    subject(:cmd) { described_class.allocate }

    before do
      allow(VagrantGitHooks::Util::Git).to receive_messages(available?: true, repo?: true)
    end

    it "refuses in --json without --yes and does not call Service.uninstall!" do
      cmd.instance_variable_set(:@opts, { json: true, yes: false, dry_run: false, no_emoji: true })
      allow(VagrantGitHooks::Service).to receive(:uninstall!)

      out = capture_stdout { @code = cmd.send(:do_uninstall, "/repo", double("cfg")) }
      expect(@code).to eq(1)
      expect(JSON.parse(out)["status"]).to eq("error")
      expect(VagrantGitHooks::Service).not_to have_received(:uninstall!)
    end

    it "proceeds in --json when --yes is given" do
      cmd.instance_variable_set(:@opts, { json: true, yes: true, dry_run: false, no_emoji: true })
      allow(VagrantGitHooks::Service).to receive(:uninstall!).and_return({ removed: [], restored: [] })

      out = capture_stdout { @code = cmd.send(:do_uninstall, "/repo", double("cfg")) }
      expect(@code).to eq(0)
      expect(JSON.parse(out)["status"]).to eq("success")
    end
  end
end
