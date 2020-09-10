#!/usr/bin/env ruby

require 'fileutils'
require 'commander/import'
require 'agent/config'
require 'highline'
require 'json'
require 'net/http'
require 'net/https'
require 'uri'

class NilClass
  def empty?
    true
  end
end

module Agent
  DEFAULT_ROOT_DIR = "/var/lib/agent"
  ROOT_DIR_PARAM = 'AGENT_DIR'
  ROOT_DIR = ENV[ROOT_DIR_PARAM] || DEFAULT_ROOT_DIR

  TEMPLATE_DIR = File.expand_path(File.join(__FILE__, '..', '..', 'templates'))

  CONFIG_FILE_NAME = "agent.conf"
  ALL_FILES = [CONFIG_FILE_NAME]

  CONFIG_FILE = File.join(ROOT_DIR, CONFIG_FILE_NAME)

  AGENT_CRONTAB_MARKER = "# agent gem"

  LOG_COLORS = {
      :create => :green,
      :update => :green,
      :ignore => :yellow,
      :remove => :red
  }

  class << self
    def init(options)
      copy_template(CONFIG_FILE_NAME, options)

      if Process.euid == 0 && (username = ENV['SUDO_USER'])
        change_owner(username, ROOT_DIR, CONFIG_FILE)
      end
      update
    end

    def update
      load_config

      crontab = load_crontab
      old_line = find_agent_crontab_line(crontab)

      # disable crontab to make sure it doesn't add a line logs while we're updating them
      if old_line
        crontab.delete(old_line)
        save_crontab(crontab)
        updated = true
      end

      #noinspection RubyScope
      log(updated ? :update : :create, "crontab entry")
      crontab << agent_crontab_line
      save_crontab(crontab)
    end

    def disable
      crontab = load_crontab
      old_line = find_agent_crontab_line(crontab)

      if old_line
        log :remove, "crontab entry"
        crontab.delete(old_line)
        save_crontab(crontab)
      end
    end

    def purge
      if ask("Deleting all data - are you sure? (y/n) ")
        if File.directory?(ROOT_DIR)
          Dir[ROOT_DIR + "/*"].each do |f|
            log :remove, f
            File.unlink(f)
          end
          log :remove, ROOT_DIR
          Dir.rmdir(ROOT_DIR)
        end

      end
    rescue SystemCallError
      sudo_fail "#{ROOT_DIR} can't be deleted"
    end

    def stats
      load_config
      require 'vmstat'
      snapshot = Vmstat.snapshot
      result = {}
      result[:host] = Socket.gethostname
      result[:at] = snapshot.at
      result[:boot_time] = snapshot.boot_time
      result[:public_key] = Agent.key
      result[:agent_version] = Agent::VERSION
      result[:cpu] = snapshot.cpus.map { |cpu|
        sum = (cpu.user + cpu.system + cpu.idle + cpu.nice).to_f
        {
            num: cpu.num,
            user:  (cpu.user*100/sum).round(2),
            system: (cpu.system*100/sum).round(2),
            idle: (cpu.idle*100/sum).round(2)

        }
      }
      result[:disks] = snapshot.disks.map { |disk|
        {
            origin: disk.origin = "/dev/disk0s2",
            free: disk.available_bytes,
            total: disk.total_bytes
        }
      }
      result[:load] = [
          snapshot.load_average.one_minute,
          snapshot.load_average.five_minutes,
          snapshot.load_average.fifteen_minutes,
      ]

      result[:memory] = {
          wired: snapshot.memory.wired_bytes,
          free: snapshot.memory.free,
          active: snapshot.memory.active_bytes,
          inactive: snapshot.memory.inactive_bytes,
          total: snapshot.memory.total_bytes
      }
      result[:network] = snapshot.network_interfaces.map { |net|
        {
            name: net.name,
            in: net.in_bytes,
            out: net.out_bytes
        }
      }
      message = JSON.generate(result)
      puts message
      post(message)
    end

    private

    def copy_template(name, options = {})
      directory = options[:to] || ROOT_DIR
      new_name = options[:as] || name
      path = File.join(directory, new_name)
      template = original_file(name)

      log :create, path
      FileUtils.mkdir_p(directory)
      File.open(path, "w") do |f|
        contents = if String.new.respond_to?(:encoding)
                     File.read(template, :external_encoding => 'UTF-8')
                   else
                     File.read(template)
                   end
        contents.gsub!(/{{(.+?)}}/) { eval $1 }
        f.write(contents)
      end
    rescue SystemCallError
      sudo_fail "#{path} can't be created"
    end

    def fail(problem)
      log problem
      exit 1
    end

    def sudo_fail(problem)
      fail "#{problem} - run this command with 'sudo' or 'rvmsudo'."
    end

    def log(type, message = nil)
      if message
        color = LOG_COLORS[type]
        label = ($terminal && color) ? $terminal.color(type, color, :bold) : type
        pad = " " * (12 - type.to_s.length)
        say("#{pad}#{label}  #{message}")
      else
        puts type
      end
    end

    def change_owner(username, *files)
      uid = `id -u #{username}`.to_i
      gid = `id -g #{username}`.to_i
      files.each do |file|
        log :chown, file
        File.chown(uid, gid, file)
      end
    end

    def original_file(name)
      File.join(TEMPLATE_DIR, name)
    end

    def user_file(name)
      File.join(ROOT_DIR, name)
    end

    def load_crontab
      `crontab -l 2> /dev/null`.split(/\n/)
    end

    def save_crontab(crontab)
      crontab_file = user_file("crontab")
      File.open(crontab_file, "w") do |file|
        crontab.each do |line|
          file.puts(line)
        end
      end

      system("crontab #{crontab_file}")
      File.unlink(crontab_file)
    end

    def find_agent_crontab_line(crontab)
      crontab.detect { |l| l.include?(AGENT_CRONTAB_MARKER) }
    end

    def agent_crontab_line
      rvm_path = ENV['rvm_path']
      rvm_load = "source #{rvm_path}/scripts/rvm &&" if rvm_path
      agent_dir = "#{ROOT_DIR_PARAM}=#{ROOT_DIR}" unless ROOT_DIR == DEFAULT_ROOT_DIR

      "#{Agent.schedule}     /bin/bash -c \"#{rvm_load} #{agent_dir} agent log\"   #{AGENT_CRONTAB_MARKER}"
    end

    def load_config
      if File.exist?(CONFIG_FILE)
        load CONFIG_FILE
      else
        fail "No #{CONFIG_FILE_NAME} file - please run 'agent install'."
      end
    end

    def post(message)
      key = Agent.secret
      mac = OpenSSL::HMAC.hexdigest("SHA256", key, message)

      uri = URI.parse(Agent.server)
      request = Net::HTTP::Post.new(uri.path, {'Content-Type': 'application/json', 'Sign': mac})
      request.body = message
      Net::HTTP.start(uri.host, uri.port, :read_timeout => 5000) do |http|
        http.use_ssl = uri.scheme == 'https'
        http.request(request)
      end
    end

  end
end
