require 'agent/agent'
require 'agent/meta'

program :version, Agent::VERSION
program :description, Agent::DESCRIPTION
program :help_formatter, :compact

program :help, "Instructions", %(
  1. Run 'agent init' to setup files and directories.
  2. Edit #{Agent::CONFIG_FILE}, set your schedule and list processes to agent.
  3. Run 'agent update' to enable agenting (rerun this each time you modify the config file or update the gem).
)

default_command :help

command :init do |c|
  c.syntax = 'agent init'
  c.summary = "Creates a directory for agent in #{Agent::ROOT_DIR} and copies all necessary files"
  c.option '--server url', String, 'Well-formed url for grabbing results'
  c.option '--key public', String, 'Public agent key '
  c.option '--secret secret', String, 'Private agent key'
  c.action do |args, options|
    if options.server.empty?
      options.server = ask('Server uri:')
      URI.parse(options.server) rescue raise 'Server URI must be specified and valid'
    end
    if options.key.empty?
      options.key = ask('Agent public key:')
      raise 'Public key must be specified' if options.key.empty?
    end
    if options.secret.empty?
      options.secret = ask('Agent secret key:')
      raise 'Secret key must be specified' if options.secret.empty?
    end
    Agent.init(options)
  end
end

alias_command :install, :init

command :update do |c|
  c.syntax = 'agent update'
  c.summary = 'Updates crontab'
  c.action { Agent.update }
end

alias_command :enable, :update

command :remove do |c|
  c.syntax = 'agent remove'
  c.summary = 'Removes the crontab line that runs agent (leaves all files unchanged)'
  c.action { Agent.disable }
end

alias_command :disable, :remove

command :purge do |c|
  c.syntax = 'agent purge'
  c.summary = 'Deletes all files created by agent (including all generated logs)'
  c.action { Agent.purge }
end

command :log do |c|
  c.syntax = 'agent log'
  c.summary = "Sends stats to server(this is called automatically by cron)"
  c.action { Agent.stats  }
end
