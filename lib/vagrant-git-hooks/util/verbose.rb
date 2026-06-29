# frozen_string_literal: true

require "shellwords"

module VagrantGitHooks
  module Util
    module Verbose
      module_function

      def enabled?
        ENV["VGH_VERBOSE"].to_s == "1"
      end

      def log(*args)
        return unless enabled?

        line = args.length == 1 && args.first.is_a?(String) ? args.first : args.map(&:to_s).shelljoin
        warn("[VGH] #{line}")
      end
    end
  end
end
