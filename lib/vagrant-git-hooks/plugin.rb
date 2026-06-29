# frozen_string_literal: true

require "vagrant"
require "i18n"

require_relative "version"
require_relative "helpers"
require_relative "config"
require_relative "command"
require_relative "service"
require_relative "util/git"

module VagrantGitHooks
  class Plugin < Vagrant.plugin("2")
    name "vagrant-git-hooks"

    description <<~DESC
      Manage git hooks declaratively from your Vagrantfile. A husky replacement
      that needs no Node/npm, only Vagrant: it installs hook scripts into the
      repository's hooks directory with ownership markers and backups.
    DESC

    config(:git_hooks) do
      Config
    end

    command("hooks") do
      Command
    end

    %i[machine_action_up machine_action_provision machine_action_reload].each do |hook_name|
      action_hook(:vgh_install, hook_name) do |hook|
        hook.append(Action::Install)
      end
    end

    action_hook(:vgh_uninstall, :machine_action_destroy) do |hook|
      hook.prepend(Action::Uninstall)
    end
  end

  module Action
    class Install
      def initialize(app, _env) = (@app = app)

      def call(env)
        UiHelpers.setup_i18n!
        cfg = env[:machine].config.git_hooks
        UiHelpers.setup_locale_from_config!(cfg)
        ui   = env[:ui]
        root = env[:machine].env.root_path.to_s

        run(cfg, ui, root) if cfg.install_on_up
      rescue StandardError => e
        UiHelpers.error(env[:ui], "VGH: #{e.message}")
      ensure
        @app.call(env)
      end

      private

      def run(cfg, ui, root)
        unless Util::Git.available? && Util::Git.repo?(root)
          UiHelpers.warn(ui, "#{UiHelpers.e(:warning)} #{UiHelpers.t("messages.not_a_repo")}")
          return
        end

        res = Service.install!(root: root, cfg: cfg, ui: ui)
        if res[:installed].empty? && res[:updated].empty?
          UiHelpers.say(ui, "#{UiHelpers.e(:info)} #{UiHelpers.t("messages.no_hooks")}")
          return
        end

        UiHelpers.say(ui, "#{UiHelpers.e(:success)} #{UiHelpers.t("messages.installed",
                                                                  count: res[:installed].size + res[:updated].size)}")
        return if res[:backed_up].empty?

        UiHelpers.say(ui, "#{UiHelpers.e(:info)} #{UiHelpers.t("messages.backed_up",
                                                               list: res[:backed_up].join(", "))}")
      end
    end

    class Uninstall
      def initialize(app, _env) = (@app = app)

      def call(env)
        UiHelpers.setup_i18n!
        cfg = env[:machine].config.git_hooks
        UiHelpers.setup_locale_from_config!(cfg)
        ui   = env[:ui]
        root = env[:machine].env.root_path.to_s

        run(cfg, ui, root) if cfg.remove_on_destroy
      rescue StandardError => e
        UiHelpers.error(env[:ui], "VGH: #{e.message}")
      ensure
        @app.call(env)
      end

      private

      def run(cfg, ui, root)
        return unless Util::Git.available? && Util::Git.repo?(root)

        res = Service.uninstall!(root: root, cfg: cfg, ui: ui)
        return if res[:removed].empty? && res[:restored].empty?

        UiHelpers.say(ui, "#{UiHelpers.e(:broom)} #{UiHelpers.t("messages.removed", count: res[:removed].size)}")
      end
    end
  end
end
