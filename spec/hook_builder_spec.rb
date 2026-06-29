# frozen_string_literal: true

require "spec_helper"
require "vagrant-git-hooks/hook_builder"

RSpec.describe VagrantGitHooks::HookBuilder do
  it "builds a managed inline hook with shebang, markers and set -e" do
    s = described_class.script_for(name: "pre-commit", commands: "rubocop --parallel")
    expect(s.split("\n").first).to eq("#!/usr/bin/env sh")
    expect(s).to include(described_class::BLOCK_START)
    expect(s).to include(described_class::BLOCK_STOP)
    expect(s).to include("set -e")
    expect(s).to include("rubocop --parallel")
    expect(described_class.managed?(s)).to be(true)
  end

  it "omits set -e when fail_on_error is false and supports multiline arrays" do
    s = described_class.script_for(name: "pre-push", commands: %W[a b\nc], fail_on_error: false)
    expect(s).not_to include("set -e")
    %w[a b c].each { |line| expect(s.split("\n")).to include(line) }
  end

  it "passes hook arguments through verbatim" do
    s = described_class.script_for(name: "commit-msg", commands: "commitlint --edit $1")
    expect(s).to include("commitlint --edit $1")
  end

  it "adopts a script, preserving its own shebang and adding markers" do
    s = described_class.adopt_script(name: "pre-commit", content: "#!/bin/bash\necho hi\n")
    expect(s.split("\n").first).to eq("#!/bin/bash")
    expect(described_class.managed?(s)).to be(true)
    expect(s).to include("echo hi")
  end

  it "adds a default shebang when the adopted script has none" do
    s = described_class.adopt_script(name: "pre-commit", content: "echo hi\n")
    expect(s.split("\n").first).to eq("#!/usr/bin/env sh")
  end
end
