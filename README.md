# vagrant-git-hooks

🇬🇧 English · [🇫🇷 Français](./README.fr.md)

Manage your project's **git hooks from the Vagrantfile** — a [husky](https://github.com/typicode/husky)
replacement that needs **no Node/npm**, only Vagrant. Stop adding a `package.json`
and `node_modules` to a Go/Ruby/Python repo just to lint on commit.

## Why

Husky is great, but it *is* a Node package. `vagrant-git-hooks` moves hook
management into the tool you already use to describe your environment — Vagrant —
so the only dependency is Vagrant itself. Hooks are plain POSIX shell and run on
the host, exactly like husky's.

## Install

```sh
vagrant plugin install vagrant-git-hooks
```

## Configure

```ruby
Vagrant.configure("2") do |config|
  config.git_hooks.hooks = {
    "pre-commit" => "rubocop --parallel",
    "commit-msg" => "commitlint --edit $1",
    "pre-push"   => ["bundle exec rake spec", "echo pushed"]
  }

  # Optional: adopt one-file-per-hook scripts from a versioned directory.
  config.git_hooks.hooks_source = "scripts/githooks"

  # Defaults:
  # config.git_hooks.install_on_up     = true   # install on `vagrant up`/provision
  # config.git_hooks.remove_on_destroy = false  # keep hooks on `vagrant destroy`
  # config.git_hooks.fail_on_error     = true   # inject `set -e` (a failing hook blocks the commit)
end
```

A value can be a `String` (single line) or an `Array<String>` (several lines).
Your `$1` / `"$@"` are passed through — git feeds the hook its own arguments.

On `vagrant up` the plugin writes each hook into the repository hooks directory
(resolved via `git rev-parse --git-path hooks`, so `core.hooksPath` and worktrees
are honored) with a managed header:

```sh
#!/usr/bin/env sh
# >>> vagrant-git-hooks (managed) >>>
# Managed by Vagrant - do not edit manually (hook: pre-commit)
set -e
rubocop --parallel
# <<< vagrant-git-hooks (managed) <<<
```

If a non-managed hook already exists, it is backed up to `<hook>.bak` before being
replaced, and restored on uninstall.

## CLI

| Command | Description |
|---|---|
| `vagrant hooks install` | Install configured hooks (`--dry-run`, `--json`) |
| `vagrant hooks uninstall` | Remove managed hooks, restore backups (`--yes`) |
| `vagrant hooks list` | Show each hook's state: `installed` / `missing` / `modified` / `foreign` |
| `vagrant hooks run <hook> [args]` | Run a configured hook on the host (test without committing) |
| `vagrant hooks version` | Print the plugin version |
| `vagrant hooks help [topic]` | Help |

Global flags: `--json`, `--no-emoji`, `--lang en|fr`.

## husky → vagrant-git-hooks

| husky | vagrant-git-hooks |
|---|---|
| `npx husky init` + `.husky/<hook>` files | `config.git_hooks.hooks = { … }` in the Vagrantfile |
| installed on `npm install` (Node) | installed on `vagrant up` (Vagrant) |
| `package.json` + `node_modules` | nothing extra — just Vagrant |

## License

MIT — see [LICENSE.md](./LICENSE.md).
