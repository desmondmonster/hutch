require 'hutch/error_handlers/logger'
require 'logger'

module Hutch
  class UnknownAttributeError < StandardError; end

  class Config
    require 'yaml'

    def initialize(attributes = {})
      default_attributes.each do |attr, val|
        initialize_attribute(attr, val)
      end

      load_attributes(attributes)
    end

    def load_attributes(attrs)
      attrs.each { |attr, val| set attr, val }
      self
    end

    def load_from_file(file)
      require 'erb'
      load_attributes(YAML.load(ERB.new(file.read).result))
    end

    def method_missing(method, *args, &block)
      if attempting_to_set_attribute?(method)
        attr = method.to_s.sub(/=$/, '')
        raise UnknownAttributeError, "#{attr} is not a valid config attribute"
      else
        super
      end
    end


    private

    def set(attr, val)
      send("#{attr}=", val)
    end

    def attempting_to_set_attribute?(method)
      method =~ /=$/
    end

    def initialize_attribute(attr, val)
      self.class.instance_eval { attr_accessor attr }
      set attr, val
    end

    def default_attributes
      { mq_host: 'localhost',
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
        pidfile: 'tmp/hutch.pid' }
    end
  end
end
