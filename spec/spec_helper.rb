# frozen_string_literal: true

require "json"
require "stringio"
require "tmpdir"
require "fileutils"

ENV["VGH_LANG"]     = "en"
ENV["VGH_NO_EMOJI"] = "1"

unless defined?(Vagrant)
  module Vagrant
    def self.plugin(_version, type = nil)
      case type
      when :config
        Class.new do
          const_set(:UNSET_VALUE, :__UNSET__) unless const_defined?(:UNSET_VALUE)
        end
      when :command
        Class.new do
          def initialize(argv, env)
            @argv = argv
            @env  = env
          end

          def parse_options(parser)
            parser.permute!(@argv)
            @argv
          rescue OptionParser::InvalidOption
            nil
          end
        end
      else
        Class.new
      end
    end

    module Util
      module Platform
        def self.windows? = false
      end
    end
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

def capture_stdout
  old = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old
end
