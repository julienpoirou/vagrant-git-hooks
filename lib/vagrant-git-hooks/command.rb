# frozen_string_literal: true

require "optparse"
require "json"
require "tempfile"

require_relative "helpers"
require_relative "config"
require_relative "service"
require_relative "hook_builder"
require_relative "util/git"
require_relative "util/verbose"
require_relative "version"

module VagrantGitHooks
  BASE_CMD = if defined?(Vagrant) && Vagrant.respond_to?(:plugin)
               Vagrant.plugin("2", :command)
             else
               Class.new do
                 def initialize(argv = [], env = {})
                   @argv = argv || []
                   @env  = env  || {}
                 end

                 def parse_options(parser)
                   parser.permute!(@argv)
                   @argv
                 rescue OptionParser::InvalidOption
                   nil
                 end
               end
             end

  class Command < BASE_CMD
    def execute
      UiHelpers.setup_i18n!
      @opts = { json: false, no_emoji: false, lang: nil, yes: false, dry_run: false }

      argv = parse_options(build_parser)
      return 0 unless argv

      apply_locale_and_flags
      dispatch(argv.shift, argv)
    end

    private

    def dispatch(sub, argv)
      case sub
      when "version"             then cmd_version
      when nil, "", "help"       then UiHelpers.print_topic_help(argv.shift)
                                      0
      when "install"             then with_project { |root, cfg| do_install(root, cfg) }
      when "uninstall", "remove" then with_project { |root, cfg| do_uninstall(root, cfg) }
      when "list", "status"      then with_project { |root, cfg| do_list(root, cfg) }
      when "run"                 then with_project { |root, cfg| do_run(root, cfg, argv) }
      else
        err("#{UiHelpers.e(:error, no_emoji: @opts[:no_emoji])} #{UiHelpers.t("errors.unknown_command")}")
        1
      end
    end

    def build_parser
      OptionParser.new do |o|
        o.banner = UiHelpers.t("usage.banner")
        o.on("--json", "Machine-readable JSON output") { @opts[:json] = true }
        o.on("--no-emoji", "Disable emoji in output")  { @opts[:no_emoji] = true }
        o.on("--lang LANG", "Force language (en|fr)")  { |v| @opts[:lang] = v }
        o.on("--dry-run", "Show what would change")    { @opts[:dry_run] = true }
        o.on("-y", "--yes", "Auto-confirm")            { @opts[:yes] = true }
      end
    end

    def apply_locale_and_flags
      ENV["VGH_NO_EMOJI"] = "1" if @opts[:no_emoji]
      return unless @opts[:lang]

      begin
        UiHelpers.set_locale!(@opts[:lang])
      rescue UiHelpers::UnsupportedLocaleError
        UiHelpers.set_locale!("en")
      end
    end

    def with_project
      root = @env.respond_to?(:root_path) ? @env.root_path : nil
      unless root
        err("#{UiHelpers.e(:error, no_emoji: @opts[:no_emoji])} #{UiHelpers.t("errors.no_machine")}")
        return 1
      end

      cfg = @env.vagrantfile.config.git_hooks
      resolve_cli_locale!(cfg)
      yield root.to_s, cfg
    end

    def resolve_cli_locale!(cfg)
      return if @opts[:lang]
      return unless ENV["VGH_LANG"].to_s.strip.empty?
      return unless cfg.respond_to?(:locale) && cfg.locale

      begin
        UiHelpers.set_locale!(cfg.locale)
      rescue UiHelpers::UnsupportedLocaleError
        UiHelpers.set_locale!("en")
      end
    end

    def do_install(root, cfg)
      return fail_not_repo("install") unless git_repo?(root)

      res = Service.install!(root: root, cfg: cfg, ui: ui, dry_run: @opts[:dry_run])
      return emit("install", "success", res) if @opts[:json]

      total = res[:installed].size + res[:updated].size
      if total.zero?
        say("#{mark(:info)} #{UiHelpers.t("messages.no_hooks")}")
      else
        say("#{mark(:success)} #{UiHelpers.t("messages.installed", count: total)}")
        unless res[:backed_up].empty?
          say("#{mark(:info)} #{UiHelpers.t("messages.backed_up", list: res[:backed_up].join(", "))}")
        end
      end
      0
    end

    def do_uninstall(root, _cfg)
      return fail_not_repo("uninstall") unless git_repo?(root)

      unless @opts[:yes]
        return err_code("uninstall", UiHelpers.t("errors.confirmation_required")) if @opts[:json]

        unless confirm?("#{mark(:question)} #{UiHelpers.t("prompts.uninstall")}")
          return err_code("uninstall", UiHelpers.t("errors.cancelled"))
        end
      end

      res = Service.uninstall!(root: root, ui: ui, dry_run: @opts[:dry_run])
      return emit("uninstall", "success", res) if @opts[:json]

      say("#{mark(:broom)} #{UiHelpers.t("messages.removed", count: res[:removed].size)}")
      say("#{mark(:info)} #{UiHelpers.t("messages.restored", count: res[:restored].size)}") unless res[:restored].empty?
      0
    end

    def do_list(root, cfg)
      rows = Service.status(root: root, cfg: cfg)
      return emit("list", "success", { hooks: rows }) if @opts[:json]

      if rows.empty?
        say("#{mark(:info)} #{UiHelpers.t("messages.no_hooks")}")
        return 0
      end

      say("#{mark(:info)} #{UiHelpers.t("messages.list_header")}")
      rows.each { |r| say(format("  • %-22s %s", r[:name], r[:state])) }
      0
    end

    def do_run(_root, cfg, argv)
      name = argv.shift
      return err_code("run", UiHelpers.t("usage.run")) if name.to_s.strip.empty?

      cmd = (cfg.hooks || {})[name]
      return err_code("run", UiHelpers.t("errors.hook_not_configured", name: name)) if cmd.nil?

      script = HookBuilder.script_for(name: name, commands: cmd, fail_on_error: cfg.fail_on_error)
      Tempfile.create(["vgh-", ""]) do |f|
        f.write(script)
        f.flush
        File.chmod(0o755, f.path) unless Gem.win_platform?
        Util::Verbose.log("sh", f.path, *argv)
        system("sh", f.path, *argv) ? 0 : 1
      end
    end

    def cmd_version
      return emit("version", "success", { version: VERSION }) if @opts[:json]

      say("#{mark(:version)} #{UiHelpers.t("log.version_line", version: VERSION)}")
      0
    end


    def git_repo?(root)
      Util::Git.available? && Util::Git.repo?(root)
    end

    def fail_not_repo(action)
      err_code(action, UiHelpers.t("errors.not_a_repo"))
    end

    def err_code(action, message)
      return emit(action, "error", { error: message }) if @opts[:json]

      err("#{mark(:error)} #{message}")
      1
    end

    def emit(action, status, data)
      puts JSON.generate({ action: action, status: status }.merge(data))
      status == "success" ? 0 : 1
    end

    def mark(key)
      UiHelpers.e(key, no_emoji: @opts[:no_emoji])
    end

    def confirm?(prompt)
      return true if @opts[:yes]

      print "#{prompt} "
      %w[y yes o oui].include?($stdin.gets.to_s.strip.downcase)
    end

    def ui
      @env.respond_to?(:ui) ? @env.ui : nil
    end

    def say(msg)
      UiHelpers.say(ui, msg)
    end

    def err(msg)
      UiHelpers.error(ui, msg)
    end
  end
end
