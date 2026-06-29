# frozen_string_literal: true

require "open3"
require_relative "verbose"

module VagrantGitHooks
  module Util
    module Git
      module_function

      def available?
        Verbose.log("git", "--version")
        _out, _err, st = Open3.capture3("git", "--version")
        st.success?
      rescue StandardError
        false
      end

      def repo?(root)
        out, _err, st = capture(root, "rev-parse", "--is-inside-work-tree")
        st.success? && out.strip == "true"
      end

      def toplevel(root)
        out, _err, st = capture(root, "rev-parse", "--show-toplevel")
        st.success? && !out.strip.empty? ? out.strip : nil
      end

      def hooks_dir(root)
        resolve(root, "hooks") || File.join(toplevel(root) || root.to_s, ".git", "hooks")
      end

      def manifest_path(root)
        resolve(root, "vagrant-git-hooks.json") ||
          File.join(toplevel(root) || root.to_s, ".git", "vagrant-git-hooks.json")
      end

      def resolve(root, name)
        out, _err, st = capture(root, "rev-parse", "--git-path", name)
        return nil unless st.success?

        path = out.strip
        return nil if path.empty?

        absolute?(path) ? path : File.expand_path(path, root.to_s)
      end

      def capture(root, *args)
        Verbose.log("git", "-C", root.to_s, *args)
        Open3.capture3("git", "-C", root.to_s, *args)
      end

      def absolute?(path)
        File.absolute_path?(path)
      end
    end
  end
end
