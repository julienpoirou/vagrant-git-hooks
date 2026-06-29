# Development

## Layout
- `lib/...`: plugin code (actions, config, util, i18n)
- `spec/...`: RSpec (Vagrant mocks, command tests)
- `locales/`: en/fr
- `README.md`: quick usage

## Run tests
```bash
bundle exec rake         # runs RSpec
bundle exec rubocop      # lint
gem build vagrant-git-hooks.gemspec
```

## Try the plugin locally with Vagrant
```bash
vagrant plugin install .
vagrant hooks version --json
# In a Vagrantfile, set config.git_hooks.*
vagrant up
```

Debug tips:
```bash
export VGH_DEBUG=1       # verbose debug output
export VGH_LANG=en       # force language
```

## Add a CLI subcommand
- Implement in `lib/.../command.rb`
- Add help text under `locales/*/help.topic.<cmd>`
- Cover with RSpec (see `spec/command_spec.rb`)

## i18n best practices
- Avoid inline strings; centralize in locale files.
- Keep `en.yml` and `fr.yml` in key parity.
