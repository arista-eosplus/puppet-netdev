
# encoding: utf-8

require 'puppet/type'
require 'puppet_x/eos/provider'
Puppet::Type.type(:tacacs_server).provide(:eos) do
  # Create methods that set the @property_hash for the #flush method
  mk_resource_methods

  # Mix in the api as instance methods
  include PuppetX::Eos::EapiProviderMixin
  # Mix in the api as class methods
  extend PuppetX::Eos::EapiProviderMixin

  def self.instances
    api = eapi.Tacacs
    servers = api.servers
    servers.map do |api_attributes|
      puppet_attributes = { name: namevar(api_attributes), ensure: :present }
      single_connection = api_attributes[:multiplex] ? :true : :false
      puppet_attributes[:single_connection] = single_connection
      # Filter out API attributes e.g. :multiplex => :single_connection
      resource_attributes = api_attributes.select do |key, _|
        resource_type.allattrs.include?(key)
      end
      new(resource_attributes.merge(puppet_attributes))
    end
  end

  def initialize(resource = {})
    super(resource)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    @property_flush = resource.to_hash
  end

  def destroy
    @property_flush = resource.to_hash
  end

  def hostname=(value)
    @property_flush[:hostname] = value
  end

  def port=(value)
    @property_flush[:port] = value
  end

  def single_connection=(value)
    @property_flush[:single_connection] = value
  end

  def timeout=(value)
    @property_flush[:timeout] = value
  end

  def key=(value)
    @property_flush[:key] = value
  end

  def key_format=(value)
    @property_flush[:key_format] = value
  end

  def flush
    api = eapi.Tacacs
    desired_state = @property_hash.merge(@property_flush)
    # Handle :single_connection => :multiplex mapping
    multiplex = desired_state.delete(:single_connection)
    if multiplex == :true
      desired_state[:multiplex] = true
    else
      desired_state[:multiplex] = false
    end
    validate_identity(desired_state)
    case desired_state[:ensure]
    when :present
      api.update_server(desired_state)
    when :absent
      api.remove_server(desired_state)
    end
    @property_hash.merge!(@property_flush)
  end

  ##
  # validate_identity checks to make sure there are enough options specified to
  # uniquely identify a radius server resource.
  def validate_identity(opts = {})
    errors = false
    missing = [:hostname, :port].reject { |k| opts[k] }
    errors = !missing.empty?
    msg = "Invalid options #{opts.inspect} missing: #{missing.join(', ')}"
    fail Puppet::Error, msg if errors
  end
  private :validate_identity

  def self.namevar(opts)
    hostname  = opts[:hostname] or fail ArgumentError, 'hostname required'
    port = opts[:port] || 49
    "#{hostname}/#{port}"
  end
end
