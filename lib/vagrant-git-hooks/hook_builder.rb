# frozen_string_literal: true

require "time"

module VagrantGitHooks
  module HookBuilder
    SHEBANG     = "#!/usr/bin/env sh"
    BLOCK_START = "# >>> vagrant-git-hooks (managed) >>>"
    BLOCK_STOP  = "# <<< vagrant-git-hooks (managed) <<<"

    module_function

    # Builds a managed Git hook script from configured shell commands.
    #
    # @param name [String] Git hook name.
    # @param commands [String, Array<String>] Shell commands written to the hook body.
    # @param fail_on_error [Boolean] Whether to include `set -e`.
    # @param newline [String] Line separator used in the generated script.
    # @return [String] Complete hook script.
    def script_for(name:, commands:, fail_on_error: true, newline: "\n")
      lines = header(name, "do not edit manually")
      lines << "set -e" if fail_on_error
      lines.concat(body_lines(commands))
      lines << BLOCK_STOP
      lines.join(newline) + newline
    end

    # Wraps an existing hook body in plugin markers.
    #
    # Preserves user-provided hook bodies when adopting from hooks_source, but
    # wraps them in markers so uninstall and status can manage them later.
    #
    # @param name [String] Git hook name.
    # @param content [String] Existing hook script content.
    # @param newline [String] Line separator used in the generated script.
    # @return [String] Managed hook script.
    def adopt_script(name:, content:, newline: "\n")
      lines = content.to_s.split(/\r?\n/, -1)
      lines.pop if lines.last == ""

      shebang = lines.first&.start_with?("#!") ? lines.shift : SHEBANG
      head    = [shebang, BLOCK_START, "# Managed by Vagrant - adopted from hooks_source (hook: #{name})"]

      (head + lines + [BLOCK_STOP]).join(newline) + newline
    end

    def managed?(content)
      content.to_s.include?(BLOCK_START)
    end

    def header(name, note)
      ts = begin
        Time.now.utc.iso8601
      rescue StandardError
        Time.now.utc.to_s
      end
      [
        SHEBANG,
        BLOCK_START,
        "# Managed by Vagrant - #{note} (hook: #{name})",
        "# Generated: #{ts}"
      ]
    end

    def body_lines(commands)
      Array(commands).flat_map { |c| c.to_s.split("\n") }
    end
  end
end
