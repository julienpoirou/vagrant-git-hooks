# frozen_string_literal: true

require "json"
require "fileutils"

module VagrantGitHooks
  module Util
    class Manifest
      attr_reader :path

      def initialize(path)
        @path = path.to_s
      end

      # Loads the hook manifest from disk.
      #
      # Invalid or missing manifest data is treated as empty so hook commands can
      # recover from interrupted runs.
      #
      # @return [Hash] Normalized manifest data.
      def load
        return empty unless File.exist?(@path)

        data = JSON.parse(File.read(@path))
        data.is_a?(Hash) ? normalize(data) : empty
      rescue StandardError
        empty
      end

      # Saves normalized hook manifest data.
      #
      # @param data [Hash] Manifest data.
      # @return [Hash] Original data argument.
      def save(data)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate(normalize(data)))
        data
      end

      def clear
        File.delete(@path) if File.exist?(@path)
        true
      rescue StandardError
        false
      end

      private

      def empty
        { "hooks_dir" => nil, "managed" => {} }
      end

      def normalize(data)
        {
          "hooks_dir" => data["hooks_dir"],
          "managed" => (data["managed"].is_a?(Hash) ? data["managed"] : {})
        }
      end
    end
  end
end
