# vagrant-git-hooks

[🇬🇧 English](./README.md) · 🇫🇷 Français

Gérez les **git hooks de votre projet depuis le Vagrantfile** — une alternative à
[husky](https://github.com/typicode/husky) qui **ne dépend ni de Node ni de npm**,
seulement de Vagrant. Fini le `package.json` et le `node_modules` ajoutés à un dépôt
Go/Ruby/Python juste pour linter au commit.

## Pourquoi

husky est excellent, mais c'est *un paquet Node*. `vagrant-git-hooks` déplace la
gestion des hooks dans l'outil que vous utilisez déjà pour décrire votre
environnement — Vagrant — pour que la seule dépendance soit Vagrant lui-même. Les
hooks sont du shell POSIX et s'exécutent sur l'hôte, exactement comme ceux de husky.

## Installation

```sh
vagrant plugin install vagrant-git-hooks
```

## Configuration

```ruby
Vagrant.configure("2") do |config|
  config.git_hooks.hooks = {
    "pre-commit" => "rubocop --parallel",
    "commit-msg" => "commitlint --edit $1",
    "pre-push"   => ["bundle exec rake spec", "echo pushed"]
  }

  # Optionnel : adopter des scripts (un fichier par hook) depuis un dossier versionné.
  config.git_hooks.hooks_source = "scripts/githooks"

  # Valeurs par défaut :
  # config.git_hooks.install_on_up     = true   # installer au `vagrant up`/provision
  # config.git_hooks.remove_on_destroy = false  # conserver les hooks au `vagrant destroy`
  # config.git_hooks.fail_on_error     = true   # injecte `set -e` (un hook en échec bloque le commit)
end
```

Une valeur peut être une `String` (une ligne) ou un `Array<String>` (plusieurs lignes).
Vos `$1` / `"$@"` sont transmis tels quels — git fournit ses arguments au hook.

Au `vagrant up`, le plugin écrit chaque hook dans le dossier de hooks du dépôt
(résolu via `git rev-parse --git-path hooks`, donc `core.hooksPath` et les worktrees
sont respectés) avec un en-tête géré :

```sh
#!/usr/bin/env sh
# >>> vagrant-git-hooks (managed) >>>
# Managed by Vagrant - do not edit manually (hook: pre-commit)
set -e
rubocop --parallel
# <<< vagrant-git-hooks (managed) <<<
```

Si un hook non géré existe déjà, il est sauvegardé en `<hook>.bak` avant d'être
remplacé, puis restauré à la désinstallation.

## CLI

| Commande | Description |
|---|---|
| `vagrant hooks install` | Installe les hooks configurés (`--dry-run`, `--json`) |
| `vagrant hooks uninstall` | Supprime les hooks gérés, restaure les sauvegardes (`--yes`) |
| `vagrant hooks list` | État de chaque hook : `installed` / `missing` / `modified` / `foreign` |
| `vagrant hooks run <hook> [args]` | Exécute un hook configuré sur l'hôte (tester sans commit) |
| `vagrant hooks version` | Affiche la version du plugin |
| `vagrant hooks help [topic]` | Aide |

Options globales : `--json`, `--no-emoji`, `--lang en|fr`.

## husky → vagrant-git-hooks

| husky | vagrant-git-hooks |
|---|---|
| `npx husky init` + fichiers `.husky/<hook>` | `config.git_hooks.hooks = { … }` dans le Vagrantfile |
| installé au `npm install` (Node) | installé au `vagrant up` (Vagrant) |
| `package.json` + `node_modules` | rien de plus — juste Vagrant |

## Licence

MIT — voir [LICENSE.md](./LICENSE.md).
