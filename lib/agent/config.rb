module Agent

  class Config

    def initialize(parent)
      @parent = parent
    end

    def schedule(string)
      @parent.schedule = string
    end

    def server(string)
      @parent.server = string
    end

    def key(string)
      @parent.key = string
    end

    def secret(string)
      @parent.secret = string
    end

  end

  class << self
    attr_accessor :schedule, :server, :key, :secret

    def set_defaults
      @schedule ||= "*/60 * * * *"
    end

    def configure
      set_defaults
      yield Config.new(self)
    end
  end
end
