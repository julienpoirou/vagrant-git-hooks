# frozen_string_literal: true

require "spec_helper"
require "vagrant-git-hooks/config"

RSpec.describe VagrantGitHooks::Config do
  def cfg(overrides = {})
    c = described_class.new
    c.finalize!
    overrides.each { |k, v| c.public_send("#{k}=", v) }
    c
  end

  def errors(config)
    config.validate(nil)["vagrant-git-hooks"]
  end

  it "applies defaults on finalize!" do
    c = cfg
    expect(c.hooks).to eq({})
    expect(c.hooks_source).to be_nil
    expect(c.install_on_up).to be(true)
    expect(c.remove_on_destroy).to be(false)
    expect(c.fail_on_error).to be(true)
    expect(c.locale).to eq("en")
  end

  it "accepts a valid hooks hash (String and Array commands)" do
    c = cfg(hooks: { "pre-commit" => "rubocop", "pre-push" => %w[a b] })
    expect(errors(c)).to be_empty
  end

  it "rejects an unknown git hook name" do
    expect(errors(cfg(hooks: { "pre-comit" => "rubocop" }))).to include(a_string_matching(/unknown git hook/))
  end

  it "accepts the extended client-side hooks (p4-*, reference-transaction, pre-auto-gc)" do
    extra = %w[
      pre-auto-gc reference-transaction
      p4-changelist p4-prepare-changelist p4-post-changelist p4-pre-submit
    ]
    c = cfg(hooks: extra.to_h { |h| [h, "echo #{h}"] })
    expect(errors(c)).to be_empty
  end

  it "rejects sendemail-validate (intentionally unsupported)" do
    expect(errors(cfg(hooks: { "sendemail-validate" => "echo" })))
      .to include(a_string_matching(/unknown git hook/))
  end

  it "rejects a non-string/array command and an empty command" do
    expect(errors(cfg(hooks: { "pre-commit" => 42 }))).to include(a_string_matching(/must be a String or Array/))
    expect(errors(cfg(hooks: { "pre-commit" => "  " }))).to include(a_string_matching(/is empty/))
  end

  it "rejects non-hash hooks, bad boolean and bad locale" do
    expect(errors(cfg(hooks: []))).to include(a_string_matching(/hooks must be a Hash/))
    expect(errors(cfg(install_on_up: "yes"))).to include(a_string_matching(/install_on_up must be boolean/))
    expect(errors(cfg(locale: "de"))).to include(a_string_matching(/locale must be/))
  end
end
