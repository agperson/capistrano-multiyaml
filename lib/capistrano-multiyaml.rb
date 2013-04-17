require 'fileutils'
require 'yaml'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/multiyaml requires Capistrano 2"
end


# Variable interpolation mechanism stolen from Ruby Facets 2.9.3 rather than
# requiring the whole library
def String.interpolate(&str)
  eval "%{#{str.call}}", str.binding
end

Capistrano::Configuration.instance.load do
  begin
    yamlfile = YAML.load_file(fetch(:multiyaml_stages, "config/stages.yaml"))
  rescue
    abort "Multistage deployment configuration file missing. Populate config/stages.yaml or set :multiyaml_stages to another location to use capistrano/multiyaml for multistage deployment."
  end

  stages = fetch(:stages, %w(staging production))

  # Loop through YAML configuration file and create a task for each stage.
  stages.each do |name| 
    desc "Set the target stage to `#{name}'."
    task(name) do 
      set(:stage, name.to_sym)
      set(:rails_env, name.to_s)
      logger.important "Setting stage to #{name}"

      # Load the corresponding stage's YAML configuration and iterate through,
      # setting roles, variables, and callbacks as specified.
      config = yamlfile[name.to_s]
      abort "Invalid or missing stage configuration for #{name}." if config.nil?

      config.each do |section, contents|
        case section.to_s

        # Set variables first so they can be used in roles if necessary.
        when "variables"
          contents.each do |key, value|
            if key.is_a?(Symbol) and not value.nil? then
              set(key, String.interpolate{value.to_s})
            end
          end

        when "tasks"
          contents.each do |task|
            target = task['target'].to_s
            action = task['action'].to_s
            if not target.nil? and not action.nil? then
              before(target, action) if task['type'] == "before_callback"
              after( target, action) if task['type'] == "after_callback"
            end
          end

        when "roles"
          contents.each do |rolename, hosts|
            hosts.each do |hostname, options|
              hostname = String.interpolate{hostname.to_s}
              logger.info "Processing host settings for #{hostname} (#{name})"
              if options.is_a?(Hash) then
                role(rolename.to_sym, hostname.to_s, options)
              else
                role(rolename.to_sym, hostname.to_s)
              end
            end
          end

        else
          logger.info "Multistage YAML configuration section #{section.to_s} ignored by capistrano/multiyaml."
        end
      end
    end 
  end 

  on :load do
    if stages.include?(ARGV.first)
      # Execute the specified stage so that recipes required in stage can contribute to task list
      find_and_execute_task(ARGV.first) if ARGV.any?{ |option| option =~ /-T|--tasks|-e|--explain/ }
    else
      # Execute the default stage so that recipes required in stage can contribute tasks
      find_and_execute_task(default_stage) if exists?(:default_stage)
    end
  end

  namespace :multiyaml do
    desc "[internal] Ensure that a stage has been selected."
    task :ensure do
      if !exists?(:stage)
        if exists?(:default_stage)
          logger.important "Defaulting to `#{default_stage}'"
          find_and_execute_task(default_stage)
        else
          abort "No stage specified. Please specify one of: #{stages.join(', ')} (e.g. `cap #{stages.first} #{ARGV.last}')"
        end
      end 
    end
  end

  on :start, "multiyaml:ensure", :except => stages
end
