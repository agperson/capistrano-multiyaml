YAML Multistage Extensions for Capistrano
=========================================

This extension is an alternative to Jamis Buck's multistage extension for Capistrano that stores multistage configuration in a single YAML file rather than in multiple Ruby files.  It provides a simple and straightforward way to specify variables, callbacks, and roles for different deployment stages, and the file can be manipulated by any script that understands YAML.  Even if the file is only managed by humans, there are still several benefits including centralizing stage/role configuration in one file, discouraging per-stage logic in deference to properly hooked before/after callbacks, and simplified configuration reuse.'

For more information about the general idea of multistage deployment, see the [docs for the original module](https://github.com/capistrano/capistrano/wiki/2.x-Multistage-Extension/).

## Installation

1.  Install the **capistrano-multiyaml** gem using RubyGems, Bundler, or your preferred system.
2.  Modify your `Capfile` or `deploy.rb` to set a few variables and include the gem:

        set :stages, %w(integration staging production)
        set :default_stage, "staging"
        set :multiyaml_stages, "config/stages.yaml"`
        
        require 'capistrano-multiyaml'

    **Note:** `:default_stage` is optional, and `:multiyaml_stages` only needs to be set if you are using a location other than `config/stages.yaml`.

## Configure Stages

The easiest way to understand the capabilities of the YAML file is to see a complete one.  This example incorporates all of the possible configuration options, and also uses YAML anchor/alias to avoid repetition. Note that while before/after callback hooks can be used to evaluate code, this is not recommended because the goal of this setup is to avoid putting deploy logic in the stage configuration file.

```ruby
--- # stages for application "fooapp"
integration:
  roles:
    app:
      '#{`hostname -f`}':
staging: 
  variables: &vars
    :data_path:    '/nfs/#{application}/#{stage}'
    :clean_script: '/usr/local/bin/clean-cache.sh'
  tasks: &tasks
    - type  : after_callback
      target: 'deploy:setup'
      action: 'fooapp:link_data_path'
    - type  : before_callback
      target: 'deploy:restart'
      action: 'fooapp:run_scripts'
  roles: 
    web:
      'lb-stage1.foocorp.com':
    db:
      'sql-stage1.db.foocorp.com':
    app: 
      'app-stage1.foocorp.com': { :primary: true }
      'app-stage2.foocorp.com':
production:
  variables: *vars
  tasks: *tasks
  roles: 
    web:
      'lb-prod1.foocorp.com':
      'lb-prod2.foocorp.com':
    db:
      'sql-prod1.db.foocorp.com':
    app:
      'app-prod1.foocorp.com': { :primary: true }
      'app-prod2.foocorp.com':
      'app-prod3.foocorp.com':
      'app-prod4.foocorp.com': { :read_only: true }
```

* Variable keys are symbols
* Variables and roles are interpolated. It is valid to use other variables within variables and roles, such as the staging data_path variable including the stage and application name, and the development app server role looking up the FQDN of localhost.
* Tasks can be one of `after_callback` (using the "after" hook) or `before_callback` (using the "before" hook).  Action can be either another task or a code block to be evaluated.
* Additional parameters can be passed to servers in an array

## Running Deploy Actions

Prefix deploy actions with the name of the stage, i.e. `cap production TASK`.  If you do not set a stage and `default_stage` is set, it will be used instead.

## Caveats

* Don't name your stage "stage", as this is a reserved word under the multistage extension (deploys won't do anything and in fact it will cause an infinite loop).

## Inspiration

* [Jamis Buck's original](https://github.com/capistrano/capistrano/wiki/2.x-Multistage-Extension)
* [Lee Hambly's alternative](https://github.com/leehambley/capistrano-yaml-multistage)
