# frozen_string_literal: true

require "digest"
require "fileutils"
require "time"
require_relative "../hook_builder"

module VagrantGitHooks
  module Util
    class Installer
      BACKUP_SUFFIX = ".bak"

      def initialize(hooks_dir:, manifest:, ui: nil)
        @hooks_dir = hooks_dir.to_s
        @manifest  = manifest
        @ui        = ui
      end

      # Installs or updates managed Git hooks.
      #
      # Existing foreign hooks are backed up once before replacement. Managed
      # hooks are updated in place and tracked in the manifest by SHA-256 digest.
      #
      # @param entries [Array<Hash>] Hook definitions with `:name` and either `:commands` or `:content`.
      # @param fail_on_error [Boolean] Whether generated hooks should include `set -e`.
      # @param dry_run [Boolean] Whether to report planned changes without writing files.
      # @return [Hash] Installation result with installed, updated, backed_up, and dry_run keys.
      def install(entries, fail_on_error: true, dry_run: false)
        FileUtils.mkdir_p(@hooks_dir) unless dry_run
        data = @manifest.load
        data["hooks_dir"] = @hooks_dir
        managed = data["managed"]
        result  = { installed: [], updated: [], backed_up: [], dry_run: dry_run }

        entries.each do |entry|
          name   = entry[:name].to_s
          script = build(entry, fail_on_error)
          path   = File.join(@hooks_dir, name)
          ours   = File.exist?(path) && HookBuilder.managed?(safe_read(path))

          backup = backup_if_foreign(path, name, ours, managed, result, dry_run)
          write_hook(path, script) unless dry_run

          (ours ? result[:updated] : result[:installed]) << name
          managed[name] = {
            "backup" => backup,
            "sha256" => Digest::SHA256.hexdigest(script),
            "installed_at" => now
          }
        end

        @manifest.save(data) unless dry_run
        result
      end

      # Removes managed hooks and restores backups recorded in the manifest.
      #
      # @param dry_run [Boolean] Whether to report planned changes without writing files.
      # @return [Hash] Uninstall result with removed, restored, and dry_run keys.
      def uninstall(dry_run: false)
        data    = @manifest.load
        base    = data["hooks_dir"] || @hooks_dir
        result  = { removed: [], restored: [], dry_run: dry_run }

        data["managed"].each do |name, info|
          path = File.join(base, name)

          if File.exist?(path) && HookBuilder.managed?(safe_read(path))
            File.delete(path) unless dry_run
            result[:removed] << name
          end

          backup = info["backup"]
          next unless backup && File.exist?(backup)

          restore(backup, path) unless dry_run
          result[:restored] << name
        end

        @manifest.clear unless dry_run
        result
      end

      # Reports whether hooks are installed, modified, foreign, or missing.
      #
      # @param configured_names [Array<String>] Hook names configured in the current Vagrantfile.
      # @return [Array<Hash>] Status rows with name, state, and backup fields.
      def status(configured_names = [])
        data    = @manifest.load
        base    = data["hooks_dir"] || @hooks_dir
        managed = data["managed"]
        names   = (managed.keys + configured_names.map(&:to_s)).uniq.sort

        names.map do |name|
          { name: name, state: state_of(File.join(base, name), managed[name]), backup: managed.dig(name, "backup") }
        end
      end

      private

      def build(entry, fail_on_error)
        if entry[:content]
          HookBuilder.adopt_script(name: entry[:name].to_s, content: entry[:content])
        else
          HookBuilder.script_for(name: entry[:name].to_s, commands: entry[:commands], fail_on_error: fail_on_error)
        end
      end

      def backup_if_foreign(path, name, ours, managed, result, dry_run)
        # Do not overwrite an existing backup: it is the user's original hook,
        # not a rolling history of plugin-generated updates.
        existing = managed.dig(name, "backup")
        return existing unless File.exist?(path) && !ours && existing.nil?

        backup = "#{path}#{BACKUP_SUFFIX}"
        return backup if File.exist?(backup)

        FileUtils.cp(path, backup) unless dry_run
        result[:backed_up] << name
        backup
      end

      def write_hook(path, script)
        File.write(path, script)
        File.chmod(0o755, path) unless Gem.win_platform?
      end

      def restore(backup, path)
        FileUtils.mv(backup, path)
        File.chmod(0o755, path) unless Gem.win_platform?
      end

      def state_of(path, info)
        # A managed hook with a changed digest is still ours, but status reports
        # it as modified so users can spot manual edits.
        return "missing" unless File.exist?(path)
        return "foreign" unless HookBuilder.managed?(safe_read(path))

        if info && Digest::SHA256.hexdigest(safe_read(path)) != info["sha256"]
          "modified"
        else
          "installed"
        end
      end

      def safe_read(path)
        File.read(path)
      rescue StandardError
        ""
      end

      def now
        Time.now.utc.iso8601
      rescue StandardError
        Time.now.utc.to_s
      end
    end
  end
end
