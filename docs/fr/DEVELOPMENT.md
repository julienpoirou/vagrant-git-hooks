# Développement

## Structure
- `lib/...` : code du plugin (actions, config, util, i18n)
- `spec/...` : RSpec (mocks Vagrant, tests de commandes)
- `locales/` : en/fr
- `README.md` : usage rapide

## Lancer les tests
```bash
bundle exec rake         # exécute RSpec
bundle exec rubocop      # lint
gem build vagrant-git-hooks.gemspec
```

## Tester le plugin en local avec Vagrant
```bash
vagrant plugin install .
vagrant hooks version --json
# Dans un Vagrantfile, configurez config.git_hooks.*
vagrant up
```

Astuce debug :
```bash
export VGH_DEBUG=1         # sortie de debug détaillée
export VGH_LANG=fr         # force la langue
```

## Ajouter une sous‑commande CLI
- Implémenter dans `lib/.../command.rb`
- Ajouter l'aide dans `locales/*/help.topic.<cmd>`
- Couvrir via RSpec (voir `spec/command_spec.rb`)

## i18n – bonnes pratiques
- Évitez les messages inline; centralisez dans les locales.
- Gardez `en.yml` et `fr.yml` en parité de clés.
