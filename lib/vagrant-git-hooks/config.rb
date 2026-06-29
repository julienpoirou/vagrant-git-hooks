# frozen_string_literal: true

module VagrantGitHooks
  # Vagrant configuration for managed Git hooks.
  #
  # @!attribute hooks
  #   @return [Hash{String=>String,Array<String>}] Hook commands keyed by hook name.
  # @!attribute hooks_source
  #   @return [String, nil] Directory containing hook scripts to adopt.
  # @!attribute install_on_up
  #   @return [Boolean] Whether hooks are installed during `vagrant up`.
  # @!attribute remove_on_destroy
  #   @return [Boolean] Whether managed hooks are removed during `vagrant destroy`.
  # @!attribute fail_on_error
  #   @return [Boolean] Whether generated hooks should stop on the first failing command.
  class Config < Vagrant.plugin("2", :config)
    KNOWN_HOOKS = %w[
      applypatch-msg pre-applypatch post-applypatch
      pre-commit pre-merge-commit prepare-commit-msg commit-msg post-commit
      pre-rebase post-checkout post-merge pre-push pre-auto-gc
      post-rewrite post-index-change reference-transaction fsmonitor-watchman
      p4-changelist p4-prepare-changelist p4-post-changelist p4-pre-submit
    ].freeze

    attr_accessor :hooks, :hooks_source, :install_on_up, :remove_on_destroy,
                  :fail_on_error, :locale, :verbose

    def initialize
      @hooks             = UNSET_VALUE
      @hooks_source      = UNSET_VALUE
      @install_on_up     = UNSET_VALUE
      @remove_on_destroy = UNSET_VALUE
      @fail_on_error     = UNSET_VALUE
      @locale            = UNSET_VALUE
      @verbose           = UNSET_VALUE
    end

    def finalize!
      @hooks             = {}    if @hooks             == UNSET_VALUE
      @hooks_source      = nil   if @hooks_source      == UNSET_VALUE
      @install_on_up     = true  if @install_on_up     == UNSET_VALUE
      @remove_on_destroy = false if @remove_on_destroy == UNSET_VALUE
      @fail_on_error     = true  if @fail_on_error     == UNSET_VALUE
      @locale            = "en"  if @locale            == UNSET_VALUE
      @verbose           = false if @verbose           == UNSET_VALUE
    end

    def validate(_machine)
      errors = []

      validate_hooks(errors)

      errors << "hooks_source must be a String path" if @hooks_source && !@hooks_source.is_a?(String)

      errors << "install_on_up must be boolean" unless boolean?(@install_on_up)
      errors << "remove_on_destroy must be boolean"  unless boolean?(@remove_on_destroy)
      errors << "fail_on_error must be boolean"      unless boolean?(@fail_on_error)

      unless @locale.is_a?(String) && %w[en fr].include?(@locale.to_s[0, 2].downcase)
        errors << "locale must be 'en' or 'fr'"
      end

      { "vagrant-git-hooks" => errors }
    end

    private

    def validate_hooks(errors)
      unless @hooks.is_a?(Hash)
        errors << 'hooks must be a Hash of { "hook-name" => "command" | [commands] }'
        return
      end

      @hooks.each do |name, cmd|
        errors << "unknown git hook: #{name}" unless KNOWN_HOOKS.include?(name.to_s)

        unless cmd.is_a?(String) || (cmd.is_a?(Array) && cmd.all?(String))
          errors << "hook '#{name}' command must be a String or Array of Strings"
          next
        end

        blank = cmd.is_a?(String) ? cmd.strip.empty? : Array(cmd).all? { |c| c.to_s.strip.empty? }
        errors << "hook '#{name}' command is empty" if blank
      end
    end

    def boolean?(val)
      [true, false].include?(val)
    end
  end
end
