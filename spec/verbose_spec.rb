# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/vagrant-git-hooks/util/verbose"

RSpec.describe VagrantGitHooks::Util::Verbose do
  around do |example|
    saved = ENV.fetch("VGH_VERBOSE", nil)
    example.run
    ENV["VGH_VERBOSE"] = saved
  end

  it "is disabled unless VGH_VERBOSE is exactly \"1\"" do
    ENV["VGH_VERBOSE"] = nil
    expect(described_class.enabled?).to be(false)
    ENV["VGH_VERBOSE"] = "true"
    expect(described_class.enabled?).to be(false)
    ENV["VGH_VERBOSE"] = "1"
    expect(described_class.enabled?).to be(true)
  end

  it "prints a shell-quoted argv to stderr when enabled" do
    ENV["VGH_VERBOSE"] = "1"
    expect { described_class.log("git", "-C", "/my repo", "rev-parse") }
      .to output(%r{\[VGH\] git -C /my\\ repo rev-parse}).to_stderr
  end

  it "prints a single string label verbatim" do
    ENV["VGH_VERBOSE"] = "1"
    expect { described_class.log("sh /tmp/hook (pre-commit)") }
      .to output("[VGH] sh /tmp/hook (pre-commit)\n").to_stderr
  end

  it "stays silent when disabled" do
    ENV["VGH_VERBOSE"] = nil
    expect { described_class.log("git", "status") }.not_to output.to_stderr
  end
end
