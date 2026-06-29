# frozen_string_literal: true

require_relative "config"
require_relative "util/git"
require_relative "util/manifest"
require_relative "util/installer"

module VagrantGitHooks
  module Service
    module_function

    # Builds installable hook entries from direct config and an optional source directory.
    #
    # @param cfg [VagrantGitHooks::Config] Plugin configuration.
    # @param root [String, Pathname] Git repository root.
    # @return [Array<Hash>] Hook entries consumed by the installer.
    def entries_from_config(cfg, root)
      entries = {}

      (cfg.hooks || {}).each do |name, cmd|
        entries[name.to_s] = { name: name.to_s, commands: cmd }
      end

      adopt_source(cfg, root, entries)
      entries.values
    end

    def adopt_source(cfg, root, entries)
      # Explicit Vagrantfile hooks win over hooks_source files with the same name.
      src = cfg.hooks_source.to_s.strip
      return if src.empty?

      dir = File.absolute_path?(src) ? src : File.expand_path(src, root.to_s)
      return unless File.directory?(dir)

      Dir.children(dir).sort.each do |fname|
        next unless Config::KNOWN_HOOKS.include?(fname)

        path = File.join(dir, fname)
        next unless File.file?(path)
        next if entries.key?(fname)

        entries[fname] = { name: fname, content: File.read(path) }
      end
    end

    def installer_for(root, ui: nil)
      Util::Installer.new(
        hooks_dir: Util::Git.hooks_dir(root),
        manifest: Util::Manifest.new(Util::Git.manifest_path(root)),
        ui: ui
      )
    end

    # Installs or updates hooks for a Git repository.
    #
    # @param root [String, Pathname] Git repository root.
    # @param cfg [VagrantGitHooks::Config] Plugin configuration.
    # @param ui [Object, nil] Optional Vagrant UI object.
    # @param dry_run [Boolean] Whether to report planned changes without writing files.
    # @return [Hash] Installation result.
    def install!(root:, cfg:, ui: nil, dry_run: false)
      installer_for(root, ui: ui).install(
        entries_from_config(cfg, root),
        fail_on_error: cfg.fail_on_error,
        dry_run: dry_run
      )
    end

    # Removes managed hooks and restores backed-up foreign hooks.
    #
    # @param root [String, Pathname] Git repository root.
    # @param ui [Object, nil] Optional Vagrant UI object.
    # @param dry_run [Boolean] Whether to report planned changes without writing files.
    # @return [Hash] Uninstall result.
    def uninstall!(root:, ui: nil, dry_run: false)
      installer_for(root, ui: ui).uninstall(dry_run: dry_run)
    end

    # Reports hook installation status for configured and previously managed hooks.
    #
    # @param root [String, Pathname] Git repository root.
    # @param cfg [VagrantGitHooks::Config] Plugin configuration.
    # @return [Array<Hash>] Status rows keyed by hook name.
    def status(root:, cfg:)
      configured = entries_from_config(cfg, root).map { |e| e[:name].to_s }
      installer_for(root).status(configured)
    end
  end
end
