require 'dry/core/class_attributes'

require 'rom/transaction'

module ROM
  # Abstract gateway class
  #
  # @api public
  class Gateway
    extend Dry::Core::ClassAttributes

    defines :adapter

    # Return connection object
    #
    # @return [Object] type varies depending on the gateway
    #
    # @api public
    attr_reader :connection

    # Setup a gateway
    #
    # @overload setup(type, *args)
    #   Sets up a single-gateway given a gateway type.
    #   For custom gateways, create an instance and pass it directly.
    #
    #   @param [Symbol] type
    #   @param [Array] *args
    #
    # @overload setup(gateway)
    #   @param [Gateway] gateway
    #
    # @return [Gateway] a specific gateway subclass
    #
    # @example
    #   module SuperDB
    #     class Gateway < ROM::Gateway
    #       def initialize(options)
    #       end
    #     end
    #   end
    #
    #   ROM.register_adapter(:super_db, SuperDB)
    #
    #   Gateway.setup(:super_db, some: 'options')
    #   # SuperDB::Gateway.new(some: 'options') is called
    #
    #   # or alternatively
    #   super_db = Gateway.setup(SuperDB::Gateway.new(some: 'options'))
    #   Gateway.setup(super_db)
    #
    # @api public
    def self.setup(gateway_or_scheme, *args)
      case gateway_or_scheme
      when String
        raise ArgumentError, <<-STRING.gsub(/^ {10}/, '')
          URIs without an explicit scheme are not supported anymore.
          See https://github.com/rom-rb/rom/blob/master/CHANGELOG.md
        STRING
      when Symbol
        klass = class_from_symbol(gateway_or_scheme)

        if klass.instance_method(:initialize).arity == 0
          klass.new
        else
          klass.new(*args)
        end
      else
        if args.empty?
          gateway_or_scheme
        else
          raise ArgumentError, "Can't accept arguments when passing an instance"
        end
      end
    end

    # Get gateway subclass for a specific adapter
    #
    # @param [Symbol] type adapter identifier
    #
    # @return [Class]
    #
    # @api private
    def self.class_from_symbol(type)
      adapter = ROM.adapters.fetch(type) {
        begin
          require "rom/#{type}"
        rescue LoadError
          raise AdapterLoadError, "Failed to load adapter rom/#{type}"
        end

        ROM.adapters.fetch(type)
      }

      adapter.const_get(:Gateway)
    end

    # Returns the adapter, defined for the class
    #
    # @return [Symbol]
    #
    # @api public
    def adapter
      self.class.adapter || raise(
        MissingAdapterIdentifierError,
        "gateway class +#{self}+ is missing the adapter identifier"
      )
    end

    # A generic interface for setting up a logger
    #
    # @api public
    def use_logger(*)
      # noop
    end

    # A generic interface for returning default logger
    #
    # @api public
    def logger
      # noop
    end

    # Extension hook for adding gateway-specific behavior to a command class
    #
    # @param [Class] klass command class
    # @param [Object] _dataset dataset that will be used with this command class
    #
    # @return [Class]
    #
    # @api public
    def extend_command_class(klass, _dataset)
      klass
    end

    # Schema inference hook
    #
    # Every gateway that supports schema inference should implement this method
    #
    # @return [Array] array with datasets and their names
    #
    # @api private
    def schema
      []
    end

    # Disconnect is optional and it's a no-op by default
    #
    # @api public
    def disconnect
      # noop
    end

    # Runs a block inside a transaction. The underlying transaction engine
    # is adapter-specific
    #
    # @param [Hash] Transaction options
    # @return The result of yielding the block or +nil+ if
    #         the transaction was rolled back
    #
    # @api public
    def transaction(opts = EMPTY_HASH, &block)
      transaction_runner(opts).run(opts, &block)
    end

    # @api private
    def transaction_runner(_)
      Transaction::NoOp
    end
  end
end
