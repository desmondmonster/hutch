require 'hutch/error_handlers/logger'
require 'logger'

module Hutch
  class UnknownAttributeError < StandardError; end

  class Config
    require 'yaml'

    def initialize
      @config = {
        mq_host: 'localhost',
        mq_port: 5672,
        mq_exchange: 'hutch',  # TODO: should this be required?
        mq_vhost: '/',
        mq_tls: false,
        mq_tls_cert: nil,
        mq_tls_key: nil,
        mq_username: 'guest',
        mq_password: 'guest',
        mq_api_host: 'localhost',
        mq_api_port: 15672,
        mq_api_ssl: false,
        log_level: Logger::INFO,
        logfile: $stdout,
        require_paths: [],
        autoload_app: true,
        error_handlers: [Hutch::ErrorHandlers::Logger.new],
        namespace: nil,
        channel_prefetch: 0,
        daemonize: false,
        pidfile: 'tmp/hutch.pid'
      }
    end

    def get(attr)
      check_attr(attr)
      user_config[attr]
    end

    def set(attr, value)
      check_attr(attr)
      user_config[attr] = value
    end

    alias_method :[],  :get
    alias_method :[]=, :set

    def check_attr(attr)
      unless user_config.key?(attr)
        raise UnknownAttributeError, "#{attr} is not a valid config attribute"
      end
    end

    def user_config
      initialize unless @config
      @config
    end

    def load_from_file(file)
      require 'erb'
      YAML.load(ERB.new(file.read).result).each do |attr, value|
        Hutch.config.send("#{attr}=", value)
      end
    end

    def method_missing(method, *args, &block)
      attr = method.to_s.sub(/=$/, '').to_sym
      return super unless user_config.key?(attr)

      if method =~ /=$/
        set(attr, args.first)
      else
        get(attr)
      end
    end
  end
end
