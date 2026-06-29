# frozen_string_literal: true

require "spec_helper"
require "vagrant-git-hooks/util/manifest"

RSpec.describe VagrantGitHooks::Util::Manifest do
  it "returns an empty shape, roundtrips and clears" do
    Dir.mktmpdir do |dir|
      m = described_class.new(File.join(dir, "sub", "manifest.json"))
      expect(m.load).to eq({ "hooks_dir" => nil, "managed" => {} })

      m.save("hooks_dir" => "/h", "managed" => { "pre-commit" => { "sha256" => "x" } })
      expect(m.load["hooks_dir"]).to eq("/h")
      expect(m.load["managed"]).to have_key("pre-commit")

      expect(m.clear).to be(true)
      expect(File.exist?(m.path)).to be(false)
    end
  end

  it "tolerates a corrupt file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "manifest.json")
      File.write(path, "{ not json")
      expect(described_class.new(path).load).to eq({ "hooks_dir" => nil, "managed" => {} })
    end
  end
end
